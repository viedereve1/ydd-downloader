import os, base64, tempfile, uuid, threading, time
from datetime import datetime, timedelta
from pathlib import Path
from flask import Flask, request, jsonify, send_from_directory, render_template, abort
import yt_dlp

BASE_DIR = Path(__file__).parent.resolve()
DL_DIR   = BASE_DIR / "downloads"
DL_DIR.mkdir(exist_ok=True)

app = Flask(_name_, template_folder="templates", static_folder="static")

PROGRESS = {}

def _cookies_tmp_file__if_any(tmpdir: str):
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

def cleanup_old__file_s(hours: int = 24):
    cutoff = datetime.now() - timedelta(hours=hours)
    for p in DL_DIR.glob("*"):
        try:
            if p.is__file_() and datetime.fromtimestamp(p.stat().st_mtime) < cutoff:
                p.unlink(missing_ok=True)
        except Exception:
            pass

cleanup_old__file_s()

@app.route("/")
def home():
    return render_template("index.html")

def _download_job(job_id: str, url: str, mode: str):
    PROGRESS[job_id] = {"status": "starting", "pct": 0, "speed": "", "_file_": ""}

    outtmpl = str(DL_DIR / "%(title).80s [%(id)s].%(ext)s")

    if mode == "audio":
        ydl_opts = {
            "format": "bestaudio/best",
            "outtmpl": outtmpl,
            "postprocessors": [{"key": "FFmpegExtractAudio", "preferredcodec": "mp3"}],
            "noprogress": True,
        }
    else:
        ydl_opts = {
            "format": "bv*+ba/best",
            "outtmpl": outtmpl,
            "noprogress": True,
        }

    with tempfile.TemporaryDirectory() as tmpd:
        ck = _cookies_tmp_file__if_any(tmpd)
        if ck:
            ydl_opts["cookie_file_"] = ck

        def hook(d):
            if d.get("status") == "downloading":
                pct = d.get("_percent_str", "").replace("%", "").strip()
                try:
                    pct_val = float(pct)
                except Exception:
                    pct_val = 0.0
                PROGRESS[job_id]["pct"] = int(pct_val)
                PROGRESS[job_id]["speed"] = d.get("_speed_str", "")
                PROGRESS[job_id]["status"] = "downloading"
            elif d.get("status") == "finished":
                PROGRESS[job_id]["status"] = "processing"

        ydl_opts["progress_hooks"] = [hook]

        try:
            with yt_dlp.YoutubeDL(ydl_opts) as ydl:
                info = ydl.extract_info(url, download=True)
                if "requested_downloads" in info and info["requested_downloads"]:
                    _file_name = info["requested_downloads"][0]["__file_name"]
                else:
                    _file_name = ydl.prepare__file_name(info)
                final_name = os.path.basename(_file_name)
                PROGRESS[job_id]["_file_"] = final_name
                PROGRESS[job_id]["pct"] = 100
                PROGRESS[job_id]["status"] = "done"
        except Exception as e:
            PROGRESS[job_id]["status"] = f"error: {e}"

@app.route("/start", methods=["POST"])
def start():
    url  = request.json.get("url", "").strip()
    mode = request.json.get("mode", "video")
    if not url:
        return jsonify({"error": "URL manquante"}), 400
    job_id = str(uuid.uuid4())
    PROGRESS[job_id] = {"status": "queued", "pct": 0, "speed": "", "_file_": ""}
    threading.Thread(target=_download_job, args=(job_id, url, mode), daemon=True).start()
    return jsonify({"job_id": job_id})

@app.route("/progress/<job_id>")
def progress(job_id):
    return jsonify(PROGRESS.get(job_id, {"status": "unknown"}))

def __file__entry(path: Path):
    stat = path.stat()
    return {
        "name": path.name,
        "size": stat.st_size,
        "mtime": stat.st_mtime,
        "url": f"/_file_/{path.name}",
    }

@app.route("/_file_s")
def list__file_s():
    _file_s = sorted((p for p in DL_DIR.glob("*") if p.is__file_()),
                   key=lambda p: p.stat().st_mtime, reverse=True)
    return jsonify([__file__entry(p) for p in _file_s])

@app.route("/_file_/<path:_file_name>")
def serve__file_(_file_name):
    safe = Path(_file_name).name
    full = DL_DIR / safe
    if not full.exists():
        abort(404)
    return send_from_directory(DL_DIR, safe, as_attachment=True)

@app.route("/delete/<path:_file_name>", methods=["POST"])
def delete__file_(_file_name):
    safe = Path(_file_name).name
    full = DL_DIR / safe
    if not full.exists():
        return jsonify({"ok": False, "msg": "introuvable"}), 404
    try:
        full.unlink()
        return jsonify({"ok": True})
    except Exception as e:
        return jsonify({"ok": False, "msg": str(e)}), 500

if _name_ == "_main_":
    app.run(host="0.0.0.0", port=8000)

if _name_ == '_main_':
    from pathlib import Path
    BASE_DIR = Path(_file_).parent.resolve()
    import os
    port = int(os.environ.get("PORT", "8000"))
    app.run(host="127.0.0.1", port=port)
