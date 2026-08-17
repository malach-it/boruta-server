use std::collections::{BTreeMap, BTreeSet};

use rustler::{Error, NifMap, NifResult, ResourceArc};
use serde::{Deserialize, Serialize};
use serde_json::Value;

const DEFAULT_LEARNING_RATE: f64 = 0.08;
const REQUEST_CONTEXT_WEIGHT: f64 = 0.6;
const PHI_MAX_DEGREE: u64 = 2;
const MEMORY_LIMIT: usize = 32;
const MEMORY_DECAY: f64 = 0.8;
const OPENAPI_METHODS: [&str; 8] = [
    "get", "post", "put", "patch", "delete", "head", "options", "trace",
];

#[derive(Clone, Debug, NifMap)]
struct Request {
    method: String,
    path: String,
}

#[derive(Debug, NifMap)]
struct TrainingStats {
    examples: u64,
    synthetic_examples: u64,
    openapi_operations: u64,
    graph_nodes: u64,
    graph_path_nodes: u64,
    graph_method_nodes: u64,
    request_contexts: u64,
    request_context_relationships: u64,
    request_context_weight: f64,
    phi_max_degree: u64,
    noise_examples: u64,
    signal_examples: u64,
    epochs: u64,
    max_error: f64,
}

#[derive(Debug, NifMap)]
struct Prediction {
    in_scope: bool,
    openapi_match: bool,
    noise: bool,
    score: f64,
    noise_score: f64,
    phi_value: f64,
    memory_size: u64,
}

#[derive(Clone, Debug, Deserialize, Serialize)]
struct Route {
    method: String,
    segments: Vec<RouteSegment>,
}

#[derive(Clone, Debug, Deserialize, Serialize)]
enum RouteSegment {
    Literal(String),
    Parameter,
}

#[derive(Clone, Debug, Deserialize, Serialize)]
struct PhiModel {
    routes: Vec<Route>,
    graph_nodes: Vec<String>,
    openapi_requests: Vec<String>,
    request_context_weight: f64,
    weights: BTreeMap<String, f64>,
}

struct ModelResource(PhiModel);

#[rustler::resource_impl]
impl rustler::Resource for ModelResource {}

#[rustler::nif(schedule = "DirtyCpu")]
fn train(
    openapi_json: String,
    max_epochs: usize,
    epsilon: f64,
) -> NifResult<(ResourceArc<ModelResource>, TrainingStats)> {
    if max_epochs == 0 || !epsilon.is_finite() || epsilon <= 0.0 {
        return Err(Error::BadArg);
    }

    let routes = parse_openapi_routes(&openapi_json)?;
    let (labeled_requests, graph_path_nodes, graph_method_nodes) =
        synthetic_openapi_requests(&routes);
    let graph_nodes = openapi_graph_nodes(&routes);
    let openapi_requests = openapi_request_contexts(&routes);
    let synthetic_examples = labeled_requests.len();

    let examples = labeled_requests
        .iter()
        .map(|(request, target)| {
            (
                request_context_terms(request, &routes, &openapi_requests),
                *target,
            )
        })
        .collect::<Vec<_>>();

    if examples.is_empty() {
        return Err(Error::BadArg);
    }

    let noise_examples = examples.iter().filter(|(_, target)| *target == 1.0).count();
    let signal_examples = examples.len() - noise_examples;
    let mut model = PhiModel {
        routes,
        graph_nodes,
        openapi_requests,
        request_context_weight: REQUEST_CONTEXT_WEIGHT,
        weights: BTreeMap::new(),
    };
    let mut trained_epochs = 0;
    let mut max_error: f64 = 1.0;

    for epoch in 0..max_epochs {
        for (terms, target) in &examples {
            let prediction = model.phi_sum(terms).clamp(0.0, 1.0);
            let error = target - prediction;

            for (term, value) in terms {
                *model.weights.entry(term.clone()).or_insert(0.0) +=
                    DEFAULT_LEARNING_RATE * error * value;
            }
        }

        max_error = examples
            .iter()
            .map(|(terms, target)| (target - model.phi_sum(terms).clamp(0.0, 1.0)).abs())
            .fold(0.0, f64::max);

        trained_epochs = epoch + 1;
        if max_error <= epsilon {
            break;
        }
    }

    let stats = TrainingStats {
        examples: examples.len() as u64,
        synthetic_examples: synthetic_examples as u64,
        openapi_operations: model.routes.len() as u64,
        graph_nodes: model.graph_nodes.len() as u64,
        graph_path_nodes: graph_path_nodes as u64,
        graph_method_nodes: graph_method_nodes as u64,
        request_contexts: model.openapi_requests.len() as u64,
        request_context_relationships: (model.openapi_requests.len()
            * (model.openapi_requests.len() - 1)) as u64,
        request_context_weight: model.request_context_weight,
        phi_max_degree: PHI_MAX_DEGREE,
        noise_examples: noise_examples as u64,
        signal_examples: signal_examples as u64,
        epochs: trained_epochs as u64,
        max_error,
    };

    Ok((ResourceArc::new(ModelResource(model)), stats))
}

#[rustler::nif]
fn predict(
    model: ResourceArc<ModelResource>,
    request: Request,
    memory: Vec<Request>,
) -> Prediction {
    let in_scope = api_scope(&request.path);
    let openapi_match = route_matches(&model.0.routes, &request.method, &request.path);
    let memory_size = memory.len().min(MEMORY_LIMIT);
    let noise_score = if in_scope {
        model.0.phi_sum(&prediction_context_terms(
            &request,
            &memory,
            &model.0.routes,
        ))
    } else {
        0.0
    };
    let phi_value = noise_score;
    let noise_score = noise_score.clamp(0.0, 1.0);
    let score = if in_scope { 1.0 - noise_score } else { 0.0 };

    Prediction {
        in_scope,
        openapi_match,
        noise: in_scope && noise_score >= 0.5,
        score,
        noise_score,
        phi_value,
        memory_size: memory_size as u64,
    }
}

#[rustler::nif]
fn export_model(model: ResourceArc<ModelResource>) -> NifResult<String> {
    serde_json::to_string(&model.0).map_err(|_| Error::BadArg)
}

#[rustler::nif]
fn load_model(serialized: String) -> NifResult<ResourceArc<ModelResource>> {
    let model = serde_json::from_str::<PhiModel>(&serialized).map_err(|_| Error::BadArg)?;

    if model.weights.values().any(|weight| !weight.is_finite()) {
        return Err(Error::BadArg);
    }

    Ok(ResourceArc::new(ModelResource(model)))
}

impl PhiModel {
    fn phi_sum(&self, terms: &[(String, f64)]) -> f64 {
        terms.iter().fold(0.0, |sum, (term, value)| {
            sum + self.weights.get(term).copied().unwrap_or(0.0) * value
        })
    }
}

fn parse_openapi_routes(openapi_json: &str) -> NifResult<Vec<Route>> {
    let document = serde_json::from_str::<Value>(openapi_json).map_err(|_| Error::BadArg)?;
    let paths = document
        .get("paths")
        .and_then(Value::as_object)
        .ok_or(Error::BadArg)?;
    let mut routes = Vec::new();

    for (path, operations) in paths {
        let Some(operations) = operations.as_object() else {
            continue;
        };

        for method in OPENAPI_METHODS {
            if operations.contains_key(method) {
                routes.push(Route {
                    method: method.to_ascii_uppercase(),
                    segments: path_segments(path)
                        .into_iter()
                        .map(|segment| {
                            if segment.starts_with('{') && segment.ends_with('}') {
                                RouteSegment::Parameter
                            } else {
                                RouteSegment::Literal(segment.to_string())
                            }
                        })
                        .collect(),
                });
            }
        }
    }

    // The gateway root is a valid move for every OpenAPI Path Item method.
    for method in OPENAPI_METHODS {
        let method = method.to_ascii_uppercase();
        if !routes
            .iter()
            .any(|route| route.method == method && route.segments.is_empty())
        {
            routes.push(Route {
                method,
                segments: Vec::new(),
            });
        }
    }
    routes.push(Route {
        // The wildcard also covers valid HTTP extension methods.
        method: "*".to_string(),
        segments: Vec::new(),
    });

    if routes.is_empty() {
        Err(Error::BadArg)
    } else {
        Ok(routes)
    }
}

fn route_matches(routes: &[Route], method: &str, path: &str) -> bool {
    let method = method.to_ascii_uppercase();
    let segments = path_segments(path);

    routes.iter().any(|route| {
        (route.method == method || route.method == "*")
            && route.segments.len() == segments.len()
            && route
                .segments
                .iter()
                .zip(&segments)
                .all(|(expected, actual)| match expected {
                    RouteSegment::Literal(literal) => literal == actual,
                    RouteSegment::Parameter => !actual.is_empty(),
                })
    })
}

fn synthetic_openapi_requests(routes: &[Route]) -> (Vec<(Request, f64)>, usize, usize) {
    let mut examples = Vec::new();
    let path_routes = routes
        .iter()
        .map(|route| (route.template_path(), route.clone()))
        .collect::<BTreeMap<_, _>>();
    let methods = routes
        .iter()
        .filter(|route| route.method != "*")
        .map(|route| route.method.clone())
        .collect::<BTreeSet<_>>();
    let method_node_count = routes
        .iter()
        .map(|route| route.method.as_str())
        .collect::<BTreeSet<_>>()
        .len();

    for route in path_routes.values() {
        let parameters = if route
            .segments
            .iter()
            .any(|segment| matches!(segment, RouteSegment::Parameter))
        {
            vec!["example-id", "292f26d4-3adb-42d5-824d-09a4297f0c98"]
        } else {
            vec!["example-id"]
        };

        for method in &methods {
            for parameter in &parameters {
                let concrete_path = route.concrete_path(parameter);
                let target = if route_matches(routes, method, &concrete_path) {
                    0.0
                } else {
                    1.0
                };
                examples.push((synthetic_request(method, &concrete_path), target));
            }
        }

        let concrete_path = route.concrete_path("example-id");

        // Unsupported methods and scanner-like suffixes are controlled negative
        // mutations of otherwise valid OpenAPI operations.
        if !route_matches(routes, "CONNECT", &concrete_path) {
            examples.push((synthetic_request("CONNECT", &concrete_path), 1.0));
        }
        for method in &methods {
            let unknown_path = format!("{concrete_path}/.env/config");
            if !route_matches(routes, method, &unknown_path) {
                examples.push((synthetic_request(method, &unknown_path), 1.0));
            }
        }
    }

    if routes
        .iter()
        .any(|route| route.method == "*" && route.segments.is_empty())
    {
        examples.push((synthetic_request("*", "/"), 0.0));
    }

    (examples, path_routes.len(), method_node_count)
}

fn openapi_graph_nodes(routes: &[Route]) -> Vec<String> {
    routes
        .iter()
        .flat_map(|route| {
            [
                format!("method:{}", route.method),
                format!("path:{}", route.template_path()),
            ]
        })
        .collect::<BTreeSet<_>>()
        .into_iter()
        .collect()
}

fn openapi_request_contexts(routes: &[Route]) -> Vec<String> {
    routes
        .iter()
        .map(|route| format!("{} {}", route.method, route.template_path()))
        .collect::<BTreeSet<_>>()
        .into_iter()
        .collect()
}

impl Route {
    fn template_path(&self) -> String {
        let segments = self
            .segments
            .iter()
            .map(|segment| match segment {
                RouteSegment::Literal(literal) => literal.as_str(),
                RouteSegment::Parameter => "{}",
            })
            .collect::<Vec<_>>();

        format!("/{}", segments.join("/"))
    }

    fn concrete_path(&self, parameter: &str) -> String {
        let segments = self
            .segments
            .iter()
            .map(|segment| match segment {
                RouteSegment::Literal(literal) => literal.as_str(),
                RouteSegment::Parameter => parameter,
            })
            .collect::<Vec<_>>();

        format!("/{}", segments.join("/"))
    }
}

fn synthetic_request(method: &str, path: &str) -> Request {
    Request {
        method: method.to_string(),
        path: path.to_string(),
    }
}

fn path_segments(path: &str) -> Vec<&str> {
    let path = path.split(['?', '#']).next().unwrap_or(path);
    path.trim_matches('/')
        .split('/')
        .filter(|segment| !segment.is_empty())
        .collect()
}

fn api_scope(_path: &str) -> bool {
    true
}

fn request_context_terms(
    request: &Request,
    routes: &[Route],
    openapi_requests: &[String],
) -> Vec<(String, f64)> {
    let mut terms = Vec::new();
    let request_id = request_id(routes, request);
    add_request_example_terms(&mut terms, &request_id, 1.0);

    // a, b, c are whole request examples. Phi composition is additive:
    // phi(a + 0.6b + 0.6c) = phi(a) + 0.6phi(b) + 0.6phi(c).
    for context in openapi_requests
        .iter()
        .filter(|context| **context != request_id)
    {
        add_request_example_terms(&mut terms, context, REQUEST_CONTEXT_WEIGHT);
        terms.push((
            format!("phi:degree2:{request_id}*{context}"),
            REQUEST_CONTEXT_WEIGHT,
        ));
    }

    terms
}

fn prediction_context_terms(
    request: &Request,
    memory: &[Request],
    routes: &[Route],
) -> Vec<(String, f64)> {
    let primary_id = request_id(routes, request);
    let mut terms = Vec::new();
    add_request_example_terms(&mut terms, &primary_id, 1.0);

    for (age, context) in memory.iter().rev().take(MEMORY_LIMIT).enumerate() {
        let context_id = request_id(routes, context);
        if context_id == primary_id {
            continue;
        }

        let weight = REQUEST_CONTEXT_WEIGHT * MEMORY_DECAY.powi(age as i32);
        add_request_example_terms(&mut terms, &context_id, weight);
        terms.push((format!("phi:degree2:{primary_id}*{context_id}"), weight));
    }

    terms
}

fn request_id(routes: &[Route], request: &Request) -> String {
    let path_template = best_path_template(routes, &request.path);
    let method = canonical_request_method(routes, request);

    match path_template {
        Some(template) => format!("{method} {template}"),
        None => format!("{method} <unknown>"),
    }
}

fn canonical_request_method(routes: &[Route], request: &Request) -> String {
    let method = request.method.to_ascii_uppercase();

    if routes
        .iter()
        .any(|route| route.method == method && route_path_matches(route, &request.path))
    {
        method
    } else if routes
        .iter()
        .any(|route| route.method == "*" && route_path_matches(route, &request.path))
    {
        "*".to_string()
    } else {
        method
    }
}

fn add_request_example_terms(terms: &mut Vec<(String, f64)>, request_id: &str, weight: f64) {
    let Some((method, path)) = request_id.split_once(' ') else {
        return;
    };

    terms.push((format!("phi:request:{request_id}"), weight));
    terms.push((format!("phi:node:method:{method}"), weight));
    terms.push((format!("phi:node:path:{path}"), weight));
}

fn best_path_template(routes: &[Route], path: &str) -> Option<String> {
    routes
        .iter()
        .filter(|route| route_path_matches(route, path))
        .max_by_key(|route| {
            route
                .segments
                .iter()
                .filter(|segment| matches!(segment, RouteSegment::Literal(_)))
                .count()
        })
        .map(Route::template_path)
}

fn route_path_matches(route: &Route, path: &str) -> bool {
    let segments = path_segments(path);

    route.segments.len() == segments.len()
        && route
            .segments
            .iter()
            .zip(&segments)
            .all(|(expected, actual)| match expected {
                RouteSegment::Literal(literal) => literal == actual,
                RouteSegment::Parameter => !actual.is_empty(),
            })
}

rustler::init!("Elixir.BorutaGateway.PhiNoise.Native");

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn matches_parameterized_openapi_routes_and_trailing_slashes() {
        let routes = parse_openapi_routes(
            r#"{"paths":{"/api/clients":{"get":{}},"/api/clients/{id}":{"get":{}}}}"#,
        )
        .unwrap();

        assert!(route_matches(&routes, "GET", "/api/clients/"));
        assert!(route_matches(&routes, "get", "/api/clients/client-id"));
        assert!(!route_matches(&routes, "POST", "/api/clients/client-id"));
        assert!(!route_matches(
            &routes,
            "GET",
            "/api/clients/client-id/edit"
        ));
    }

    #[test]
    fn phi_is_additive_over_request_examples() {
        let model = PhiModel {
            routes: Vec::new(),
            graph_nodes: Vec::new(),
            openapi_requests: Vec::new(),
            request_context_weight: REQUEST_CONTEXT_WEIGHT,
            weights: BTreeMap::from([
                ("phi:request:a".to_string(), 0.2),
                ("phi:request:b".to_string(), 0.3),
                ("phi:request:c".to_string(), 0.4),
            ]),
        };
        let a = [("phi:request:a".to_string(), 1.0)];
        let b = [("phi:request:b".to_string(), 1.0)];
        let c = [("phi:request:c".to_string(), 1.0)];
        let abc = [a[0].clone(), b[0].clone(), c[0].clone()];

        assert_eq!(
            model.phi_sum(&abc),
            model.phi_sum(&a) + model.phi_sum(&b) + model.phi_sum(&c)
        );
    }

    #[test]
    fn other_openapi_requests_are_lower_weight_phi_examples() {
        let routes = parse_openapi_routes(
            r#"{"paths":{"/api/clients":{"get":{},"post":{}},"/api/clients/{id}":{"get":{}}}}"#,
        )
        .unwrap();
        let contexts = openapi_request_contexts(&routes);
        let terms = request_context_terms(
            &Request {
                method: "GET".to_string(),
                path: "/api/clients".to_string(),
            },
            &routes,
            &contexts,
        );

        assert!(terms.contains(&("phi:request:GET /api/clients".to_string(), 1.0)));
        assert!(terms.contains(&(
            "phi:request:GET /api/clients/{}".to_string(),
            REQUEST_CONTEXT_WEIGHT
        )));
        assert!(terms.contains(&(
            "phi:request:POST /api/clients".to_string(),
            REQUEST_CONTEXT_WEIGHT
        )));
        assert!(terms.contains(&(
            "phi:degree2:GET /api/clients*POST /api/clients".to_string(),
            REQUEST_CONTEXT_WEIGHT
        )));
    }
}
