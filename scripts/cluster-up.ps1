param(
  [string]$ClusterName = "gitops-lab",
  [switch]$ForceRecreate
)

$ErrorActionPreference = "Stop"
$repoRoot = Resolve-Path (Join-Path $PSScriptRoot "..")
$toolsDir = Join-Path $repoRoot ".tools\\bin"
$k3dPath = Join-Path $toolsDir "k3d.exe"
$helmPath = Join-Path $toolsDir "helm.exe"

& (Join-Path $PSScriptRoot "ensure-tools.ps1")

Push-Location $repoRoot
try {
  & docker compose up -d --build git-daemon
  if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
}
finally {
  Pop-Location
}

& (Join-Path $PSScriptRoot "bootstrap-gitops-repo.ps1")
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

$repoProbeUrl = "git://127.0.0.1:9418/platform.git"
$repoReady = $false
for ($attempt = 1; $attempt -le 20; $attempt++) {
  try {
    & git ls-remote $repoProbeUrl | Out-Null
    if ($LASTEXITCODE -eq 0) {
      $repoReady = $true
      break
    }
  }
  catch {
    Start-Sleep -Seconds 2
  }
}
if (-not $repoReady) {
  throw "Local GitOps HTTP repo did not become reachable at $repoProbeUrl"
}

$clusterList = & $k3dPath cluster list 2>$null
$clusterExists = $clusterList | Select-String -Pattern "^$ClusterName\s"
if ($clusterExists -and $ForceRecreate) {
  & $k3dPath cluster delete $ClusterName
  $clusterExists = $null
}

if (-not $clusterExists) {
  & $k3dPath cluster create $ClusterName `
    --servers 1 `
    --agents 1 `
    --wait `
    --port "18080:80@loadbalancer" `
    --port "18443:443@loadbalancer" `
    --k3s-arg "--disable=traefik@server:0"
  if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
}

& $k3dPath kubeconfig merge $ClusterName --kubeconfig-switch-context
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

$apiPort = (& docker port "k3d-$ClusterName-serverlb" 6443/tcp 2>$null | Select-Object -First 1)
if ($apiPort) {
  $normalizedApiPort = ($apiPort -replace '0\.0\.0\.0:', '') -replace '\[::\]:', ''
  & kubectl config set-cluster "k3d-$ClusterName" --server="https://127.0.0.1:$normalizedApiPort" | Out-Null
}

& kubectl wait --for=condition=Ready nodes --all --timeout=180s
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

& $helmPath repo add ingress-nginx https://kubernetes.github.io/ingress-nginx | Out-Null
& $helmPath repo add jetstack https://charts.jetstack.io | Out-Null
& $helmPath repo update | Out-Null

& $helmPath upgrade --install ingress-nginx ingress-nginx/ingress-nginx `
  --namespace ingress-nginx `
  --create-namespace `
  -f (Join-Path $repoRoot "cluster\\addons\\ingress-nginx-values.yaml")
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

& $helmPath upgrade --install cert-manager jetstack/cert-manager `
  --namespace cert-manager `
  --create-namespace `
  --set installCRDs=true
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

& (Join-Path $PSScriptRoot "wait-k8s.ps1") -Namespace ingress-nginx -Kind daemonset -Name ingress-nginx-controller
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
& (Join-Path $PSScriptRoot "wait-k8s.ps1") -Namespace cert-manager -Kind deployment -Name cert-manager
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
& (Join-Path $PSScriptRoot "wait-k8s.ps1") -Namespace cert-manager -Kind deployment -Name cert-manager-webhook
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
& (Join-Path $PSScriptRoot "wait-k8s.ps1") -Namespace kube-system -Kind deployment -Name metrics-server
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

& kubectl apply -f (Join-Path $repoRoot "cluster\\addons\\selfsigned-issuer.yaml")
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

& kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply -f -
& kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/v2.13.3/manifests/install.yaml
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

& (Join-Path $PSScriptRoot "wait-k8s.ps1") -Namespace argocd -Kind deployment -Name argocd-server
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
& (Join-Path $PSScriptRoot "wait-k8s.ps1") -Namespace argocd -Kind deployment -Name argocd-repo-server
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

& (Join-Path $PSScriptRoot "build-and-import-images.ps1") -ClusterName $ClusterName
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

& kubectl apply -f (Join-Path $repoRoot "cluster\\bootstrap\\argocd-project.yaml")
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

& kubectl apply -f (Join-Path $repoRoot "cluster\\bootstrap\\argocd-apps-demo.yaml")
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

& (Join-Path $PSScriptRoot "wait-k8s.ps1") -Namespace argocd -Kind application -Name service-desk-demo -TimeoutSeconds 900
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
& (Join-Path $PSScriptRoot "wait-k8s.ps1") -Namespace argocd -Kind application -Name webhook-demo -TimeoutSeconds 900
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
& (Join-Path $PSScriptRoot "wait-k8s.ps1") -Namespace service-desk -Kind certificate -Name service-desk-demo-tls -TimeoutSeconds 300
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
& (Join-Path $PSScriptRoot "wait-k8s.ps1") -Namespace webhook -Kind certificate -Name webhook-demo-tls -TimeoutSeconds 300
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
