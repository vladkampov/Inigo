const api = globalThis.browser ?? chrome;
async function invoke(tab) {
  if (!tab?.id || tab.incognito !== false || !/^https?:/.test(tab.url ?? '')) return;
  await api.scripting.executeScript({target:{tabId:tab.id},files:['content.js']});
  await api.tabs.sendMessage(tab.id,{type:'inigo-refine'});
}
api.action.onClicked.addListener(invoke);
api.commands.onCommand.addListener(async command=>{if(command==='refine'){const [tab]=await api.tabs.query({active:true,currentWindow:true});await invoke(tab)}});
api.runtime.onConnect.addListener(port=>{
  if(port.name!=='inigo' || !port.sender?.tab || port.sender.tab.incognito !== false)return port.disconnect();
  if(typeof api.runtime.getURL==='function' && api.runtime.getURL('').startsWith('safari-web-extension:')) {
    let closed=false;port.onDisconnect.addListener(()=>{closed=true});
    port.onMessage.addListener(async message=>{
      try { const result=await api.runtime.sendNativeMessage('app.inigo.browser',{...message,private:false});if(!closed)port.postMessage(result) }
      catch { if(!closed)port.postMessage({error:'The signed Safari connection is unavailable. Open Inigo and check extension setup.'}) }
    });return;
  }
  const native=api.runtime.connectNative('app.inigo.personal');
  port.onMessage.addListener(message=>native.postMessage({...message,private:false}));
  native.onMessage.addListener(message=>port.postMessage(message));
  native.onDisconnect.addListener(()=>{const error=api.runtime.lastError;if(error)try{port.postMessage({error:'Open Inigo and install the browser connection first.'})}catch{};try{port.disconnect()}catch{}});
  port.onDisconnect.addListener(()=>{try{native.disconnect()}catch{}});
});
