# Boruta ingress controller playbook

This directory contains Kubernetes playbooks for Boruta. The local Boruta ingress
controller scenario is split between `ingress-controller.yml`, `oauth.yml`, and
`kagome.yml`.

## Purpose

`ingress-controller.yml` deploys the local Boruta ingress-controller stack:

- a namespace for the Boruta components;
- RBAC for watching Kubernetes `Ingress` and `Service` resources;
- a PostgreSQL deployment and service;
- a Boruta Gateway deployment configured as a Kubernetes ingress controller;
- a `NodePort` service exposing HTTP and HTTPS entry points.

`oauth.yml` deploys the OAuth example surface:

- a static Boruta Admin configuration `ConfigMap`;
- a one-shot `Job` using `boruta-admin` to load that configuration;
- a Boruta Auth deployment, service, and example ingress.

`kagome.yml` deploys the Kagome example upstream:

- a separate `kagome` namespace;
- a Kagome static configuration `ConfigMap`;
- a Kagome deployment and service;
- an ingress handled by the Boruta ingress controller.

The playbooks are intended for development and staging-style Kubernetes clusters.
They currently use GHCR-hosted Boruta Gateway/Auth/Admin/Kagome images.

## Prerequisites

- Ansible with the `kubernetes.core` collection installed.
- Access to a Kubernetes cluster from the current kubeconfig context.
- Python Kubernetes client dependencies available to Ansible.
- DNS or local hosts entries for the example hostnames you want to call, such as
  `auth.boruta.local` and `kagome.local`.

Example install command for the Ansible collection:

```sh
ansible-galaxy collection install kubernetes.core
```

## Running

From the repository root:

```sh
ansible-playbook -i ansible/hosts ansible/ingress-controller.yml
ansible-playbook -i ansible/hosts ansible/oauth.yml
ansible-playbook -i ansible/hosts ansible/kagome.yml
```

To override variables at runtime:

```sh
ansible-playbook -i ansible/hosts ansible/ingress-controller.yml \
  -e boruta_namespace=boruta-staging \
  -e boruta_gateway_image=ghcr.io/malach-it/boruta-gateway:kubernetes-ingress-controller.alpha.7
ansible-playbook -i ansible/hosts ansible/oauth.yml \
  -e boruta_namespace=boruta-staging \
  -e boruta_oauth_host=auth.boruta.local
ansible-playbook -i ansible/hosts ansible/kagome.yml \
  -e kagome_mtls_enabled=true
```

## Main Variables

| Variable | Default | Description |
| --- | --- | --- |
| `boruta_namespace` | `boruta-staging` | Kubernetes namespace for the stack. |
| `boruta_ingress_class` | `boruta` | Ingress class watched by the controller. |
| `boruta_ingress_watch_namespace` | `boruta_namespace` | Namespace watched for ingress/service resources. Use `*` for cluster-wide watch. |
| `boruta_libcluster_namespace` | `*` | Namespace used by libcluster Kubernetes pod discovery. Use `*` for cluster-wide discovery. |
| `boruta_libcluster_selector` | `identity_platform=boruta` | Pod selector used by libcluster Kubernetes discovery. |
| `boruta_ingress_node_name` | `global` | Gateway node name used by the ingress controller. |
| `boruta_ingress_replicas` | `2` | Number of gateway ingress-controller replicas. |
| `boruta_release_cookie` | `cookie` | Erlang distribution cookie shared by clustered releases. |
| `boruta_oauth_scheme` | `http` | Scheme used by the Boruta Auth deployment. |
| `boruta_oauth_host` | `auth.boruta.local` | Hostname used for the Boruta OAuth ingress and generated OAuth URLs. |
| `boruta_oauth_port` | `8080` | Internal Boruta Auth HTTP port. |
| `boruta_oauth_base_url` | `http://auth.boruta.local:30080` | Public base URL used by the Boruta Auth deployment. |
| `boruta_gateway_image` | `ghcr.io/malach-it/boruta-gateway:kubernetes-ingress-controller.alpha.7` | Gateway image. |
| `boruta_admin_image` | `ghcr.io/malach-it/boruta-admin:kubernetes-ingress-controller.alpha.7` | Image used by the configuration-loader job. |
| `boruta_auth_image` | `ghcr.io/malach-it/boruta-auth:kubernetes-ingress-controller.alpha.7` | Image used by the Boruta Auth deployment. |
| `boruta_kagome_image` | `ghcr.io/malach-it/kagome:kubernetes-ingress-controller.alpha.4` | Kagome image. |
| `kagome_mtls_enabled` | `true` | Enables mTLS verification for the Kagome ingress/backend example. |
| `boruta_ingress_http_node_port` | `30080` | NodePort for HTTP traffic. |
| `boruta_ingress_https_node_port` | `30443` | NodePort for HTTPS traffic. |
| `boruta_configuration_path` | `/app/config/static-configuration.yml` | Path where the static config is mounted in the loader job. |

Variables common to the split playbooks live in `group_vars/all`. Run with
`-i ansible/hosts` or another inventory so Ansible loads those shared defaults.

## Kubernetes Clustering

The ingress, OAuth, and Kagome deployments set:

```yaml
K8S_NAMESPACE: "{{ boruta_libcluster_namespace }}"
K8S_SELECTOR: "{{ boruta_libcluster_selector }}"
```

The default namespace wildcard enables cluster-wide pod discovery. The ingress
playbook creates cluster-scoped pod RBAC for libcluster when
`boruta_libcluster_namespace` is `*`; otherwise it creates namespace-scoped
RBAC in the configured namespace.

Pods that should participate in discovery must match
`boruta_libcluster_selector`. The Boruta ingress controller, OAuth deployment,
and Kagome deployment use `identity_platform: "boruta"` labels for that purpose.

## Configuration Loader

`oauth.yml` creates a `ConfigMap` named by `boruta_configuration_name`, with a
`static-configuration.yml` entry based on the Boruta Admin example configuration.
It is mounted into a Kubernetes `Job` that runs:

```sh
/app/bin/boruta_admin eval "Application.ensure_all_started(:boruta_identity) && BorutaAdmin.Release.load_configuration() |> dbg"
```

The loader reads the file from `BORUTA_CONFIGURATION_PATH`. The loader is
idempotent: applying the same configuration again updates existing resources
instead of creating duplicates.

The static configuration can also provide the Boruta service-registry cluster
CA used for gateway TLS/mTLS:

```yaml
configuration:
  cluster_ca:
    certificate: |
      -----BEGIN CERTIFICATE-----
      ...
      -----END CERTIFICATE-----
    private_key: |
      -----BEGIN PRIVATE KEY-----
      ...
      -----END PRIVATE KEY-----
```

When `cluster_ca` is present, Boruta validates that the certificate and private
key match, upserts the service-registry root record, and loads the certificate as
a trusted CA. Keep the private key out of committed playbooks; mount or template
it from a secret source for shared environments.

The job has `ttlSecondsAfterFinished: 300`. If the job already exists and has
completed, Kubernetes will not automatically rerun it only because the ConfigMap
changed. Delete the existing job before reapplying when you need to force a new
load:

```sh
kubectl -n boruta-staging delete job boruta-static-configuration-loader
ansible-playbook -i ansible/hosts ansible/oauth.yml
```

## Ingress Annotations

The example ingress uses Boruta annotations to populate gateway upstream
metadata:

- `boruta.patatoid.fr/strip-uri`
- `boruta.patatoid.fr/authorize`
- `boruta.patatoid.fr/required-scopes`
- `boruta.patatoid.fr/error-content-type`
- `boruta.patatoid.fr/forbidden-response`
- `boruta.patatoid.fr/unauthorized-response`
- `boruta.patatoid.fr/forwarded-token-signature-alg`
- `boruta.patatoid.fr/forwarded-token-secret`
- `boruta.patatoid.fr/mtls-enabled`
- `boruta.patatoid.fr/rate-limit-*`

The controller watches ingresses matching `boruta_ingress_class`. For the default
playbook, use:

```yaml
spec:
  ingressClassName: boruta
```

`boruta.patatoid.fr/mtls-enabled: "true"` enables client-certificate
authentication when the gateway connects to the upstream service. It requires an
HTTPS backend, so set `boruta.patatoid.fr/backend-protocol: "HTTPS"` or
`nginx.ingress.kubernetes.io/backend-protocol: "HTTPS"` on the same ingress.

## Local Access

With the default NodePort values, HTTP traffic is exposed on port `30080`.

For a local cluster, add a host entry that points the example hostname to a node
IP, for example:

```text
127.0.0.1 auth.boruta.local
```

Then call:

```sh
curl http://auth.boruta.local:30080/healthcheck
```

## Notes

- The default PostgreSQL password and Boruta secrets are development values.
  Override them for any shared environment.
- Run `ingress-controller.yml` before `oauth.yml`; the OAuth deployment and
  configuration loader use the shared `boruta-env` `ConfigMap` created by the
  ingress playbook.
- Run `kagome.yml` after `ingress-controller.yml` when you want the Kagome
  example ingress and upstream.
- Setting `boruta_ingress_watch_namespace='*'` switches RBAC from `Role` and
  `RoleBinding` to `ClusterRole` and `ClusterRoleBinding`.
