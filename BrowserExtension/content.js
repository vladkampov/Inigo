(()=>{
  if(globalThis.__inigoInstalled)return;globalThis.__inigoInstalled=true;
  const api=globalThis.browser??chrome;
  let active=null,overlay=null,timer=null;
  const clear=()=>{if(timer)clearTimeout(timer);overlay?.remove();overlay=null;};
  function show(message,text='',undo=null){
    clear();const host=document.createElement('div');host.style.cssText='position:fixed;right:24px;bottom:24px;z-index:2147483647';
    const root=host.attachShadow({mode:'closed'});const style=document.createElement('style');style.textContent='section{font:14px -apple-system,BlinkMacSystemFont,sans-serif;color:#202124;background:#f8f9fc;border:1px solid #ddd;border-radius:14px;padding:18px;width:340px;box-shadow:0 8px 32px #0002}p{white-space:pre-wrap;max-height:220px;overflow:auto;line-height:1.5}button{font:inherit;border:0;border-radius:7px;padding:7px 12px;background:#087fff;color:white;margin:6px 8px 0 0;cursor:pointer}';root.append(style);
    const box=document.createElement('section');const label=document.createElement('div');label.textContent=message;box.append(label);
    if(text){const p=document.createElement('p');p.textContent=text;box.append(p);const copy=document.createElement('button');copy.textContent='Copy rewrite';copy.onclick=async()=>{await navigator.clipboard.writeText(text);clear()};box.append(copy)}
    if(undo){const button=document.createElement('button');button.textContent='Undo';button.onmousedown=e=>e.preventDefault();button.onclick=undo;box.append(button)}
    const close=document.createElement('button');close.textContent='Dismiss';close.onclick=()=>{active?.cancel();clear()};box.append(close);root.append(box);document.documentElement.append(host);overlay=host;timer=setTimeout(clear,120000);
  }
  function context(element){
    const scope=element.closest('[role="dialog"],main,[role="main"]')??element.parentElement;
    if(!scope)return '';const walker=document.createTreeWalker(scope,NodeFilter.SHOW_TEXT);let node,output='',visited=0;
    while((node=walker.nextNode())&&visited++<1000&&output.length<6000){const p=node.parentElement;if(!p||p.closest('script,style,input,textarea,[aria-hidden="true"]')||overlay?.contains(p))continue;const rect=p.getBoundingClientRect();const css=getComputedStyle(p);if(rect.width&&rect.height&&rect.top>=0&&rect.bottom<=innerHeight&&rect.left>=0&&rect.right<=innerWidth&&css.visibility==='visible'&&css.display!=='none')output+=node.textContent+'\n'}return output.slice(0,6000);
  }
  api.runtime.onMessage.addListener(message=>{
    if(message.type!=='inigo-refine')return;active?.cancel();clear();
    const element=document.activeElement;
    const plain=element instanceof HTMLTextAreaElement || (element instanceof HTMLInputElement && ['text','search'].includes(element.type));
    if(element instanceof HTMLInputElement && !plain)return show('This field is excluded.');
    if(/^(cc-|one-time-code|current-password|new-password)/.test(element?.autocomplete??''))return show('This field is excluded.');
    if(element?.closest('[autocomplete="current-password"],[autocomplete="new-password"],[data-private]'))return show('This field is excluded.');
    const selection=getSelection();const rich=element?.isContentEditable;
    const original=plain?element.value:'';
    const initialStart=plain?element.selectionStart:0,initialEnd=plain?element.selectionEnd:0;
    let start=initialStart,end=initialEnd;
    if(plain&&start===end){if(element instanceof HTMLTextAreaElement){start=original.lastIndexOf('\n',Math.max(0,start-1))+1;const next=original.indexOf('\n',end);end=next<0?original.length:next}else{start=0;end=original.length}}
    const draft=plain?original.slice(start,end):(selection?.toString()??'');
    if(!draft.trim())return show('Select text in this editor first. Inigo will never read a whole document implicitly.');
    if(draft.length>20000)return show('Select a shorter passage (up to 20,000 characters).');
    const port=api.runtime.connect({name:'inigo'});let cancelled=false;
    const cancel=()=>{if(cancelled)return;cancelled=true;port.disconnect();element.removeEventListener('input',onInput);window.removeEventListener('blur',onInput);document.removeEventListener('visibilitychange',onHidden);};
    const onInput=()=>{cancel();show('Cancelled · your writing is unchanged')};const onHidden=()=>{if(document.hidden)onInput()};
    element.addEventListener('input',onInput);window.addEventListener('blur',onInput);document.addEventListener('visibilitychange',onHidden);active={cancel};
    show('Inigo · Refining…');
    port.onMessage.addListener(result=>{
      if(cancelled)return;cancel();
      if(result.error)return show(result.error);
      if(typeof result.text!=='string')return show('No complete rewrite was returned.');
      // Rich editors are copy-only until their structural adapter is validated.
      if(!plain)return show('Your draft is unchanged. Copy the refined version.',result.text);
      if(document.activeElement!==element||element.value!==original||element.selectionStart!==initialStart||element.selectionEnd!==initialEnd)return show('Cancelled · the target changed');
      const expected=original.slice(0,start)+result.text+original.slice(end);
      element.setRangeText(result.text,start,end,'end');element.dispatchEvent(new InputEvent('input',{bubbles:true,inputType:'insertReplacementText',data:result.text}));
      if(element.value!==expected)return show('The editor handled this change differently. Check your draft.');
      show('Refined', '',()=>{if(element.value!==expected)return show('Undo unavailable · your newer writing is untouched.');element.focus();element.setRangeText(draft,start,start+result.text.length,'end');element.dispatchEvent(new InputEvent('input',{bubbles:true,inputType:'insertReplacementText',data:draft}));show('Original restored')});
    });
    port.onDisconnect.addListener(()=>{if(!cancelled){cancel();show('Inigo could not connect. Open the app and check the browser connection.')}});
    port.postMessage({draft,context:context(element)});
  });
})();
