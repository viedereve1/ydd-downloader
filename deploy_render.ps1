<# ===========================
   deploy_render.ps1
   Déclenche un déploiement Render en poussant sur origin/main
   et affiche le lien du dashboard.
   =========================== #>

# --- Helpers propres (sans caractères spéciaux) ---
function Info($m){  Write-Host "[i] $m"  -ForegroundColor Cyan }
function Ok($m){    Write-Host "[OK] $m" -ForegroundColor Green }
function Warn($m){  Write-Host "[!] $m"  -ForegroundColor Yellow }
function Err($m){   Write-Host "[X] $m"  -ForegroundColor Red }

param(
    [string]$RenderServiceId  # Ex.: "srv-d3a...210" (avec ou sans "srv-")
)

# 0) Paramètres & prérequis
try {
    if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
        throw "Git n'est pas installé ou pas dans le PATH."
    }

    if (-not $RenderServiceId -or [string]::IsNullOrWhiteSpace($RenderServiceId)) {
        $RenderServiceId = Read-Host "Entre l'ID du service Render (ex: srv-xxxxxxxxxxxx)"
    }

    # Normaliser: s'assurer que ça commence par 'srv-'
    if ($RenderServiceId -notmatch '^srv-') {
        $RenderServiceId = "srv-$RenderServiceId"
    }
}
catch {
    Err $_.Exception.Message
    exit 1
}

# 1) Vérifier qu'on est dans un repo git et sur une branche
try {
    $null = git rev-parse --is-inside-work-tree 2>$null
    if ($LASTEXITCODE -ne 0) { throw "Ce dossier n'est pas un dépôt Git." }

    $branch = (git rev-parse --abbrev-ref HEAD).Trim()
    if ([string]::IsNullOrWhiteSpace($branch)) { throw "Impossible d'identifier la branche courante." }

    Info "Branche actuelle : $branch"
}
catch {
    Err $_.Exception.Message
    exit 1
}

# 2) Ajouter/commiter si nécessaire (ou commit vide pour déclencher Render)
try {
    $status = git status --porcelain
    if ([string]::IsNullOrWhiteSpace($status)) {
        Warn "Aucun changement détecté. Création d'un commit 'vide' pour déclencher Render…"
        git commit --allow-empty -m "chore: trigger Render deploy" | Out-Null
    }
    else {
        Info "Des changements sont détectés. Ajout & commit…"
        git add -A
        git commit -m "chore: trigger Render deploy" | Out-Null
    }
    Ok "Commit prêt."
}
catch {
    Err "Commit impossible : $($_.Exception.Message)"
    exit 1
}

# 3) Déterminer le remote et pousser
try {
    # S'assurer que 'origin' existe
    $remotes = git remote
    if ($remotes -notmatch '(^|\s)origin($|\s)') {
        throw "Le remote 'origin' est introuvable. Configure-le avant de lancer ce script."
    }

    # Pousser sur main (si ta branche par défaut est 'main'; adapte si besoin)
    Info "Push vers 'origin $branch'…"
    git push -u origin $branch
    if ($LASTEXITCODE -ne 0) { throw "Échec du push (voir erreurs ci-dessus)." }

    Ok "Push réussi."
}
catch {
    Err $_.Exception.Message
    exit 1
}

# 4) Afficher le lien du dashboard Render pour suivre le déploiement
try {
    $dashUrl = "https://dashboard.render.com/web/$RenderServiceId"
    Info "Déploiement déclenché. Suis la progression ici : $dashUrl"
}
catch {
    Warn "Impossible de composer l'URL du dashboard Render."
}

# Fin
Ok "Terminé."
