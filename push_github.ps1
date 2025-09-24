param(
  [string]$RepoURL,     # ex: https://github.com/USER/REPO.git
  [string]$UserName = "Ton Nom",
  [string]$UserEmail = "ton@mail.com",
  [string]$CommitMsg = "deploy: initial push"
)

function Ok ($m) { Write-Host "[OK] $m" -ForegroundColor Green }
function Info ($m) { Write-Host "[INFO] $m" -ForegroundColor Cyan }
function Warn ($m) { Write-Host "[WARN] $m" -ForegroundColor Yellow }
function Err ($m) { Write-Host "[ERR] $m" -ForegroundColor Red }

try {
  # 1) Vérif chemin projet
  $root = Get-Location
  Info "Projet: $root"

  # 2) Init repo si absent
  if (-not (Test-Path ".git")) {
    git init | Out-Null
    Ok "Repo git initialisé."
  }

  # 3) Config user
  if ($UserName -ne "") { git config user.name "$UserName" }
  if ($UserEmail -ne "") { git config user.email "$UserEmail" }

  # 4) .gitignore auto (si absent)
  $gi = Join-Path $root ".gitignore"
  if (-not (Test-Path $gi)) {
    @"
# === YDD Downloader ===
.venv/
env/
downloads/
__pycache__/
*.pyc
*.log
.DS_Store
tools/
.tools/
"@ | Set-Content -Path $gi -Encoding UTF8
    Ok ".gitignore créé."
  }

  # 5) Définir/valider l’URL distante
  $originSet = (& git remote) -contains "origin"
  if (-not $originSet) {
    git remote add origin $RepoURL
    Ok "Remote ajouté: $RepoURL"
  } else {
    git remote set-url origin $RepoURL
    Ok "Remote mis à jour: $RepoURL"
  }

  # 6) Ajouter tous les fichiers
  git add -A
  Ok "Fichiers ajoutés."

  # 7) Commit (même si vide ça passe)
  git commit -m "$CommitMsg" --allow-empty
  Ok "Commit effectué: $CommitMsg"

  # 8) Branche main + push
  git branch -M main
  git push -u origin main
  Ok "Projet envoyé avec succès sur GitHub !"

} catch {
  Err "Échec: $($_.Exception.Message)"
}
