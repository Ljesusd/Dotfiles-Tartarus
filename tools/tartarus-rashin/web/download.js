async function refreshModelDownloads(){
  const host=document.getElementById('download-list');
  if(!host)return;
  try{
    const list=await api('/api/models/downloads');
    host.innerHTML=(list||[]).slice(0,5).map(x=>`<div class="download-item"><strong>${escapeHtml(x.name)}</strong><span>${escapeHtml(x.status)}</span><div class="progress"><i style="width:${Math.max(0,Math.min(100,x.progress||0))}%"></i></div><span>${x.total?Math.round(x.progress||0)+'%':''}</span></div>`).join('');
  }catch(e){}
}
const downloadButton=document.getElementById('download-model');
if(downloadButton)downloadButton.onclick=async()=>{
  const url=document.getElementById('model-url').value.trim();
  if(!url){alert('Añade una URL directa al GGUF');return}
  downloadButton.disabled=true;downloadButton.textContent='Preparando…';
  try{
    await api('/api/models/download',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({url,name:document.getElementById('model-name').value.trim(),tier:document.getElementById('model-tier').value})});
    document.getElementById('model-url').value='';document.getElementById('model-name').value='';refreshModelDownloads();
  }catch(e){alert(e.message)}finally{downloadButton.disabled=false;downloadButton.textContent='Descargar'}
};
refreshModelDownloads();setInterval(refreshModelDownloads,3000);
