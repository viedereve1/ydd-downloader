# Dockerfile
FROM python:3.11-slim

# ffmpeg + utilitaires
RUN apt-get update && apt-get install -y --no-install-recommends \
    ffmpeg ca-certificates && \
    rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Déps d'abord pour le cache
COPY requirements.txt /app/requirements.txt
RUN pip install --upgrade pip && \
    pip install -r requirements.txt && \
    pip install --upgrade yt-dlp

# Code
COPY . /app

# Port standard Koyeb
ENV PORT=8080
CMD ["gunicorn", "-b", "0.0.0.0:8080", "app:app"]
