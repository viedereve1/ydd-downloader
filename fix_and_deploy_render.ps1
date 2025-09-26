# fix_and_deploy_render.ps1
# But : normaliser app.py / Procfile / render.yaml / requirements.txt,
# puis commit & push sur 'main' pour (re)déclencher le déploiement Render.

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Info([string]$msg){ Write-Host "[i] $msg" -ForegroundColor Cyan }
function Ok([string]$msg){ Write-Host "[OK] $msg" -ForegroundColor Green }
function Warn([string]$msg){ Write-Host "[!] $msg" -ForegroundColor Yellow }
function Err([string]$msg){ Write-Host "[X] $msg" -ForegroundColor Red }

# --- 0) Vérifs rapides ---
if (-not (Test-Path ".git")) { Err "Ici ce n'est pas un dépôt Git."; exit 1 }
# Branche actuelle
$branch = (git rev-parse --abbrev-ref HEAD).Trim()
if ([string]::IsNullOrWhiteSpace($branch)) { $branch = "main" }

# --- 1) Helpers ---
function New-Backup([string]$path){
  if (Test-Path $path){
    $stamp = Get-Date -Format "yyyyMMdd-HHmmss"
    Copy-Item $path "$path.bak.$stamp" -Force
  }
}

function Write-If-Changed([string]$path, [string]$content){
  $needsWrite = $true
  if (Test-Path $path){
    $existing = Get-Content $path -Raw -ErrorAction SilentlyContinue
    if ($existing -eq $content){ $needsWrite = $false }
  }
  if ($needsWrite){
    New-Backup $path
    # Forcer UTF-8 sans BOM
    $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
    [System.IO.File]::WriteAllText((Resolve-Path $path), $content, $utf8NoBom)
    return $true
  }
  return $false
}

# --- 2) Contenus normalisés ---

$appPy = @"
from flask import Flask, request, render_template, jsonify
import os

app = Flask(__name__)

@app.route("/")
def home():
    return "✅ YDD Downloader en ligne !", 200

# Health check pour plateformes (Render, etc.)
@app.route("/health")
def health():
    return jsonify(status="ok"), 200

if __name__ == "__main__":
    port = int(os.environ.get("PORT", 8000))
    app.run(host="0.0.0.0", port=port)
"@

$procfile = "web: gunicorn app:app`n"

$renderYaml = @"
services:
  - type: web
    name: ydd-downloader
    env: python
    buildCommand: pip install -U pip && pip install -r requirements.txt
    startCommand: gunicorn app:app
    envVars:
      - key: PYTHON_VERSION
        value: 3.11
"@

$requirements = @"
Flask==3.0.3
gunicorn==21.2.0
yt-dlp==2024.8.6
requests>=2.32.2,<2.33
"@

# --- 3) Écriture des fichiers (idempotent) ---

$changed = $false

# a) app.py : si absent ou sans 'app = Flask(' on le remplace par un minimal viable
$needApp = $true
if (Test-Path "app.py"){
  $raw = Get-Content "app.py" -Raw
  if ($raw -match "(?m)^\s*app\s*=\s*Flask\("){ $needApp = $false }
}
if ($needApp){
  if (Write-If-Changed "app.py" $appPy){ Ok "app.py normalisé."; $changed = $true } else { Info "app.py déjà correct." }
} else {
  Info "app.py détecté avec app = Flask(...), on ne remplace pas."
}

# b) Procfile
if (Write-If-Changed "Procfile" $procfile){ Ok "Procfile mis à jour." ; $changed = $true } else { Info "Procfile déjà à jour." }

# c) render.yaml
if (Write-If-Changed "render.yaml" $renderYaml){ Ok "render.yaml mis à jour." ; $changed = $true } else { Info "render.yaml déjà à jour." }

# d) requirements.txt
if (Write-If-Changed "requirements.txt" $requirements){ Ok "requirements.txt mis à jour." ; $changed = $true } else { Info "requirements.txt déjà à jour." }

# --- 4) Git add / commit / push ---
# Ajoute même si rien n'a changé pour sécuriser la suite
git add app.py Procfile render.yaml requirements.txt | Out-Null

# Commit seulement s'il y a des changements staged
$hasDiff = (git diff --cached --quiet) ; $exit = $LASTEXITCODE
if ($exit -ne 0){
  Info "Commit des modifications…"
  git commit -m "chore(render): ensure Procfile/app.py and pin requirements; ready for Render" | Out-Null
  Ok "Commit effectué."
} else {
  Warn "Aucun changement à committer (déjà à jour)."
}

# Vérifie l'origine
try {
  $remote = (git remote get-url origin).Trim()
  Info "Remote : $remote"
} catch {
  Err "Pas de remote 'origin'. Configure d'abord : git remote add origin <URL>"
  exit 1
}

Info "Push vers '$branch'…"
git push origin $branch | Out-Null
Ok "Push effectué."

Warn "Render va normalement déclencher un déploiement auto sur ce push."
Ok "Si besoin, déclenche manuellement dans Render : Deploy → Deploy latest commit."

# Lien pratique (si ton service existe déjà et s’appelle ydd-downloader)
Info "Dashboard Render (à adapter au besoin) : https://dashboard.render.com/"
Ok "Terminé."
