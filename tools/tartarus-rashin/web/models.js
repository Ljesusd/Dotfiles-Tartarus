const rashinFamilyName=name=>String(name||'').replace(/\s+(?:IQ|Q)\d+(?:\s+.*)?$/i,'').replace(/\s+(?:F16|BF16)$/i,'').trim();
const rashinTierOrder=['Low','Medium','High','XHigh','Max','Ultra'];
async function loadGroupedModels(){
  try{
    const data=await api('/api/models');
    state.models=data.models||[];
    renderModelSelect(state.models);
    const groups={};
    state.models.forEach(model=>{const family=rashinFamilyName(model.name);(groups[family]??=[]).push(model)});
    document.getElementById('model-list').innerHTML=Object.entries(groups).map(([family,items])=>`<article class="model-family"><div class="family-heading"><div><p class="eyebrow">MODELO</p><h3>${escapeHtml(family)}</h3></div><span class="muted">${items.length} variantes</span></div><div class="variant-grid">${items.sort((a,b)=>rashinTierOrder.indexOf(a.tier)-rashinTierOrder.indexOf(b.tier)).map(x=>`<div class="variant ${x.active?'active':''}"><div><strong>${escapeHtml(x.tier)}</strong><small>${escapeHtml(x.name.replace(family,'').trim())||'cuantización local'}</small></div>${x.active?'<span class="active-label">Activo</span>':x.installed?`<button class="secondary" data-activate="${x.id}">Usar</button>`:'<span class="muted">No instalado</span>'}</div>`).join('')}</div></article>`).join('')||'<p class="muted">No se encontraron modelos GGUF.</p>';
    document.querySelectorAll('[data-activate]').forEach(button=>button.onclick=async()=>{try{const result=await api('/api/models/activate',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({id:button.dataset.activate})});alert(result.message||'Perfil guardado');loadGroupedModels();loadStatus()}catch(error){alert(error.message)}});
  }catch(error){document.getElementById('model-list').innerHTML='<p class="muted">No se pudo leer el catálogo.</p>'}
}
loadModels=loadGroupedModels;
const refreshModelsButton=document.getElementById('refresh-models');
if(refreshModelsButton)refreshModelsButton.onclick=loadGroupedModels;
loadGroupedModels();
