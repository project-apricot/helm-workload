# Helm Workload

[![CI](https://github.com/project-apricot/helm-workload/actions/workflows/ci.yml/badge.svg)](https://github.com/project-apricot/helm-workload/actions/workflows/ci.yml)
[![License](https://img.shields.io/badge/license-Apache--2.0-blue.svg)](https://github.com/project-apricot/helm-workload/blob/main/LICENSE)

One Helm chart for **Deployments, StatefulSets, Jobs and CronJobs**, driven entirely by values.

An application repository keeps a values file and **no templates**. The chart renders the workload and
everything around it: a Service, an Ingress, ConfigMaps, ExternalSecrets, volumes, a ServiceAccount, an
autoscaler, a disruption budget and a NetworkPolicy. All of it is opt-in, nothing is assumed about the
cluster, and a **strict schema** turns a mistyped key into an error instead of a silent no-op.

## Install

The chart is published to GitHub Container Registry as an OCI artifact:

```bash
helm install my-app oci://ghcr.io/project-apricot/helm-workload/workload --version 0.1.0 -f values.yaml
```

Or depend on it from a small application chart, which is the intended use:

```yaml
# Chart.yaml
apiVersion: v2
name: my-app
version: 0.1.0
dependencies:
  - name: workload
    version: ">=0.1.0"
    repository: oci://ghcr.io/project-apricot/helm-workload
```

## Usage

```yaml
# values.yaml: everything goes under the dependency's name
workload:
  image:
    repository: registry.example.test/my-app
    tag: "1.0.0"
  replicaCount: 2
  ports:
    - name: http
      containerPort: 8080
  ingress:
    enabled: true
    host: my-app.example.test
  configMaps:
    app:
      enabled: true
      asEnv: true
      data:
        LOG_LEVEL: info
```

That renders a Deployment, a Service, an Ingress and a ConfigMap, named after the release. Switching
to a Job or a CronJob is a matter of enabling it and turning the Deployment off.

## Development

Everything runs in containers, so Docker is the only requirement:

```bash
make lint          # helm lint --strict, with the defaults and every scenario in ci/
make unittest      # helm-unittest
make kubeconform   # validate the rendered manifests against several Kubernetes versions
make docs          # regenerate docs/values.mdx from values.yaml
make all           # everything CI runs
make help          # the full list
```

`tests/` holds the unit tests. `ci/` holds the values scenarios that lint and manifest validation run
against. `docs/` is mirrored to the documentation site on release.

Pull request titles follow [Conventional Commits](https://www.conventionalcommits.org): `fix:` makes a
patch release, `feat:` a minor one, and a breaking change a major one. The values and the schema are the
chart's public interface, so removing or renaming a value counts as breaking.

Full documentation: <https://projectapricot.dev/docs/helm-workload>
