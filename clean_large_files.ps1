# ===============================
# clean_large_files.ps1
# Supprime de l'index Git les fichiers > 100 MB,
# retire les binaires FFmpeg et met à jour .gitignore
# ===============================

$ErrorActionPreference = "Stop"

function Info($m){ Write-Host "[i] $m" -ForegroundColor Cyan }
function Ok($m){ Write-Host "[] $m" -ForegroundColor Green }
function Warn($m){ Write-Host "[!] $m" -ForegroundColor Yellow }
function Err($m){ Write-Host "[x] $m" -ForegroundColor Red }

# Limite GitHub (100 MB)
$limit = 100MB

Info "Scan des fichiers > 100 MB (workspace)..."
$bigFiles = Get-ChildItem -Recurse -File | Where-Object { $_.Length -gt $limit }

if ($bigFiles.Count -gt 0) {
  $bigFiles | ForEach-Object {
    $rel = Resolve-Path -Relative $_.FullName
    Warn "Retrait de l'index (trop gros) : $rel"
    git rm --cached --force -- "$rel" | Out-Null
  }
} else {
  Ok "Aucun fichier > 100 MB dans le workspace."
}

# Retrait ciblé : binaires FFmpeg (souvent > 100 MB)
$ffmpegDir = ".tools/ffmpeg/bin"
if (Test-Path $ffmpegDir) {
  Warn "Retrait de l'index du dossier FFmpeg : $ffmpegDir"
  git rm --cached -r --force -- "$ffmpegDir" | Out-Null
} else {
  Info "Dossier FFmpeg non trouvé : $ffmpegDir (ok)"
}

# .gitignore : s'assurer que ces chemins sont ignorés
$ignoreLines = @(
  "",
  "# === Binaries & larges fichiers ===",
  ".tools/ffmpeg/bin/",
  "downloads/",
  "*.mp4",
  "*.mov",
  "*.mkv",
  "*.zip",
  "*.exe",
  "*.iso"
)

if (-not (Test-Path ".gitignore")) { New-Item -ItemType File -Path ".gitignore" | Out-Null }

$gi = Get-Content ".gitignore" -Raw
$toAppend = @()
foreach ($line in $ignoreLines) {
  if ($line -ne "" -and $gi -match [regex]::Escape($line)) { continue }
  $toAppend += $line
}
if ($toAppend.Count -gt 0) {
  Add-Content -Path ".gitignore" -Value ($toAppend -join [Environment]::NewLine)
  Ok ".gitignore mis à jour."
} else {
  Info ".gitignore déjà à jour."
}

# Commit du nettoyage
git add .gitignore
git add -A

# S'il n'y a rien à commit, git renverra un code différent ; on gère ça proprement
$changes = git status --porcelain
if ([string]::IsNullOrWhiteSpace($changes)) {
  Info "Rien à commit (working tree clean)."
} else {
  git commit -m "chore: remove >100MB files (ffmpeg, media) and update .gitignore" | Out-Null
  Ok "Commit de nettoyage effectué."
}

Ok "Nettoyage terminé."
