<# 
  deploy_render.ps1
  Déploie un app Flask sur Render en poussant la branche Git.
  Usage:
    .\deploy_render.ps1                       # auto-détection remote & 'main'
    .\deploy_render.ps1 -Branch main          # force la branche
    .\deploy_render.ps1 -RepoUrl "https://github.com/USER/REPO.git" -Branch main
    .\deploy_render.ps1 -RenderServiceUrl "https://dashboard.render.com/web/srv-XXXX"
#>

param(
  [string]$RepoUrl = "",
  [string]$Branch  = "main",
  [string]$RenderServiceUrl = ""   # colle ici l’URL de ton service web sur Render si tu l’as déjà
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Ok   ($m){ Write-Host "[OK] $m"  -ForegroundColor Green }
function Info ($m){ Write-Host "[i] $m"  -ForegroundColor Cyan }
function Warn ($m){ Write-Host "[!] $m"  -ForegroundColor Yellow }
function Err  ($m){ Write-Host "[X] $m"  -ForegroundColor Red }

# -- 0) Vérifs de base
try {
  git --version *>$null
} catch {
  Err "Git n'est pas installé ou pas dans le PATH."
  exit 1
}

# Aller à la racine du dépôt si on est dans un sous-dossier
try {
  $root = (git rev-parse --show-toplevel).Trim()
  if ($root) { Set-Location $root }
  Ok "Racine du dépôt: $root"
} catch {
  Err "Ce dossier n'est pas un dépôt Git."
  exit 1
}

# -- 1) Récupérer/valider l'URL du remote
if (-not $RepoUrl -or $RepoUrl.Trim() -eq "") {
  try {
    $RepoUrl = (git remote get-url origin).Trim()
    if (-not $RepoUrl) { throw "pas d'URL origin" }
  } catch {
    Err "Impossible de lire l'URL du remote 'origin'. Fournis -RepoUrl ""https://github.com/USER/REPO.git""."
    exit 1
  }
}
Info "Remote Git: $RepoUrl"

# -- 2) Sécuriser les fichiers indispensables pour Render

# 2.1 Procfile
$procfile = "Procfile"
$procWanted = "web: gunicorn app:app`n"
if (-not (Test-Path $procfile)) {
  Set-Content -Value $procWanted -Path $procfile -Encoding UTF8
  Ok "Créé: Procfile"
} else {
  $cur = Get-Content $procfile -Raw
  if ($cur -ne $procWanted) {
    Set-Content -Value $procWanted -Path $procfile -Encoding UTF8
    Ok "Mis à jour: Procfile"
  } else {
    Info "Procfile déjà correct."
  }
}

# 2.2 requirements.txt (versions compatibles Render)
$req = "requirements.txt"
$reqWanted = @"
Flask==3.0.3
gunicorn==21.2.0
yt-dlp==2024.8.6
requests>=2.32.2,<2.33
"@.Trim() + "`n"
if (-not (Test-Path $req)) {
  Set-Content -Value $reqWanted -Path $req -Encoding UTF8
  Ok "Créé: requirements.txt"
} else {
  # Remplace de façon fiable (on garde simple: on écrase par les versions sûres)
  Set-Content -Value $reqWanted -Path $req -Encoding UTF8
  Ok "Mis à jour: requirements.txt (versions figées et compatibles)."
}

# 2.3 render.yaml (build avec pip upgrade puis install deps, start gunicorn)
$render = "render.yaml"
$renderWanted = @"
services:
  - type: web
    name: ydd-downloader
    env: python
    plan: free
    buildCommand: pip install -U pip && pip install -r requirements.txt
    startCommand: gunicorn app:app
    envVars:
      - key: PYTHON_VERSION
        value: 3.11
"@.Trim() + "`n"
if (-not (Test-Path $render)) {
  Set-Content -Value $renderWanted -Path $render -Encoding UTF8
  Ok "Créé: render.yaml"
} else {
  $cur = Get-Content $render -Raw
  if ($cur -ne $renderWanted) {
    Set-Content -Value $renderWanted -Path $render -Encoding UTF8
    Ok "Mis à jour: render.yaml"
  } else {
    Info "render.yaml déjà correct."
  }
}

# -- 3) Vérifier qu'app.py existe et expose 'app'
if (-not (Test-Path "app.py")) {
  Warn "app.py introuvable. Je crée un squelette Flask minimal."
  $appPy = @"
from flask import Flask, render_template_string, request
app = Flask(__name__)

@app.get("/")
def index():
    return render_template_string("<h2>YDD Downloader en ligne 🎉</h2>")

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=10000)
"@
  Set-Content -Value $appPy -Path "app.py" -Encoding UTF8
  Ok "Créé: app.py (squelette)."
} else {
  Info "app.py présent."
}

# -- 4) Git: branch & commit
try {
  git checkout -B $Branch | Out-Null
  Ok "Branche '$Branch' prête."
} catch {
  Err "Impossible de créer/activer la branche '$Branch'."
  exit 1
}

git add Procfile requirements.txt render.yaml app.py 2>$null
# Ajoute aussi le reste des modifs si tu veux :
# git add -A

# S'il n'y a rien à committer, 'git commit' sort avec code 1 => on ignore l'erreur
git commit -m "chore(render): ensure Procfile/requirements/render.yaml OK + trigger deploy" 2>$null | Out-Null
Info "Commit prêt (ou déjà à jour)."

# -- 5) Push vers origin/Branch
try {
  git push -u origin $Branch
  Ok "Push effectué vers '$RepoUrl' ($Branch)."
} catch {
  Err "Échec du push. Vérifie tes droits GitHub/jeton (repo:write)."
  exit 1
}

# -- 6) Ouvrir le dashboard Render pour suivre le déploiement
if ([string]::IsNullOrWhiteSpace($RenderServiceUrl)) {
  Warn "Aucune URL de service Render fournie. J’ouvre le dashboard général."
  Start-Process "https://dashboard.render.com/"
  Info "Sur Render: vérifie que l’Auto-Deploy est activé pour ce repo/branche."
} else {
  Start-Process $RenderServiceUrl
  Info "Suis la progression ici : $RenderServiceUrl"
}

Ok "Terminé."

