import os, base64, tempfile, threading, uuid
from flask import Flask, request, jsonify, send_file, render_template
import yt_dlp

app = Flask(_name_, template_folder="templates", static_folder="static")

# Mémoire : état des téléchargements
PROGRESS = {}  # job_id -> dict(status,pct,text,speed,filepath,url,mode)

def _pick_local_cookies():
    # cherche un cookies.txt prioritaire sinon plateformes
    for name in ["cookies.txt", "instagram.txt", "youtube.txt", "tiktok.txt", "facebook.txt"]:
        p = os.path.join(os.getcwd(), name)
        if os.path.isfile(p) and os.path.getsize(p) > 0:
            return p
    return None

def _cookies_path(tmpdir: str) -> str | None:
    # 1) via env COOKIES_B64 (Base64 Netscape)
    b64 = os.environ.get("COOKIES_B64", "").strip()
    if b64:
        try:
            raw = base64.b64decode(b64.encode("utf-8"))
            ck_path = os.path.join(tmpdir, "cookies.txt")
            with open(ck_path, "wb") as f:
                f.write(raw)
            return ck_path
        except Exception:
            pass
    # 2) via fichiers locaux
    return _pick_local_cookies()

def _progress_hook(job_id: str):
    def hook(d):
        st = d.get("status")
        if st in ("downloading", "finished"):
            pct = 0.0
            if d.get("_percent_str"):
                try:
                    pct = float(d["_percent_str"].strip().strip("%"))
                except Exception:
                    pct = 0.0
            speed = d.get("_speed_str", "")
            text  = d.get("_eta_str", "")
            PROGRESS[job_id].update({"status": st, "pct": pct, "speed": speed, "text": text})
            if st == "finished":
                PROGRESS[job_id]["pct"] = 100.0
    return hook

def _download(job_id: str, url: str, mode: str):
    tmpdir = tempfile.mkdtemp(prefix="ydd_")
    cookies = _cookies_path(tmpdir)
    outtmpl = os.path.join("static", "downloads", f"%(title).80s-%(id)s.%(ext)s")
    fmt = "bestaudio/best" if mode == "audio" else "bestvideo*+bestaudio/best"
    postprocessors = []
    if mode == "audio":
        postprocessors = [{
            "key": "FFmpegExtractAudio",
            "preferredcodec": "mp3",
            "preferredquality": "192",
        }]

    ydl_opts = {
        "outtmpl": outtmpl,
        "format": fmt,
        "noplaylist": True,
        "progress_hooks": [_progress_hook(job_id)],
        "quiet": True,
        "nocheckcertificate": True,
        "postprocessors": postprocessors
    }
    if cookies:
        ydl_opts["cookiefile"] = cookies

    try:
        with yt_dlp.YoutubeDL(ydl_opts) as ydl:
            info = ydl.extract_info(url, download=True)
            filename = ydl.prepare_filename(info)
            # si audio, l'extension change
            if mode == "audio" and filename.endswith((".webm",".m4a",".mp4",".mkv",".ogg",".opus",".wav",".flac",".m4b",".mp3")):
                base, _ = os.path.splitext(filename)
                # yt-dlp renomme vers .mp3 via postprocessor
                if os.path.exists(base + ".mp3"):
                    filename = base + ".mp3"
            PROGRESS[job_id].update({"status": "finished", "filepath": filename})
    except Exception as e:
        PROGRESS[job_id].update({"status": "error", "message": f"{type(e)._name_}: {e}"})

@app.get("/")
def home():
    return render_template("index.html")

@app.post("/api/start")
def api_start():
    data = request.get_json(force=True)
    url  = (data.get("url") or "").strip()
    mode = (data.get("mode") or "video").strip().lower()
    if not url:
        return jsonify({"error": "Lien manquant"}), 400
    if mode not in ("audio","video"):
        mode = "video"

    job_id = str(uuid.uuid4())
    PROGRESS[job_id] = {"status":"queued","pct":0,"text":"", "speed":"", "filepath":"", "url":url, "mode":mode}
    threading.Thread(target=_download, args=(job_id, url, mode), daemon=True).start()
    return jsonify({"job_id": job_id})

@app.get("/api/status/<job_id>")
def api_status(job_id):
    return jsonify(PROGRESS.get(job_id, {"status":"unknown"}))

@app.get("/result/<job_id>")
def result(job_id):
    st = PROGRESS.get(job_id)
    if not st or st.get("status") != "finished" or not st.get("filepath"):
        return "Not ready", 404
    path = st["filepath"]
    return send_file(path, as_attachment=True, download_name=os.path.basename(path))

if _name_ == "_main_":
    app.run(host="0.0.0.0", port=int(os.environ.get("PORT", "8000")))
