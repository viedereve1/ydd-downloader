param(
  [string]\main = 'main',
  [string]\ = ''
)
function Ok(\){ Write-Host "[OK] \" -ForegroundColor Green }
function Info(\){ Write-Host "[INFO] \" -ForegroundColor Cyan }
function Warn(\){ Write-Host "[WARN] \" -ForegroundColor Yellow }
function Err(\){ Write-Host "[ERR] \" -ForegroundColor Red }

try{
  Info "Ajout + commit"
  git add -A
  git commit -m "Auto update 2025-10-04 19:54:42" 2> | Out-Null
}catch{}

try{
  Info "Pull --rebase"
  git pull --rebase origin \main
}catch{
  Warn "Rebase en conflit  tentative de continuation"
  git rebase --continue 2> | Out-Null
}

Info "Push GitHub"
git push origin \main
Ok "Push réussi"

if(-not [string]::IsNullOrWhiteSpace(\)){
  Info "Déclenchement Render"
  try{
    Invoke-RestMethod -Method Post -Uri \ | Out-Null
    Ok "Redeploy Render déclenché"
  }catch{ Warn "Échec hook Render : \" }
}else{
  Warn "DeployHook vide  pas de redeploy auto"
}
