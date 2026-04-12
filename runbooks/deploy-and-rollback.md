# Deploy and Rollback Runbook

## Bootstrap

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\validate.ps1
powershell -ExecutionPolicy Bypass -File .\scripts\cluster-up.ps1
```

Expected result:

- `Argo CD` applications are `Healthy` and `Synced`
- both workload health endpoints return `200`
- `kubectl top pods -A` returns metrics

## Release

Use a Git commit as the release trigger:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\demo-rollout.ps1 -Action release
```

The script changes the demo values for `service-desk-api`, commits the change into the local GitOps repo, and pushes it to the local remote. `Argo CD` reconciles the change automatically.

## Failed release

To simulate a degraded release:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\demo-rollout.ps1 -Action break
```

This intentionally writes a broken readiness path to the `service-desk-api` demo values, which should lead to an unhealthy rollout.

## Rollback

Rollback is done through Git, not by editing the cluster manually:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\demo-rollout.ps1 -Action rollback
```

The script reverts the latest GitOps commit and pushes the revert, allowing `Argo CD` to reconcile the cluster back to the last healthy revision.

## Local GitOps source

The local source-of-truth repo is exposed over Git protocol on `git://127.0.0.1:9418/platform.git`. Inside the cluster, `Argo CD` reads it through `git://host.k3d.internal:9418/platform.git`.

## Evidence collection

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\collect-evidence.ps1
```

## Cleanup

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\cluster-down.ps1
```
