import test from 'node:test';
import assert from 'node:assert/strict';
import vm from 'node:vm';
import fs from 'node:fs';
const source=fs.readFileSync(new URL('../background.js',import.meta.url),'utf8');
function environment(){
  const calls=[],listeners={};const api={scripting:{executeScript:async x=>calls.push(['inject',x])},tabs:{sendMessage:async(...x)=>calls.push(['message',x]),query:async()=>[]},action:{onClicked:{addListener:f=>listeners.invoke=f}},commands:{onCommand:{addListener:f=>listeners.command=f}},runtime:{onConnect:{addListener:f=>listeners.connect=f},connectNative:()=>{calls.push(['native']);return{postMessage(){},onMessage:{addListener(){}},onDisconnect:{addListener(){}},disconnect(){}}}}};vm.runInNewContext(source,{chrome:api});return{calls,listeners};
}
test('private tabs never inject or connect',async()=>{const e=environment();await e.listeners.invoke({id:1,incognito:true,url:'https://example.com'});assert.deepEqual(e.calls,[])});
test('unknown private state fails closed',async()=>{const e=environment();await e.listeners.invoke({id:1,url:'https://example.com'});assert.deepEqual(e.calls,[])});
test('browser internal pages are excluded',async()=>{const e=environment();await e.listeners.invoke({id:1,incognito:false,url:'chrome://settings'});assert.deepEqual(e.calls,[])});
test('ordinary invoked page gets one injection',async()=>{const e=environment();await e.listeners.invoke({id:1,incognito:false,url:'https://example.com'});assert.equal(e.calls[0][0],'inject');assert.equal(e.calls.length,2)});
test('private port cannot reach the native host',()=>{const e=environment();let closed=false;e.listeners.connect({name:'inigo',sender:{tab:{incognito:true}},disconnect(){closed=true}});assert.equal(closed,true);assert.deepEqual(e.calls,[])});
test('untrusted port cannot reach the native host',()=>{const e=environment();let closed=false;e.listeners.connect({name:'other',sender:{tab:{incognito:false}},disconnect(){closed=true}});assert.equal(closed,true);assert.deepEqual(e.calls,[])});
