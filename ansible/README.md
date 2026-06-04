# Boruta ingress controller playbook

This directory contains Kubernetes playbooks for Boruta. The main Boruta ingress
controller scenario is defined in `ingress-controller.yml`.

## Purpose

`ingress-controller.yml` deploys a local Boruta ingress-controller stack:

- a namespace for the Boruta components;
- RBAC for watching Kubernetes `Ingress` and `Service` resources;
- a PostgreSQL deployment and service;
- a Boruta Gateway deployment configured as a Kubernetes ingress controller;
- a `NodePort` service exposing HTTP and HTTPS entry points;
- a static Boruta Admin configuration `ConfigMap`;
- a one-shot `Job` using `boruta-admin` to load that configuration;
- a Boruta Auth deployment, service, and example ingress.

The playbook is intended for development and staging-style Kubernetes clusters.
It currently uses a local gateway image and GHCR-hosted Boruta Auth/Admin images.

## Prerequisites

- Ansible with the `kubernetes.core` collection installed.
- Access to a Kubernetes cluster from the current kubeconfig context.
- Python Kubernetes client dependencies available to Ansible.
- The Boruta Gateway image referenced by `boruta_gateway_image` available on the
  target nodes. The default is local-only and uses `imagePullPolicy: Never`.
- DNS or local hosts entries for the example hostnames you want to call, such as
  `auth.boruta.local`.

Example install command for the Ansible collection:

```sh
ansible-galaxy collection install kubernetes.core
```

## Running

From the repository root:

```sh
ansible-playbook ansible/ingress-controller.yml
```

To override variables at runtime:

```sh
ansible-playbook ansible/ingress-controller.yml \
  -e boruta_namespace=boruta-staging \
  -e boruta_gateway_image=boruta-gateway:local.4
```

## Main Variables

| Variable | Default | Description |
| --- | --- | --- |
| `boruta_namespace` | `boruta-staging` | Kubernetes namespace for the stack. |
| `boruta_ingress_class` | `boruta` | Ingress class watched by the controller. |
| `boruta_ingress_watch_namespace` | `boruta_namespace` | Namespace watched for ingress/service resources. Use `*` for cluster-wide watch. |
| `boruta_ingress_node_name` | `global` | Gateway node name used by the ingress controller. |
| `boruta_ingress_replicas` | `2` | Number of gateway ingress-controller replicas. |
| `boruta_oauth_host` | `auth.boruta.local` | Hostname used for the Boruta OAuth ingress and generated OAuth URLs. |
| `boruta_gateway_image` | `boruta-gateway:local.4` | Gateway image. The default expects a locally loaded image. |
| `boruta_admin_image` | `ghcr.io/malach-it/boruta-admin:0.9.1` | Image used by the configuration-loader job. |
| `boruta_auth_image` | `ghcr.io/malach-it/boruta-auth:0.9.1` | Image used by the Boruta Auth deployment. |
| `boruta_ingress_http_node_port` | `30080` | NodePort for HTTP traffic. |
| `boruta_ingress_https_node_port` | `30443` | NodePort for HTTPS traffic. |
| `boruta_configuration_path` | `/app/config/static-configuration.yml` | Path where the static config is mounted in the loader job. |

## Configuration Loader

The playbook creates a `ConfigMap` named by `boruta_configuration_name`, with a
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
ansible-playbook ansible/ingress-controller.yml
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
- `boruta_gateway_image` defaults to a local image with `imagePullPolicy: Never`.
  Change both the image and pull policy in the playbook if the gateway image is
  pulled from a registry.
- Setting `boruta_ingress_watch_namespace='*'` switches RBAC from `Role` and
  `RoleBinding` to `ClusterRole` and `ClusterRoleBinding`.
