const $ = (sel)=>document.querySelector(sel);
const byName = (n)=>document.querySelector(`input[name="${n}"]:checked`);

async function postJSON(url, data){
const r = await fetch(url,{method:"POST",headers:{"Content-Type":"application/json"},body:JSON.stringify(data)});
return await r.json();
}
function msg(t){ $("#msg").textContent = t; }
function setBusy(v){ $("#btn").disabled = v; }

async function startDownload(){
const url = $("#url").value.trim();
const mode = byName("mode").value;
if(!url){ msg("Entre une URL."); return; }
setBusy(true);
const r = await postJSON("/api/start", {url, mode});
if(!r.ok){ setBusy(false); msg("Erreur: " + (r.error||"inconnue")); return; }
msg("Téléchargement démarré…");
poll(r.id);
}

async function poll(id){
$("#progressBox").classList.remove("hidden");
const timer = setInterval(async ()=>{
  const s = await fetch("/api/status?id="+id).then(r=>r.json()).catch(()=>null);
  if(!s || !s.ok){ clearInterval(timer); setBusy(false); msg("Erreur statut."); return; }
  const st = s.state;
  if(st.percent != null){ $("#bar").style.width = Math.max(0, Math.min(100, st.percent)) + "%"; }
  $("#progressText").textContent = humanStatus(st);
  if(st.status==="finished" || st.status==="error"){
    clearInterval(timer);
    setBusy(false);
    if(st.status==="finished"){ msg("✅ Terminé."); loadHistory(); }
    else { msg("❌ " + (st.error||"Erreur")); }
  }
}, 800);
}

function humanStatus(st){
if(st.status==="queued") return "En attente…";
if(st.status==="downloading"){
  const pct = st.percent!=null ? st.percent+"%" : "";
  const spd = st.speed ? (st.speed/1024/1024).toFixed(1)+" MB/s" : "";
  const eta = st.eta ? ("ETA "+st.eta+"s") : "";
  return `Téléchargement ${pct} ${spd} ${eta}`.trim();
}
if(st.status==="postprocessing") return "Post-traitement (fusion/audio)…";
if(st.status==="finished") return "Terminé";
if(st.status==="error") return "Erreur";
return st.status||"";
}

async function loadHistory(){
const h = await fetch("/history").then(r=>r.json()).catch(()=>[]);
const box = $("#history"); box.innerHTML = "";
if(!h.length){ box.textContent = "Aucun téléchargement pour l'instant."; return; }
for(const item of h){
  const div=document.createElement("div"); div.className="item";
  const a=document.createElement("a");
  a.href="/downloads/"+encodeURIComponent(item.file);
  a.textContent=item.file+" — "+new Date(item.time*1000).toLocaleString();
  div.appendChild(a); box.appendChild(div);
}
}
async function clearHistory(){ await fetch("/history/clear",{method:"POST"}); loadHistory(); }

document.addEventListener("DOMContentLoaded", ()=>{
$("#btn").addEventListener("click", startDownload);
$("#clear").addEventListener("click", clearHistory);
loadHistory();
});
