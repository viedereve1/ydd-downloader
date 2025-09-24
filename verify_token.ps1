param(
    [string]$Token
)

if (-not $Token) {
    Write-Host "❌ Tu dois fournir ton token GitHub !" -ForegroundColor Red
    Write-Host "👉 Exemple : .\verify_token.ps1 -Token ghp_TON_TOKEN_ICI" -ForegroundColor Yellow
    exit 1
}

try {
    $response = Invoke-RestMethod -Uri "https://api.github.com/user" -Headers @{Authorization = "token $Token"}

    if ($response.login) {
        Write-Host "✅ Token valide !" -ForegroundColor Green
        Write-Host "👤 Utilisateur GitHub détecté : $($response.login)" -ForegroundColor Cyan
    }
    else {
        Write-Host "❌ Token invalide ou sans permissions suffisantes." -ForegroundColor Red
    }
}
catch {
    Write-Host "❌ Erreur lors de la vérification du token." -ForegroundColor Red
    Write-Host $_.Exception.Message -ForegroundColor Yellow
}
