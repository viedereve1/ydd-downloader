param(
  [Parameter(Mandatory=$true)][string]$RepoUrl,      # ex: https://github.com/viedereve1/ydd-downloader.git
  [string]$Branch = "main"
)

# --- 0) Demander le token sans l'écrire dans le script ni l'historique
$Token = Read-Host "Colle ton GitHub PAT (il ne sera pas stocké)" -AsSecureString
$TokenPlain = [Runtime.InteropServices.Marshal]::PtrToStringAuto(
  [Runtime.InteropServices.Marshal]::SecureStringToBSTR($Token)
)

function Ok  ($m){ Write-Host "Ok  $m"  -ForegroundColor Green }
function Info($m){ Write-Host "Info $m" -ForegroundColor Cyan  }
function Warn($m){ Write-Host "⚠ $m"    -ForegroundColor Yellow}
function Err ($m){ Write-Host "[X] $m"  -ForegroundColor Red   }

# --- 1) Vérifs de base
git rev-parse --is-inside-work-tree 2>$null | Out-Null
if ($LASTEXITCODE -ne 0) { Err "Pas un repo Git ici."; exit 1 }

$cleanPatterns = @(
  ".tools/ffmpeg/bin/ffmpeg.exe",
  ".tools/ffmpeg/bin/ffplay.exe",
  ".tools/ffmpeg/bin/ffprobe.exe",
  "downloads",
  "__pycache__",
  "*.log",
  ".DS_Store",
  "*.mp4",
  "*.zip",
  "*.bin",
  "*.dll",
  "*.exe"
)

# --- 2) Nettoyage historique (préfère filter-repo si dispo)
function HaveFilterRepo {
  git filter-repo -h 1>$null 2>$null
  return ($LASTEXITCODE -eq 0)
}

Info "Nettoyage de l'historique…"
if (HaveFilterRepo) {
  $pathsFile = "$env:TEMP\paths-to-remove.txt"
  $cleanPatterns | Set-Content -Encoding UTF8 $pathsFile
  git filter-repo --force --paths-from-file "$pathsFile" --invert-paths
  if ($LASTEXITCODE -ne 0) { Err "git filter-repo a échoué."; exit 1 }
  Ok  "filter-repo effectué."
} else {
  Warn "git-filter-repo indisponible → fallback git filter-branch (plus lent)."
  $indexCmd = "git rm -r --cached --ignore-unmatch " + ($cleanPatterns -join ' ')
  git filter-branch --force --index-filter "$indexCmd" --prune-empty --tag-name-filter cat -- --all
  if ($LASTEXITCODE -ne 0) { Err "filter-branch a échoué."; exit 1 }
  Ok  "filter-branch effectué."
}

# --- 3) Garbage-collect / repack
Info "Optimisation du dépôt…"
git reflog expire --expire-unreachable=now --all
git gc --prune=now --aggressive
Ok  "Optimisation terminée."

# --- 4) S'assurer d'avoir un .gitignore minimal
$gi = ".gitignore"
if (-not (Test-Path $gi)) { New-Item $gi -ItemType File | Out-Null }
@"
__pycache__/
downloads/
*.log
*.zip
*.mp4
*.bin
*.dll
*.exe
.DS_Store
"@ | Out-File -Encoding utf8 $gi
git add .gitignore; git commit -m "chore: add .gitignore (skip large/binary files)" --allow-empty | Out-Null

# --- 5) Config remote (tolère l'absence d'origin)
try { git remote remove origin 2>$null } catch {}
$RepoUrlClean = $RepoUrl.Trim()
$remoteWithToken = $RepoUrlClean.Replace("https://", "https://$($TokenPlain)@")

git remote add origin "$remoteWithToken"
Ok "Remote (avec token temporaire) configuré."

# --- 6) Définir/renommer la branche
git branch -M $Branch 2>$null

# --- 7) Push forcé (toutes les refs)
Info "Push forcé vers '$RepoUrlClean'…"
git push -u origin $Branch --force
if ($LASTEXITCODE -ne 0) {
  Err "Échec du push principal."; exit 1
}
git push origin --force --tags 2>$null

# --- 8) Remettre une URL propre (sans token)
Info "Nettoyage de l'URL du remote (retrait du token)…"
git remote set-url origin "$RepoUrlClean"
Ok "Remote nettoyé."

# --- 9) Fin
Ok "Tout est terminé ✅. Vérifie sur GitHub : $RepoUrlClean"
