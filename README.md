# gha-stateful-runner

A Helm chart for deploying stateful GitHub Actions self-hosted runners on Kubernetes using a UI token — no Personal Access Token (PAT) required.

Each runner pod keeps its registration credentials in a dedicated PersistentVolumeClaim, so runners survive restarts without re-registering on every startup.

## Prerequisites

- Kubernetes 1.25+
- Helm 3.x
- A GitHub Actions runner registration token (obtained from **GitHub → Repository → Settings → Actions → Runners → New self-hosted runner**)

## Quick Start

1. In GitHub, open your repository and go to **Settings -> Actions -> Runners**.
2. Click **New self-hosted runner**.
3. Copy the runner registration token shown in the setup page (this is the `ui_token`, valid for about 1 hour).
4. Install the chart from GHCR with your repo URL and token:

```bash
helm install my-runners oci://ghcr.io/eric2788/charts/gha-stateful-runner \
  --set runner.repoUrl=https://github.com/your-org/your-repo \
  --set runner.token=YOUR_REGISTRATION_TOKEN
```

> [!NOTE]
> - `runner.repoUrl` and either `runner.token` or `runner.secret` are required.
> - Version is not pinned in these examples so new chart releases are picked up automatically.

## Local Development Install

For local chart development/testing from a cloned repo:

```bash
helm install my-runners . \
  --set runner.repoUrl=https://github.com/your-org/your-repo \
  --set runner.token=YOUR_REGISTRATION_TOKEN
```

## Configuration

| Parameter | Description | Default                            |
|-----------|-------------|------------------------------------|
| `image` | Runner container image | `ghcr.io/actions/actions-runner`   |
| `version` | Runner image tag | `2.333.0`                          |
| `imagePullPolicy` | Image pull policy for runner/init/DinD containers | `IfNotPresent`                     |
| `fullnameOverride` | Override the full resource name | `""`                               |
| `includeNamespace` | Include namespace in resource metadata | `false`                            |
| `namespaceOverride` | Override the namespace | `""`                               |
| `runner.name` | Runner name prefix | `gha-sts-runner`                   |
| `runner.count` | Number of runner replicas | `3`                                |
| `runner.terminationGracePeriodSeconds` | Pod termination grace period before force kill | `600`                              |
| `runner.preStop.enabled` | Enable bounded preStop drain logic | `true`                             |
| `runner.preStop.maxWaitSeconds` | Max wait for in-flight runner work during preStop | `540`                              |
| `runner.preStop.pollIntervalSeconds` | Poll interval used by preStop wait loop | `5`                                |
| `runner.repoUrl` | **Required.** GitHub repo or org URL | `""`                               |
| `runner.token` | Runner registration token (required when `runner.secret` is not set) | `""`                               |
| `runner.secret` | Name of an existing Secret with key `ui_token` | `""`                               |
| `runner.labels` | Runner labels for job routing | `[self-hosted, linux, gha-static]` |
| `runner.extraEnv` | Additional environment variables for the runner container. | `[]`                               |
| `runner.storageClass` | StorageClass for credentials PVC | `""` (cluster default)             |
| `runner.credStorageSize` | Storage size for credentials PVC | `"64Mi"`                           |
| `runner.resources` | Resource requests/limits for runner container | See `values.yaml`                  |
| `runner.initResources` | Resource requests/limits for init container | See `values.yaml`                  |
| `serviceAccount.create` | Create a dedicated ServiceAccount resource. When `false`, the runner pod uses `serviceAccount.name` if set, otherwise the namespace `default` ServiceAccount | `true`                             |
| `serviceAccount.name` | ServiceAccount name for the runner pod to use (existing or chart-created) | `""`                               |
| `serviceAccount.automountServiceAccountToken` | Whether to auto-mount the Kubernetes API token on the runner pod | `false`                            |
| `serviceAccount.annotations` | Annotations for the ServiceAccount (e.g. IRSA) | `{}`                               |
| `podDisruptionBudget.enabled` | Create a PodDisruptionBudget | `true`                             |
| `podDisruptionBudget.minAvailable` | Minimum available pods during disruptions | `1`                                |
| `securityContext` | Pod-level security context | `{fsGroup: 1001}`                  |
| `containerSecurityContext` | Container-level security context | non-root, drop ALL capabilities    |
| `podAntiAffinity.enabled` | Spread runners across nodes | `true`                             |
| `podAntiAffinity.type` | `preferred` (soft) or `required` (hard) | `preferred`                        |
| `affinity` | Additional affinity rules (e.g. nodeAffinity) | `{}`                               |
| `podAnnotations` | Annotations for runner pods (e.g. Prometheus) | `{}`                               |
| `extraManifests` | Extra templated Kubernetes manifests to deploy with this chart | `[]`                               |
| `dind.enable` | Enable Docker-in-Docker sidecar | `false`                            |
| `dind.image` | DinD container image | `docker:27-dind`                   |
| `dind.resources` | Resource requests/limits for DinD container | See `values.yaml`                  |

## Using an Existing Secret

Pre-create a secret and reference it to avoid passing the token on the command line:

```bash
kubectl create secret generic my-runner-token \
  --from-literal=ui_token=YOUR_REGISTRATION_TOKEN

helm install my-runners oci://ghcr.io/eric2788/charts/gha-stateful-runner \
  --set runner.repoUrl=https://github.com/your-org/your-repo \
  --set runner.secret=my-runner-token
```

## Docker-in-Docker (DinD)

Enable the DinD sidecar to run Docker commands inside jobs:

```bash
helm install my-runners oci://ghcr.io/eric2788/charts/gha-stateful-runner \
  --set runner.repoUrl=https://github.com/your-org/your-repo \
  --set runner.token=YOUR_REGISTRATION_TOKEN \
  --set dind.enable=true
```

> [!WARNING]
> DinD requires `privileged: true`. Ensure your cluster's PodSecurity policy or admission controller allows privileged containers.

## Re-registering a Runner

Runner credentials are cached in a PVC. If a runner's registration is lost (runner deleted from GitHub), re-register it by deleting the PVC for the affected pod:

```bash
# 1. Update the Secret with a freshly generated registration token FIRST
#    (tokens are only valid for ~1 hour from the moment they are generated)
kubectl create secret generic <secret-name> \
  --from-literal=ui_token=NEW_REGISTRATION_TOKEN \
  --dry-run=client -o yaml | kubectl apply -f -

# 2. Delete the credential PVC and the pod (replace <N> with the pod index 0, 1, 2, …)
kubectl delete pvc runner-creds-<release-name>-gha-sts-runner-<N>
kubectl delete pod <release-name>-gha-sts-runner-<N>
```

The StatefulSet recreates the pod automatically. Because the PVC was deleted, the init container runs `config.sh` again with the new token and saves fresh credentials.

> [!NOTE]
> `whenScaled: Retain` is intentional -- scaling the StatefulSet down and back up preserves each runner's credential PVC so the runner reconnects to GitHub without re-registration. Only delete a PVC when you explicitly need to force re-registration for a specific runner.

## Uninstalling

```bash
helm uninstall <release-name>
```

Because the PVC retention policy is `whenDeleted: Delete`, uninstalling the chart deletes the StatefulSet **and all credential PVCs automatically** — no manual PVC cleanup is needed.

However, the runner entries remain registered in **GitHub Settings → Actions → Runners** as offline runners. You must remove them manually from the GitHub UI (or via the API), or GitHub will auto-remove them after approximately 14 days of inactivity.

## Autoscaling

For dynamic, queue-based autoscaling, prefer GitHub's official [Actions Runner Controller (ARC)](https://github.com/actions/actions-runner-controller) with runner scale sets.

This chart is designed for **stateful, persistent runners** with PVC-backed credentials and a fixed `runner.count`. If you need elastic scale-up/scale-down from workflow demand, use ARC instead of third-party scalers.

## Security Notes

- Runner containers run as non-root user (UID 1001) with all Linux capabilities dropped.
- The Kubernetes API token is **not** mounted by default (`automountServiceAccountToken: false`). Enable it and create appropriate RBAC only if your CI jobs need to interact with the Kubernetes API.
- DinD runs as a privileged container and should only be enabled when necessary.
- For production, use `runner.secret` to reference a pre-created (or externally managed) Secret rather than passing `runner.token` in values.
