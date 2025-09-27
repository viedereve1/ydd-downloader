from flask import Flask, request, abort, send_file, jsonify, render_template
import os, tempfile, glob
from yt_dlp import YoutubeDL

app = Flask(__name__)

@app.get("/")
def home():
    return render_template("index.html")

@app.get("/download")
def download():
    url = request.args.get("url", "").strip()
    if not url:
        return jsonify({"error": "missing ?url=<video_url>"}), 400

    tmpdir = tempfile.mkdtemp(prefix="ydd_", dir="/tmp")
    outtpl = os.path.join(tmpdir, "%(title)s.%(ext)s")

    ydl_opts = {
        "outtmpl": outtpl,
        "format": "bestaudio/best",
        "noplaylist": True,
        "quiet": True,
        "nocheckcertificate": True
        # If you want mp3 by default, uncomment below and ensure ffmpeg is available:
        # ,"postprocessors": [{"key":"FFmpegExtractAudio","preferredcodec":"mp3","preferredquality":"192"}],
        # "prefer_ffmpeg": True
    }

    try:
        with YoutubeDL(ydl_opts) as ydl:
            ydl.download([url])

        matches = glob.glob(os.path.join(tmpdir, "*"))
        if not matches:
            return jsonify({"error": "download failed"}), 500

        filepath = max(matches, key=os.path.getsize)
        filename = os.path.basename(filepath)

        return send_file(filepath, as_attachment=True, download_name=filename)
    except Exception as e:
        return jsonify({"error": str(e)}), 500

@app.route("/ui")
def ui():
    return render_template("index.html")
