// Keep queued assistant placeholders alive while an earlier turn finishes.
// The original loader remains available when the user changes session.
const rashinLoadSessionMessages=loadSessionMessages;
loadSessionMessages=async function(){
  if(state.requests.some(item=>!item.done))return;
  return rashinLoadSessionMessages();
};

function rashinMarkdown(value){
  let html=escapeHtml(value||'');
  const blocks=[];
  html=html.replace(/```(?:[a-zA-Z0-9_+-]+)?\n?([\s\S]*?)```/g,(_,code)=>{
    const marker=`@@RASHIN_CODE_${blocks.length}@@`;
    blocks.push(`<pre><code>${code.trim()}</code></pre>`);
    return marker;
  });
  html=html.replace(/^###\s+(.+)$/gm,'<h4>$1</h4>').replace(/^##\s+(.+)$/gm,'<h3>$1</h3>').replace(/^#\s+(.+)$/gm,'<h2>$1</h2>');
  html=html.replace(/\*\*(.+?)\*\*/g,'<strong>$1</strong>').replace(/`([^`\n]+)`/g,'<code>$1</code>');
  html=html.replace(/\n/g,'<br>');
  blocks.forEach((block,index)=>{html=html.replace(`@@RASHIN_CODE_${index}@@`,block)});
  return html;
}

const rashinHandleChatEvent=handleChatEvent;
handleChatEvent=function(event){
  rashinHandleChatEvent(event);
  if(event.type!=='done'&&event.type!=='delta')return;
  const item=requestFor(event);
  if(item&&item.body&&item.answer) item.body.innerHTML=rashinMarkdown(item.answer);
};
