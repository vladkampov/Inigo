import {createConnection} from './oauth.mjs';
import {createInterface} from 'node:readline';
import {randomUUID} from 'node:crypto';
const pending=new Map(),active=new Map();
const reply=value=>process.stdout.write(JSON.stringify(value)+'\n');
const vault=(operation,value)=>{const id=randomUUID();return new Promise((resolve,reject)=>{pending.set(id,{resolve,reject});reply({vault:id,operation,value})})};
const connection=createConnection({directory:process.argv[2],vault,openBrowser:url=>reply({openBrowser:url})});
let queue=Promise.resolve();
createInterface({input:process.stdin}).on('line',line=>{
 let message;try{message=JSON.parse(line)}catch{return}
 if(message.vaultReply){const p=pending.get(message.vaultReply);pending.delete(message.vaultReply);if(message.error)p?.reject(Error('Keychain access failed'));else p?.resolve(message.value);return}
 if(message.cancel){active.get(message.cancel)?.abort();return}
 const {id,method}=message;const controller=new AbortController();active.set(id,controller);
 if(method==='disconnect')for(const [key,value]of active)if(key!==id)value.abort();
 queue=queue.catch(()=>{}).then(async()=>{
  try{controller.signal.throwIfAborted();let result;if(method==='session')result=await connection.session();else if(method==='signIn')result=await connection.signIn(controller.signal);else if(method==='disconnect')result=await connection.disconnect();else if(method==='rewrite')result=await connection.rewrite(message.instructions,message.input,controller.signal);else throw Error('Unknown request');reply({id,result})}
  catch(error){reply({id,error:{code:'request_failed',message:error.name==='AbortError'?'Request cancelled.':/^[A-Za-z][A-Za-z .’'—-]{0,200}$/.test(error.message)?error.message:'ChatGPT could not complete this request. Check your connection and account.'}})}
  finally{active.delete(id)}
 });
});
process.stdin.on('end',()=>process.exit(0));
