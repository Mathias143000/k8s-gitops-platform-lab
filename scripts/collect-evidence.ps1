param(
  [string]$OutputDir = (Join-Path (Resolve-Path (Join-Path $PSScriptRoot "..")) "artifacts\\evidence\\latest")
)

$ErrorActionPreference = "Stop"
New-Item -ItemType Directory -Force -Path $OutputDir | Out-Null

& kubectl get nodes -o wide | Out-File -Encoding utf8 (Join-Path $OutputDir "nodes.txt")
& kubectl get pods -A -o wide | Out-File -Encoding utf8 (Join-Path $OutputDir "pods.txt")
& kubectl get applications -n argocd | Out-File -Encoding utf8 (Join-Path $OutputDir "argocd-applications.txt")
& kubectl get ingress -A | Out-File -Encoding utf8 (Join-Path $OutputDir "ingress.txt")
& kubectl get certificates -A | Out-File -Encoding utf8 (Join-Path $OutputDir "certificates.txt")
& kubectl get hpa -A | Out-File -Encoding utf8 (Join-Path $OutputDir "hpa.txt")
& kubectl top pods -A | Out-File -Encoding utf8 (Join-Path $OutputDir "pod-metrics.txt")
& curl.exe -ks https://service-desk.127.0.0.1.sslip.io:18443/api/health/ | Out-File -Encoding utf8 (Join-Path $OutputDir "service-desk-health.json")
& curl.exe -ks https://service-desk.127.0.0.1.sslip.io:18443/api/metrics/ | Out-File -Encoding utf8 (Join-Path $OutputDir "service-desk-metrics.txt")
& curl.exe -ks https://webhook.127.0.0.1.sslip.io:18443/health | Out-File -Encoding utf8 (Join-Path $OutputDir "webhook-health.json")
& curl.exe -ks https://webhook.127.0.0.1.sslip.io:18443/metrics | Out-File -Encoding utf8 (Join-Path $OutputDir "webhook-metrics.txt")

