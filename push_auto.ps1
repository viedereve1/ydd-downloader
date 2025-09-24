param(
  [Parameter(Mandatory = $true)][string]$Token,          # ton PAT GitHub (ghp_...)
  [string]$User      = "viedereve1",                     # ton nom d'utilisateur GitHub
  [string]$Repo      = "ydd-downloader",                 # nom du dépôt GitHub
  [string]$Branch    = "main",                           # branche cible
  [string]$CommitMsg = "deploy: auto push"               # message de commit
)

function Ok  ($m){ Write-Host "[OK]  $m" -ForegroundColor Green }
function Info($m){ Write-Host "[i]   $m" -ForegroundColor Cyan  }
function Err ($m){ Write-Host "[X]   $m" -ForegroundColor Red; exit 1 }

# 0) Se placer dans le dossier du script
$root = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $root

# 1) Vérif git
git --version | Out-Null
if ($LASTEXITCODE -ne 0) { Err "Git n'est pas installé dans le PATH." }

# 2) Initialiser le repo si nécessaire
if (-not (Test-Path ".git")) {
  git init | Out-Null
  Ok "Dépôt Git initialisé"
}

# 3) .gitignore (évite les gros fichiers/dirs)
$gitignore = ".gitignore"
$patterns = @(
  "/downloads/",
  "/.tools/ffmpeg/",
  "/.venv/",
  "/_pycache_/",
  "*.pyc",
  ".DS_Store",
  "*.log"
)
if (-not (Test-Path $gitignore)) {
  $patterns -join "`n" | Set-Content $gitignore -Encoding utf8
  Ok ".gitignore créé"
} else {
  foreach ($p in $patterns) {
    if (-not (Select-String -Path $gitignore -Pattern ([regex]::Escape($p)) -Quiet)) {
      Add-Content $gitignore $p
    }
  }
}

# 4) Config remote avec token (sans l’enregistrer en dur dans le code)
$remoteUrl = "https://$Token@github.com/$User/$Repo.git"
$hasOrigin = (git remote) -contains "origin"
if ($hasOrigin) {
  git remote set-url origin $remoteUrl | Out-Null
} else {
  git remote add origin $remoteUrl | Out-Null
}
Ok "Remote 'origin' prêt → https://github.com/$User/$Repo"

# 5) Forcer le nom de branche
git branch -M $Branch | Out-Null
Ok "Branche active : $Branch"

# 6) Stage & commit
git add -A | Out-Null
$changes = git status --porcelain
if ([string]::IsNullOrWhiteSpace($changes)) {
  Info "Aucun changement à committer (working tree clean)"
} else {
  git commit -m $CommitMsg | Out-Null
  Ok "Commit effectué : $CommitMsg"
}

# 7) Push
try {
  git push -u origin $Branch
  if ($LASTEXITCODE -ne 0) { Err "Échec du push" }
  Ok "Push réussi vers https://github.com/$User/$Repo"
} catch {
  Err $_.Exception.Message
}