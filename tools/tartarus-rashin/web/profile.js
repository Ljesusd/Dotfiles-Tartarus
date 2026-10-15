async function loadUserProfile(){
  const editor=document.getElementById('user-profile');
  if(!editor)return;
  try{const data=await api('/api/profile');editor.value=data.content||''}catch(e){}
}
const saveProfileButton=document.getElementById('save-profile');
if(saveProfileButton)saveProfileButton.onclick=async()=>{
  const stateNode=document.getElementById('profile-state');
  saveProfileButton.disabled=true;
  try{await api('/api/profile',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({content:document.getElementById('user-profile').value})});stateNode.textContent='Guardado localmente'}catch(e){stateNode.textContent=e.message}finally{saveProfileButton.disabled=false}
};
document.querySelector('[data-page="memory"]')?.addEventListener('click',loadUserProfile);
loadUserProfile();
