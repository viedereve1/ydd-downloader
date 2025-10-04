# YDD Downloader (propre)

## Lancer en local
python -m venv .venv
.\.venv\Scripts\Activate.ps1
pip install -U pip && pip install -r requirements.txt
python app.py
# ouvrir http://localhost:8000

## Déploiement Render
- Procfile et render.yaml déjà prêts.
- Ajoute, si besoin, la variable d'env COOKIES_B64 côté Render (cookies.txt encodé Base64).
- A chaque push GitHub, Render redéploie.

## Cookies
Dépose youtube.txt, instagram.txt, tiktok.txt, facebook.txt à la racine
OU mets COOKIES_B64 (cookies.txt entier encodé en Base64).

