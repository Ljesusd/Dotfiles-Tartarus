function rashinWaitForSocket(timeout=10000){
  ensureSocket();
  const socket=state.socket;
  if(socket&&socket.readyState===WebSocket.OPEN)return Promise.resolve(socket);
  return new Promise((resolve,reject)=>{
    const timer=setTimeout(()=>{cleanup();reject(new Error('La conexión con Rashin tardó demasiado'))},timeout);
    const cleanup=()=>{clearTimeout(timer);socket?.removeEventListener('open',opened);socket?.removeEventListener('close',closed);socket?.removeEventListener('error',closed)};
    const opened=()=>{cleanup();resolve(socket)};
    const closed=()=>{cleanup();reject(new Error('La conexión con Rashin se cerró'))};
    socket?.addEventListener('open',opened,{once:true});socket?.addEventListener('close',closed,{once:true});socket?.addEventListener('error',closed,{once:true});
  });
}

// Uploads are asynchronous. Re-check the websocket after the upload instead
// of calling send() on the old CLOSED object.
sendChat=async function(text){
  const item=pendingRequest(text);
  state.lastPrompt=text;state.lastMode=chatMode();setWorking(true);$('question').value='';
  try{
    const ids=await uploadPending();
    clearAttachments();
    const socket=await rashinWaitForSocket();
    socket.send(JSON.stringify({type:'prompt',text,mode:state.lastMode,sessionId:state.currentSession,modelProfile:$('model-profile').value,fastMode:$('fast-mode').checked,attachmentIds:ids}));
  }catch(error){item.done=true;item.response.classList.add('error');item.body.textContent='No se pudo enviar: '+error.message;setWorking(false)}
};

const attachAccepts={
  files:'.txt,.md,.markdown,.json,.yaml,.yml,.toml,.csv,.go,.qml,.js,.ts,.py,.sh,.c,.h,.cpp,.rs,.pdf,.doc,.docx,.odt,.png,.jpg,.jpeg,.webp,.gif,.mp4,.webm,.mkv,.mov,.avi',
  photos:'image/*',
  videos:'video/*',
  documents:'.pdf,.doc,.docx,.odt,.txt,.md,.markdown,.json,.yaml,.yml,.toml,.csv'
};
const attachMenu=document.getElementById('attach-menu');
document.getElementById('attach-menu-toggle')?.addEventListener('click',event=>{event.stopPropagation();attachMenu.classList.toggle('hidden')});
document.querySelectorAll('[data-attach-kind]').forEach(button=>button.addEventListener('click',()=>{const input=document.getElementById('attachments');input.accept=attachAccepts[button.dataset.attachKind]||attachAccepts.files;input.click();attachMenu.classList.add('hidden')}));
document.addEventListener('click',event=>{if(attachMenu&&!attachMenu.contains(event.target)&&event.target.id!=='attach-menu-toggle')attachMenu.classList.add('hidden')});
