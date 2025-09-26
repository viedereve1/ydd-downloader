# fix_and_deploy.ps1
# But : corriger requirements.txt + Procfile puis pousser sur GitHub (déploie Render)

param(
  [string]$CommitMessage = "chore: fix requirements and Procfile for Render",
  [string]$Branch = "main"
)

# --- Utilitaire d’écriture UTF8 sans BOM ---
function Write-Utf8NoBom($Path, $Content) {
  $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
  [System.IO.File]::WriteAllText($Path, $Content -join "`n", $utf8NoBom)
}

# --- 1) requirements.txt minimal compatible ---
$reqPath = "requirements.txt"
$requirements = @'
Flask==3.0.3
gunicorn==21.2.0
yt-dlp==2024.8.6
requests>=2.32.2
'@.Trim()

# --- 2) Procfile pour gunicorn ---
$procPath = "Procfile"
$procfile = "web: gunicorn app:app"

# --- 3) Écrire / mettre à jour les fichiers ---
Write-Host "[i] Mise à jour de $reqPath et $procPath ..." -ForegroundColor Cyan
Write-Utf8NoBom $reqPath $requirements
Write-Utf8NoBom $procPath $procfile

# --- 4) Git add/commit/push ---
# S’assure d’être sur la branche voulue
git rev-parse --abbrev-ref HEAD | Out-Null
if ($LASTEXITCODE -ne 0) { throw "Git n'est pas initialisé dans ce dossier." }

# Crée la branche si elle n’existe pas localement
git checkout -B $Branch | Out-Null

# Ajoute les fichiers et commit s'il y a des changements
git add $reqPath $procPath

# Vérifie s'il y a quelque chose à committer
$pending = git status --porcelain
if ([string]::IsNullOrWhiteSpace($pending)) {
  Write-Host "[=] Rien à committer (déjà à jour)." -ForegroundColor Yellow
} else {
  git commit -m "$CommitMessage"
  if ($LASTEXITCODE -ne 0) { throw "Echec du commit." }
}

# Push vers origin/$Branch (déclenche Render Auto-Deploy)
Write-Host "[>] Push vers origin/$Branch ..." -ForegroundColor Cyan
git push -u origin $Branch
if ($LASTEXITCODE -ne 0) { throw "Echec du push. Vérifie l'accès au dépôt." }

Write-Host "[OK] Push effectué. Render va (re)déployer automatiquement." -ForegroundColor Green
Write-Host "Ouvre ton service Render et regarde les logs de build si besoin." -ForegroundColor Green
