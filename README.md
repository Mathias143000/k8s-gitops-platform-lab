# k8s-gitops-platform-lab

Runnable Kubernetes + GitOps showcase built around `k3d`, `Argo CD`, `Helm`, `ingress-nginx`, `cert-manager`, and two real portfolio workloads.

The goal is to prove a believable local GitOps flow end to end:

- local cluster bootstrap
- local Git remote as source of truth
- `Argo CD` sync into the cluster
- TLS through ingress
- reproducible rollout and rollback
- basic workload metrics and autoscaling primitives

## What this project demonstrates

- `k3d` cluster bootstrap on a clean machine
- `Argo CD` syncing from a local Git remote
- `Helm` charts for two real workloads:
  - `service-desk-api`
  - `webhook-ingestion-service`
- `Ingress NGINX` + `cert-manager` self-signed TLS for local demo traffic
- `metrics-server` + HPA baseline for workload scaling
- reproducible release and rollback flow driven by Git commits

## Fixed stack

- `k3d`
- `Helm`
- `Argo CD`
- `Ingress NGINX`
- `cert-manager`
- `metrics-server`
- `HPA`
- `Trivy` config scan in CI

Items intentionally left for a later hardening pass are called out in [todo.md](todo.md).

## Architecture

See [docs/architecture.md](docs/architecture.md) for the diagram and dependency wiring.

## Quick demo flow

1. Validate charts and bootstrap tooling:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\validate.ps1
```

2. Start the cluster and sync both workloads:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\cluster-up.ps1
```

3. Check the workloads through ingress:

```powershell
curl.exe -ks https://service-desk.127.0.0.1.sslip.io:18443/api/health/
curl.exe -ks https://webhook.127.0.0.1.sslip.io:18443/health
```

4. Trigger a release commit:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\demo-rollout.ps1 -Action release
```

5. Trigger a failed release and rollback:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\demo-rollout.ps1 -Action break
powershell -ExecutionPolicy Bypass -File .\scripts\demo-rollout.ps1 -Action rollback
```

6. Collect evidence:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\collect-evidence.ps1
```

## Workload packaging choices

The lab deliberately deploys the API paths of `service-desk-api` and `webhook-ingestion-service` in their minimal runnable modes:

- `service-desk-api` runs with SQLite and async tasks disabled
- `webhook-ingestion-service` runs with SQLite and inline queue mode

This keeps the first GitOps lab focused on cluster delivery, ingress, TLS, sync, and rollback, instead of re-building the entire dependency topology of each workload inside the cluster. The fuller stateful and enterprise storage stories are covered later by the portfolio.

## Operational evidence

The evidence bundle is written to `artifacts/evidence/latest/` and includes:

- node and pod inventory
- Argo CD application status
- ingress and certificate state
- `kubectl top` output
- HPA state
- health and metrics samples from both workloads

## CI Scope Today

The current CI path intentionally stays lightweight and validates the repository as a baseline GitOps lab:

- `Helm` chart lint for both workloads
- `Trivy` config scan

The full runtime bootstrap, sync, and rollback proof still lives in the local operator path described in this README and in [runbooks/deploy-and-rollback.md](runbooks/deploy-and-rollback.md). That is a deliberate trade-off: this repo optimizes for a clean GitOps teaching/demo path, while the heavier platform proof is delegated to `enterprise-onprem-platform-lab`.

## Runbook

See [runbooks/deploy-and-rollback.md](runbooks/deploy-and-rollback.md) for bootstrap, release, rollback, and cleanup steps.

## Known limitations

- `SOPS`, `cosign`, and admission policy enforcement are not part of the first DoD slice yet. They remain backlog items for the security-hardening pass.
- The local GitOps remote is served through a lightweight `git daemon` container for simplicity. It is good enough for a real local Argo CD sync, but it is not the same thing as a production Git hosting setup.
- The workloads are deployed in their minimal API-ready modes, not with their full async/stateful dependency graphs.
- TLS is issued through a self-signed local `ClusterIssuer`, which is appropriate for the lab but not for a production public endpoint.
- This repository intentionally stops before the broader enterprise platform shell so it does not duplicate the role of `enterprise-onprem-platform-lab`.

## Backlog / future improvements

- Add `SOPS`-encrypted secrets in the GitOps repo
- Add `cosign` signing and policy checks for unsigned images
- Add `ShareChat` as the stretch real-time workload
- Add failure drill documentation with explicit SLI/SLO notes
- Extend the lab with a real registry-backed image promotion flow
