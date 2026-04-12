param(
  [ValidateSet("release", "break", "rollback")]
  [string]$Action = "release"
)

$ErrorActionPreference = "Stop"
$repoRoot = Resolve-Path (Join-Path $PSScriptRoot "..")
$worktreePath = Join-Path $repoRoot "artifacts\\git\\platform-worktree"
$bareRepoPath = Join-Path $repoRoot "artifacts\\git\\platform.git"
$sourceGitopsPath = Join-Path $repoRoot "gitops"
$valuesFile = Join-Path $sourceGitopsPath "apps\\service-desk-api\\values-demo.yaml"

if (-not (Test-Path $valuesFile)) {
  throw "GitOps worktree is not ready. Run cluster-up.ps1 first."
}

$content = Get-Content $valuesFile -Raw

switch ($Action) {
  "release" {
    if ($content -match 'appVersion:\s+"2\.0\.1"') {
      $content = $content -replace 'appVersion:\s+"2\.0\.1"', 'appVersion: "2.0.2"'
    }
    elseif ($content -match 'appVersion:\s+"2\.0\.0"') {
      $content = $content -replace 'appVersion:\s+"2\.0\.0"', 'appVersion: "2.0.1"'
    }
    Set-Content -Path $valuesFile -Value $content -NoNewline
    & (Join-Path $PSScriptRoot "push-gitops.ps1") -Message "Release service-desk demo"
  }
  "break" {
    if ($content -notmatch 'readinessPath:\s+/api/does-not-exist/') {
      if ($content -match 'readinessPath:\s+/api/health/') {
        $content = $content -replace 'readinessPath:\s+/api/health/', 'readinessPath: /api/does-not-exist/'
      }
      else {
        $content += "`nreadinessPath: /api/does-not-exist/"
      }
      Set-Content -Path $valuesFile -Value $content -NoNewline
      & (Join-Path $PSScriptRoot "push-gitops.ps1") -Message "Break service-desk readiness"
    }
  }
  "rollback" {
    Push-Location $worktreePath
    try {
      & git revert --no-edit HEAD | Out-Null
      & git push origin main | Out-Null
    }
    finally {
      Pop-Location
    }

    & git -C $bareRepoPath update-server-info
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

    if (Test-Path $sourceGitopsPath) {
      Remove-Item -Recurse -Force $sourceGitopsPath
    }
    Copy-Item -Recurse -Force (Join-Path $worktreePath "gitops") $sourceGitopsPath
  }
}
