# gha-stateful-runner

A Helm chart for deploying stateful GitHub Actions self-hosted runners on Kubernetes using a UI token — no Personal Access Token (PAT) required.

Each runner pod keeps its registration credentials in a dedicated PersistentVolumeClaim, so runners survive restarts without re-registering on every startup.

## Prerequisites

- Kubernetes 1.25+
- Helm 3.x
- A GitHub Actions runner registration token (obtained from **GitHub → Repository/Organization → Settings → Actions → Runners → New self-hosted runner**)

## Quick Start

```bash
helm install my-runners . \
  --set runner.repoUrl=https://github.com/your-org/your-repo \
  --set runner.token=YOUR_REGISTRATION_TOKEN
```

> **Note**: `runner.repoUrl` and either `runner.token` or `runner.secret` are required.

## Configuration

| Parameter | Description | Default |
|-----------|-------------|---------|
| `image` | Runner container image | `ghcr.io/actions/actions-runner` |
| `version` | Runner image tag | `2.333.0` |
| `fullnameOverride` | Override the full resource name | `""` |
| `includeNamespace` | Include namespace in resource metadata | `false` |
| `namespaceOverride` | Override the namespace | `""` |
| `runner.name` | Runner name prefix | `gha-sts-runner` |
| `runner.count` | Number of runner replicas | `3` |
| `runner.repoUrl` | **Required.** GitHub repo or org URL | `""` |
| `runner.token` | Runner registration token (required when `runner.secret` is not set) | `""` |
| `runner.secret` | Name of an existing Secret with key `ui_token` | `""` |
| `runner.labels` | Runner labels for job routing | `[self-hosted, linux, gha-static]` |
| `runner.storageClass` | StorageClass for credentials PVC | `""` (cluster default) |
| `runner.resources` | Resource requests/limits for runner container | See `values.yaml` |
| `runner.initResources` | Resource requests/limits for init container | See `values.yaml` |
| `serviceAccount.create` | Create a dedicated ServiceAccount | `true` |
| `serviceAccount.name` | Override the ServiceAccount name | `""` |
| `serviceAccount.automountServiceAccountToken` | Disable automatic API token mounting | `false` |
| `serviceAccount.annotations` | Annotations for the ServiceAccount (e.g. IRSA) | `{}` |
| `podDisruptionBudget.enabled` | Create a PodDisruptionBudget | `true` |
| `podDisruptionBudget.minAvailable` | Minimum available pods during disruptions | `1` |
| `securityContext` | Pod-level security context | `{fsGroup: 1001}` |
| `containerSecurityContext` | Container-level security context | non-root, drop ALL capabilities |
| `podAntiAffinity.enabled` | Spread runners across nodes | `true` |
| `podAntiAffinity.type` | `preferred` (soft) or `required` (hard) | `preferred` |
| `affinity` | Additional affinity rules (e.g. nodeAffinity) | `{}` |
| `dind.enable` | Enable Docker-in-Docker sidecar | `false` |
| `dind.image` | DinD container image | `docker:27-dind` |
| `dind.resources` | Resource requests/limits for DinD container | See `values.yaml` |

## Using an Existing Secret

Pre-create a secret and reference it to avoid passing the token on the command line:

```bash
kubectl create secret generic my-runner-token \
  --from-literal=ui_token=YOUR_REGISTRATION_TOKEN

helm install my-runners . \
  --set runner.repoUrl=https://github.com/your-org/your-repo \
  --set runner.secret=my-runner-token
```

## Docker-in-Docker (DinD)

Enable the DinD sidecar to run Docker commands inside jobs:

```bash
helm install my-runners . \
  --set runner.repoUrl=https://github.com/your-org/your-repo \
  --set runner.token=YOUR_REGISTRATION_TOKEN \
  --set dind.enable=true
```

> **Warning**: DinD requires `privileged: true`. Ensure your cluster's PodSecurity policy or admission controller allows privileged containers.

## Re-registering a Runner

Runner credentials are cached in a PVC. If a runner's registration is lost (token expired, runner deleted from GitHub), re-register it by deleting the PVC for the affected pod:

```bash
# Replace <N> with the pod index (0, 1, 2, ...)
kubectl delete pvc runner-creds-<release-name>-gha-sts-runner-<N>
kubectl delete pod <release-name>-gha-sts-runner-<N>
```

Provide a fresh registration token in the Secret before deleting the PVC.

## Autoscaling

For dynamic scaling based on the GitHub Actions job queue, consider using [KEDA](https://keda.sh/) with the [GitHub Runner scaler](https://keda.sh/docs/scalers/github-runner/).

## Security Notes

- Runner containers run as non-root user (UID 1001) with all Linux capabilities dropped.
- The Kubernetes API token is **not** mounted by default (`automountServiceAccountToken: false`). Enable it and create appropriate RBAC only if your CI jobs need to interact with the Kubernetes API.
- DinD runs as a privileged container and should only be enabled when necessary.
- For production, use `runner.secret` to reference a pre-created (or externally managed) Secret rather than passing `runner.token` in values.
