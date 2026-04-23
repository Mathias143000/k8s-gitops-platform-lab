from __future__ import annotations

import json
import re
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
CHARTS = (
    ROOT / "gitops" / "apps" / "service-desk-api",
    ROOT / "gitops" / "apps" / "webhook-ingestion-service",
)


def read(path: Path) -> str:
    return path.read_text(encoding="utf-8")


def fail(errors: list[str], message: str) -> None:
    errors.append(message)


def image_tags(text: str) -> list[str]:
    return re.findall(r"^\s*tag:\s*[\"']?([^\"'\s]+)[\"']?", text, flags=re.MULTILINE)


def main() -> int:
    errors: list[str] = []

    project = read(ROOT / "cluster" / "bootstrap" / "argocd-project.yaml")
    if '- "*"' in project or "group: \"*\"" in project or "kind: \"*\"" in project:
        fail(errors, "Argo CD AppProject must not use wildcard source or resource permissions")
    if "git://host.k3d.internal:9418/platform.git" not in project:
        fail(errors, "Argo CD AppProject must scope sourceRepos to the local GitOps remote")
    for marker in ["kind: Namespace", "kind: Deployment", "kind: Service", "kind: Secret", "kind: Ingress"]:
        if marker not in project:
            fail(errors, f"Argo CD AppProject is missing allowed resource marker: {marker}")

    ci = read(ROOT / ".github" / "workflows" / "ci.yml")
    for marker in ["GitOps policy check", "scripts/policy_check.py", "Trivy config scan"]:
        if marker not in ci:
            fail(errors, f"CI is missing hardening marker: {marker}")

    for chart in CHARTS:
        values = read(chart / "values.yaml")
        deployment = read(chart / "templates" / "deployment.yaml")

        for tag in image_tags(values):
            if tag == "latest":
                fail(errors, f"{chart.name} must not use the mutable latest image tag")

        required_values = [
            "resources:",
            "requests:",
            "limits:",
            "revisionHistoryLimit:",
            "progressDeadlineSeconds:",
            "podSecurityContext:",
            "containerSecurityContext:",
            "allowPrivilegeEscalation: false",
            "drop:",
            "- ALL",
            "RuntimeDefault",
        ]
        for marker in required_values:
            if marker not in values:
                fail(errors, f"{chart.name} values.yaml is missing hardening marker: {marker}")

        required_template_markers = [
            "readinessProbe:",
            "livenessProbe:",
            "resources:",
            "revisionHistoryLimit:",
            "progressDeadlineSeconds:",
            ".Values.podSecurityContext",
            ".Values.containerSecurityContext",
        ]
        for marker in required_template_markers:
            if marker not in deployment:
                fail(errors, f"{chart.name} deployment template is missing marker: {marker}")

    report = {
        "status": "failed" if errors else "passed",
        "checks": [
            "Argo CD project avoids wildcard source/resource permissions",
            "CI runs GitOps policy check and Trivy config scan",
            "charts avoid latest image tags",
            "charts declare probes, resources, rollout history, and progress deadlines",
            "charts declare baseline pod/container security contexts",
        ],
        "errors": errors,
    }
    output_dir = ROOT / "artifacts" / "policy"
    output_dir.mkdir(parents=True, exist_ok=True)
    (output_dir / "policy-report.json").write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")

    if errors:
        for error in errors:
            print(f"ERROR: {error}", file=sys.stderr)
        return 1

    print("GitOps policy checks passed.")
    print(f"Report: {output_dir / 'policy-report.json'}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
