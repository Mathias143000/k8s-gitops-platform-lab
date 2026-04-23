# GitOps Hardening

This repository is the baseline GitOps lab, so the hardening scope is intentionally smaller than `enterprise-onprem-platform-lab`.

## What Is Covered

- Argo CD `AppProject` source repository is scoped to the local GitOps remote
- Argo CD project resource permissions avoid wildcard `*` grants
- Helm charts avoid mutable `latest` image tags
- workload charts declare probes, resource requests, limits, rollout history, and progress deadlines
- workload charts include baseline pod/container security contexts
- CI runs Helm lint, repo-local GitOps policy checks, and Trivy config scan

## Local Validation

```powershell
python scripts\policy_check.py
powershell -ExecutionPolicy Bypass -File .\scripts\validate.ps1
```

The policy check writes a local report to:

```text
artifacts/policy/policy-report.json
```

The report is intentionally ignored by Git. It is runtime evidence for local review, not source code.

## Deliberate Trade-Offs

- `SOPS` remains backlog because this repo is still the clean GitOps baseline; the heavier secret-management story belongs in `enterprise-onprem-platform-lab`.
- `cosign` remains backlog because the local image flow uses `k3d` image import instead of a registry-backed promotion chain.
- Admission enforcement remains backlog because this wave focuses on repo-local guardrails and CI-visible policy checks.

## Remaining Backlog

- SOPS-encrypted values
- cosign image signing with registry-backed promotion
- admission policy enforcement
- deeper failure drill documentation with SLI/SLO notes
