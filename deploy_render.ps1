<# 
  Déploiement automatique sur Railway (Dockerfile)
  - Vérifie Dockerfile / requirements / Procfile (optionnel)
  - Vérifie git & push
  - Installe Railway CLI si besoin (via npm)
  - Ouvre la connexion (login) Railway
  - Déploie avec `railway up` en utilisant le Dockerfile
#>

param(
  [string]$ServiceName = "ydd-downloader",
  [string]$Region = "eu",            # eu | us | ap (Railway choisit tout seul si non supporté)
  [switch]$SetEnv,                   # ex: -SetEnv pour injecter des variables (voir $envs ci-dessous)
  [string]$Branch = "main"
)

function Ok($m){ Write-Host "[OK] $m" -ForegroundColor Green }
function Info($m){ Write-Host "[i] $m" -ForegroundColor Cyan }
function Warn($m){ Write-Host "[!] $m" -ForegroundColor Yellow }
function Err($m){ Write-Host "[X] $m" -ForegroundColor Red }

# 0) Vérifs de base
if (-not (Test-Path -Path ".\Dockerfile")) {
  Err "Aucun Dockerfile trouvé à la racine. Ce script déploie via Dockerfile."
  Err "Crée un Dockerfile ou renomme 'dockerfile' en 'Dockerfile'."
  exit 1
}

# 1) Git propre + push
try {
  git --version *>$null
} catch {
  Err "Git n'est pas installé dans PATH."
  exit 1
}

# initialisation git si besoin
if (-not (Test-Path ".git")) {
  Info "Initialisation du repo git…"
  git init | Out-Null
  git add . ; git commit -m "init" | Out-Null
}

# vérifier remote
$remoteUrl = (git remote get-url origin 2>$null)
if ([string]::IsNullOrWhiteSpace($remoteUrl)) {
  Warn "Aucun remote 'origin'. Ajoute ton repo GitHub maintenant."
  $remoteCandidate = Read-Host "Colle l'URL de ton repo (ex: https://github.com/<user>/<repo>.git)"
  if ([string]::IsNullOrWhiteSpace($remoteCandidate)) {
    Err "Pas d'URL fournie."
    exit 1
  }
  git remote add origin $remoteCandidate
  $remoteUrl = $remoteCandidate
  Ok "Remote ajouté: $remoteUrl"
} else {
  Info "Remote origin: $remoteUrl"
}

# branch courante => forcer $Branch si différent
$currentBranch = (git branch --show-current)
if ($currentBranch -ne $Branch) {
  Info "Bascule sur branche '$Branch'…"
  git checkout -B $Branch | Out-Null
}

# commit si changements
$changed = (git status --porcelain)
if ($changed) {
  Info "Changements détectés → commit…"
  git add .
  git commit -m "chore: prepare Railway deploy (Dockerfile)" | Out-Null
} else {
  Info "Aucun changement à committer."
}

Info "Push vers origin/$Branch…"
git push -u origin $Branch
if ($LASTEXITCODE -ne 0) { Err "Échec du push. Corrige puis relance."; exit 1 }
Ok "Push effectué."

# 2) Railway CLI
function Has-Cmd($name){
  $null -ne (Get-Command $name -ErrorAction SilentlyContinue)
}

if (-not (Has-Cmd "railway")) {
  Warn "Railway CLI absent. Tentative d'installation via npm…"
  if (Has-Cmd "npm") {
    npm i -g @railway/cli
    if (-not (Has-Cmd "railway")) {
      Err "Installation CLI échouée. Installe Node/npm et refais: npm i -g @railway/cli"
      exit 1
    }
    Ok "Railway CLI installé."
  } else {
    Err "npm n'est pas dispo. Installe Node.js (inclut npm) puis refais: npm i -g @railway/cli"
    Start-Process "https://nodejs.org/en/download"
    exit 1
  }
} else {
  Info "Railway CLI détecté."
}

# 3) Login Railway (ouvre le navigateur)
Info "Connexion Railway (une page web va s’ouvrir)…"
railway login
if ($LASTEXITCODE -ne 0) { Err "Login Railway annulé/échoué."; exit 1 }

# 4) Optionnel : variables d'environnement à pousser sur Railway
# Mets tes variables ici si tu passes -SetEnv au script
$envs = @{
  # "FLASK_ENV" = "production"
  # "SECRET_KEY" = "change_me"
  # "SOME_API_KEY" = "..."
}
if ($SetEnv -and $envs.Count -gt 0) {
  Info "Injection des variables d'environnement Railway…"
  foreach ($k in $envs.Keys) {
    railway variables set "$($k)=$($envs[$k])"
    if ($LASTEXITCODE -ne 0) { Warn "Impossible de définir la variable $k (tu pourras la mettre dans le dashboard Railway)." }
  }
}

# 5) Déploiement (Dockerfile auto-détecté)
# Astuce: si l'app écoute sur un port, Railway attend $PORT fourni par la plateforme.
# Assure-toi que ton CMD/entrypoint utilise $PORT (gunicorn app:app -b 0.0.0.0:$PORT)
Info "Déploiement en cours (railway up)…"
railway up --service $ServiceName --detach
if ($LASTEXITCODE -ne 0) {
  Warn "railway up non supporté sur ton compte/plan ?"
  Warn "Ouverture du dashboard pour déployer manuellement depuis GitHub (Dockerfile détecté automatiquement)…"
  Start-Process "https://railway.app/new"
  Ok "Dans Railway : New Project → Deploy from GitHub → choisis ton repo → confirme."
  exit 0
}

Ok "Déploiement demandé. Ouvre le dashboard pour voir les logs:"
$dash = "https://railway.app/project"
Write-Host "   $dash" -ForegroundColor Cyan
Ok "Terminé."
