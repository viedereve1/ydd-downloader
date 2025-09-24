# Aller dans ton dossier projet local
Set-Location "C:\dev\YDD-Downloader"

# Demander un message de commit
$CommitMsg = Read-Host "Entre ton message de commit"

# Ajouter tous les fichiers
git add -A

# Faire le commit (même si vide, ça ne bloque pas)
git commit -m $CommitMsg --allow-empty

# Définir le remote (une seule fois)
git remote remove origin 2>$null
git remote add origin "https://github.com/yadieudedans013/ydd-downloader02.git"

# Envoyer sur GitHub
git branch -M main
git push -u origin main
