import os, threading, time, json, uuid
from flask import Flask, request, jsonify, render_template, send_from_directory, abort
from yt_dlp import YoutubeDL

BASE_DIR = os.path.dirname(os.path.abspath(__file__))
DL_DIR   = os.path.join(BASE_DIR, "downloads")
HIST_FILE= os.path.join(BASE_DIR, "history.json")
COOKIES  = os.path.join(BASE_DIR, "cookies.txt")

progress_map = {}
history_lock = threading.Lock()

def load_history():
  if os.path.exists(HIST_FILE):
      try:
          with open(HIST_FILE,"r",encoding="utf-8") as f:
              return json.load(f)
      except Exception:
          return []
  return []

def save_history(h):
  with history_lock:
      with open(HIST_FILE,"w",encoding="utf-8") as f:
          json.dump(h, f, ensure_ascii=False, indent=2)

def _hook(job_id, d):
  p = progress_map.get(job_id)
  if not p:
      return
  if d.get("status") == "downloading":
      try:
          total = d.get("total_bytes") or d.get("total_bytes_estimate")
          downloaded = d.get("downloaded_bytes", 0)
          percent = int(downloaded * 100 / total) if total else None
      except Exception:
          percent = None
      p.update({
          "status":"downloading",
          "percent": percent,
          "speed": d.get("speed"),
          "eta": d.get("eta"),
          "filename": os.path.basename(d.get("filename","")) if d.get("filename") else None
      })
  elif d.get("status") == "finished":
      p.update({"status":"postprocessing"})

def _download_worker(job_id, url, mode):
  prog = progress_map[job_id]
  ydl_opts = {
      "outtmpl": os.path.join(DL_DIR, "%(title).80s.%(ext)s"),
      "progress_hooks": [lambda d: _hook(job_id, d)],
      "quiet": True,
      "noprogress": True,
      "noplaylist": True,
  }
  if mode == "audio":
      ydl_opts.update({"format":"bestaudio/best"})
      ydl_opts["postprocessors"] = [{"key":"FFmpegExtractAudio","preferredcodec":"mp3","preferredquality":"192"}]
  else:
      ydl_opts["format"] = "bestvideo[ext=mp4]+bestaudio[ext=m4a]/best[ext=mp4]/best"
      ydl_opts["merge_output_format"] = "mp4"

  if os.path.exists(COOKIES) and os.path.getsize(COOKIES) > 0:
      ydl_opts["cookiefile"] = COOKIES

  try:
      os.makedirs(DL_DIR, exist_ok=True)
      with YoutubeDL(ydl_opts) as ydl:
          info = ydl.extract_info(url, download=True)
          fname = ydl.prepare_filename(info)
          if mode == "audio":
              base, _ = os.path.splitext(fname)
              fname = base + ".mp3"

      prog.update({"status":"finished","filename": os.path.basename(fname), "percent":100})
      hist = load_history()
      hist.insert(0, {
          "time": int(time.time()),
          "url": url,
          "mode": mode,
          "file": os.path.basename(fname),
          "status": "done"
      })
      save_history(hist[:30])
  except Exception as e:
      prog.update({"status":"error","error": str(e)})

def create_app():
  app = Flask(__name__)

  @app.route("/")
  def index():
      return render_template("index.html")

  @app.post("/api/start")
  def api_start():
      data = request.get_json(silent=True) or {}
      url  = (data.get("url") or "").strip()
      mode = (data.get("mode") or "video").strip()
      if not url:
          return jsonify({"ok":False,"error":"URL manquante."}), 400
      job_id = uuid.uuid4().hex
      progress_map[job_id] = {"status":"queued","percent":0}
      threading.Thread(target=_download_worker, args=(job_id,url,mode), daemon=True).start()
      return jsonify({"ok":True,"id": job_id})

  @app.get("/api/status")
  def api_status():
      job_id = request.args.get("id")
      if not job_id or job_id not in progress_map:
          return jsonify({"ok":False,"error":"Job inconnu"}), 404
      return jsonify({"ok":True,"state": progress_map[job_id]})

  @app.get("/history")
  def api_history():
      return jsonify(load_history())

  @app.post("/history/clear")
  def api_history_clear():
      save_history([])
      return jsonify({"ok":True})

  @app.get("/downloads/<path:fname>")
  def get_file(fname):
      path = os.path.join("downloads", os.path.basename(fname))
      if not os.path.exists(path):
          abort(404)
      return send_from_directory("downloads", os.path.basename(fname), as_attachment=True)

  return app

if __name__ == "__main__":
  create_app().run(host="0.0.0.0", port=8000, debug=True)
