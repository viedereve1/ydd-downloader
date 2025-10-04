import os
import base64
import tempfile
import uuid
import threading
from flask import Flask, request, jsonify, send_file, render_template
import yt_dlp

# Initialisation de l'app Flask
app = Flask(__name__, template_folder="templates", static_folder="static")

# Suivi en mémoire
PROGRESS = {}

# Charger cookies si présents
def _load_cookies_file(tmpdir: str) -> str | None:
    b64 = os.environ.get("COOKIES_B64", "").strip()
    if not b64:
        return None
    try:
        raw = base64.b64decode(b64.encode("utf-8"))
        ck_path = os.path.join(tmpdir, "cookies.txt")
        with open(ck_path, "wb") as f:
            f.write(raw)
        return ck_path
    except Exception:
        return None

# Fonction de téléchargement
def _target_download(job_id: str, url: str, mode: str):
    tmpdir = tempfile.mkdtemp()
    cookies = _load_cookies_file(tmpdir)

    ydl_opts = {
        "outtmpl": os.path.join(tmpdir, "%(title)s.%(ext)s"),
        "progress_hooks": [lambda d: PROGRESS.update({job_id: {
            "status": d["status"],
            "pct": d.get("_percent_str", "0%"),
            "speed": d.get("_speed_str", "0"),
            "eta": d.get("_eta_str", "?")
        }})]
    }

    if cookies:
        ydl_opts["cookiefile"] = cookies

    if mode == "audio":
        ydl_opts.update({
            "format": "bestaudio/best",
            "postprocessors": [{
                "key": "FFmpegExtractAudio",
                "preferredcodec": "mp3",
                "preferredquality": "192"
            }]
        })
    else:
        ydl_opts.update({"format": "best"})

    try:
        with yt_dlp.YoutubeDL(ydl_opts) as ydl:
            info = ydl.extract_info(url, download=True)
            filename = ydl.prepare_filename(info)
            PROGRESS[job_id] = {
                "status": "finished",
                "file": filename
            }
    except Exception as e:
        PROGRESS[job_id] = {"status": "error", "error": str(e)}

# Routes
@app.route("/")
def index():
    return render_template("index.html")

@app.route("/start", methods=["POST"])
def start():
    url = request.json.get("url")
    mode = request.json.get("mode", "video")
    job_id = str(uuid.uuid4())

    PROGRESS[job_id] = {"status": "starting"}
    threading.Thread(target=_target_download, args=(job_id, url, mode)).start()

    return jsonify({"job_id": job_id, "status": "started"})

@app.route("/progress/<job_id>")
def progress(job_id):
    return jsonify(PROGRESS.get(job_id, {"status": "unknown"}))

@app.route("/download/<job_id>")
def download(job_id):
    st = PROGRESS.get(job_id, {})
    if st.get("status") == "finished" and os.path.exists(st["file"]):
        return send_file(st["file"], as_attachment=True)
    return jsonify({"error": "not ready"}), 404

# Point d’entrée
if __name__ == "_main_":
    app.run(host="0.0.0.0", port=8000)
if __name__ == "__main__":
    app.run(host="0.0.0.0", port=8000, debug=True)
