param(
    [string]$Token,
    [string]$RepoUrl = ""
)

if (-not $Token) {
    $Token = Read-Host "Colle ton token GitHub"
}

$headers = @{ Authorization = "token $Token" }

Write-Host "`n🔎 Vérification du token..." -ForegroundColor Cyan

# Vérifier le token de l’utilisateur
try {
    $resp = Invoke-RestMethod -Uri "https://api.github.com/user" -Headers $headers -ErrorAction Stop
    Write-Host "✅ Token valide" -ForegroundColor Green
    Write-Host "Utilisateur : $($resp.login) (id: $($resp.id))"
}
catch {
    Write-Host "❌ Token invalide ou expiré !" -ForegroundColor Red
    exit 1
}

# Vérifier un repo si fourni
if ($RepoUrl -ne "") {
    try {
        $repoResp = Invoke-RestMethod -Uri "https://api.github.com/repos/$RepoUrl" -Headers $headers -ErrorAction Stop
        Write-Host "✅ Tu as accès au dépôt : $RepoUrl" -ForegroundColor Green
    }
    catch {
        Write-Host "⚠️ Impossible d’accéder au dépôt $RepoUrl (permissions ou URL invalide)" -ForegroundColor Yellow
    }
}
