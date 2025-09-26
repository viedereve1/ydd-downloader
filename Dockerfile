# Dockerfile
FROM python:3.11-slim

# Dépendances système utiles (optionnel)
RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates && \
    rm -rf /var/lib/apt/lists/*

WORKDIR /app
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY . .

# Railway / PaaS fournira $PORT
ENV PORT=8000
EXPOSE 8000

# Flask/Gunicorn, par exemple :
CMD ["sh", "-c", "gunicorn app:app -b 0.0.0.0:${PORT}"]
