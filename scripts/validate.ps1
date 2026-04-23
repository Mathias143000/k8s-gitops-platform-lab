$ErrorActionPreference = "Stop"
$repoRoot = Resolve-Path (Join-Path $PSScriptRoot "..")

& (Join-Path $PSScriptRoot "ensure-tools.ps1")

& python (Join-Path $repoRoot "scripts\\policy_check.py")
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

$helmPath = Join-Path $repoRoot ".tools\\bin\\helm.exe"
& $helmPath lint (Join-Path $repoRoot "gitops\\apps\\service-desk-api")
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

& $helmPath lint (Join-Path $repoRoot "gitops\\apps\\webhook-ingestion-service")
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

Push-Location $repoRoot
try {
  & docker compose config
}
finally {
  Pop-Location
}
exit $LASTEXITCODE
