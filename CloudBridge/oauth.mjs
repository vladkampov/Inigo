// Inigo's OAuth public-client implementation, written from OpenAI's public SIWC specification.
// No Sign in with ChatGPT DevKit code is linked or vendored.
import {randomBytes,randomUUID,createHash,timingSafeEqual} from 'node:crypto';
import http from 'node:http';
import fs from 'node:fs/promises';
import path from 'node:path';
import {createRemoteJWKSet,jwtVerify} from 'jose';
import OpenAI from 'openai';
export const resource='https://api.openai.com/v1';
const issuer='https://auth.openai.com';
export function equal(a,b){if(typeof a!=='string'||typeof b!=='string')return false;const x=Buffer.from(a),y=Buffer.from(b);return x.length===y.length&&timingSafeEqual(x,y)}
export function form(values){return new URLSearchParams(values)}
export function safeEndpoint(value){const u=new URL(value);if(u.protocol!=='https:'||u.hostname!=='auth.openai.com')throw Error('Untrusted authorization endpoint');return u.href}
export function selectModel(models){const available=models.filter(m=>m.visibility==='list'&&typeof m.slug==='string');return available.find(m=>/mini/.test(m.slug))??available.find(m=>!/codex|pro/.test(m.slug))??available[0]}
export function validateClaims(payload,{clientID,nonce,subject}){if(typeof payload.exp!=='number'||!Number.isFinite(payload.exp))throw Error('Missing identity expiry');if(Array.isArray(payload.aud)&&payload.aud.length>1&&!payload.azp)throw Error('Missing authorized party');if(!payload.sub||typeof payload.sub!=='string')throw Error('Missing account identity');if(nonce&&!equal(payload.nonce,nonce))throw Error('Invalid sign-in nonce');if(subject&&payload.sub!==subject)throw Error('The account does not match this registration');if(payload.azp&&payload.azp!==clientID)throw Error('Invalid authorized party');return payload}
export function createConnection({directory,vault,openBrowser}){
 let metadata,record,discovery,jwks;
 const file=path.join(directory,'native-registration.json');
 async function init(){if(metadata)return;await fs.mkdir(directory,{recursive:true,mode:0o700});try{metadata=JSON.parse(await fs.readFile(file,'utf8'))}catch(e){if(e.code!=='ENOENT')throw Error('Saved account metadata could not be read');metadata={hostID:'urn:uuid:'+randomUUID()};await saveMetadata()}if(metadata.credentialRef)record=JSON.parse(await vault('load',metadata.credentialRef))}
 async function saveMetadata(){const temporary=file+'.'+randomUUID();await fs.writeFile(temporary,JSON.stringify(metadata),{mode:0o600});await fs.rename(temporary,file)}
 async function save(value){const old=metadata.credentialRef;const next=await vault('store',JSON.stringify(value));metadata.credentialRef=next;try{await saveMetadata()}catch(e){metadata.credentialRef=old;await vault('delete',next).catch(()=>{});throw e}record=value;if(old)await vault('delete',old).catch(()=>{})}
 async function config(){if(discovery)return discovery;const r=await fetch(issuer+'/.well-known/openid-configuration',{signal:AbortSignal.timeout(15000)});if(!r.ok)throw Error('Authorization service unavailable');const d=await r.json();if(d.issuer!==issuer)throw Error('Unexpected identity issuer');for(const k of ['authorization_endpoint','token_endpoint','jwks_uri','revocation_endpoint'])safeEndpoint(d[k]);jwks=createRemoteJWKSet(new URL(d.jwks_uri));discovery=d;return d}
 async function token(body,signal){const d=await config();const r=await fetch(d.token_endpoint,{method:'POST',headers:{'Content-Type':'application/x-www-form-urlencoded'},body:form(body),signal});if(!r.ok){const e=Error(r.status===400?'Sign in again to renew your ChatGPT connection.':'ChatGPT authentication is temporarily unavailable.');e.code='authentication_failed';throw e}const t=await r.json();if(typeof t.access_token!=='string'||typeof t.expires_in!=='number'||!Number.isFinite(t.expires_in)||t.expires_in<=0||String(t.token_type).toLowerCase()!=='bearer')throw Error('Invalid token response');return t}
 async function verify(idToken,nonce,subject){await config();const {payload}=await jwtVerify(idToken,jwks,{issuer,audience:metadata.clientID,clockTolerance:5,algorithms:['RS256','ES256']});return validateClaims(payload,{clientID:metadata.clientID,nonce,subject})}
 const session=()=>({status:record?.accessToken?'connected':'disconnected',sharing:!!record?.accessToken&&record.scopes?.includes('chatgpt.tokens.use.direct'),identity:record?.email?{email:record.email}:{}});
 function credentials(t,prior={}){return{...prior,accessToken:t.access_token,refreshToken:t.refresh_token??prior.refreshToken,expiresAt:Date.now()+t.expires_in*1000,idToken:t.id_token??prior.idToken,scopes:typeof t.scope==='string'?t.scope.split(/\s+/):prior.scopes??[],earliestRefreshAt:t.earliest_refresh_at}}
 async function ensure(signal){await init();if(!record?.accessToken)throw Error('Continue with ChatGPT in Processing settings first.');if(record.pending){const identity=await verify(record.idToken,null,metadata.subject);await save({...record,pending:false,email:identity.email})}if(record.expiresAt<=Date.now()+60000){if(!record.refreshToken)throw Error('Sign in again to renew your ChatGPT connection.');const earliest=typeof record.earliestRefreshAt==='number'?record.earliestRefreshAt*1000:Date.parse(record.earliestRefreshAt??'');if(Number.isFinite(earliest)&&earliest>Date.now()){if(record.expiresAt<=Date.now())throw Error('Your connection is not ready to refresh yet. Try again shortly.')}else{const t=await token({grant_type:'refresh_token',client_id:metadata.clientID,refresh_token:record.refreshToken,resource},AbortSignal.timeout(60000));const next=credentials(t,record);await save({...next,pending:!!t.id_token});if(t.id_token){const identity=await verify(t.id_token,null,metadata.subject);await save({...next,pending:false,email:identity.email})}}}signal?.throwIfAborted();if(!record.scopes.includes('chatgpt.tokens.use.direct'))throw Error('Enable ChatGPT plan usage in your account settings.');return record.accessToken}
 return{
  async session(){await init();return session()},
  async signIn(signal){
   await init();const d=await config();const state=randomBytes(32).toString('base64url'),nonce=randomBytes(32).toString('base64url'),verifier=randomBytes(48).toString('base64url');
   const controller=new AbortController();const combined=AbortSignal.any([signal,controller.signal,AbortSignal.timeout(600000)]);
   let resolveCallback,rejectCallback;const callback=new Promise((resolve,reject)=>{resolveCallback=resolve;rejectCallback=reject});
   // Attach a handler immediately so cancellation while opening the browser is never unhandled.
   callback.catch(()=>{});
   const server=http.createServer((req,res)=>{
    const url=new URL(req.url,'http://127.0.0.1');
    if(req.method!=='GET'||url.pathname!=='/auth/callback'||!equal(url.searchParams.get('state'),state)){res.writeHead(400,{'Content-Type':'text/plain'});res.end('Invalid sign-in callback');return}
    res.writeHead(200,{'Content-Type':'text/plain','Cache-Control':'no-store'});res.end('Return to Inigo to finish signing in.');resolveCallback(url.searchParams);
   });
   server.requestTimeout=5000;server.headersTimeout=5000;
   const abort=()=>{rejectCallback(Error('Sign-in cancelled'));server.close();server.closeAllConnections()};combined.addEventListener('abort',abort,{once:true});
   try{
    await new Promise((resolve,reject)=>{server.once('error',reject);server.listen(0,'127.0.0.1',resolve)});
    const redirect=`http://127.0.0.1:${server.address().port}/auth/callback`;
    const args={client_id:metadata.clientID??'dynamic_agent_client',ext_agent_host_id:metadata.hostID,response_type:'code',redirect_uri:redirect,scope:'openid profile email offline_access resource.invoke chatgpt.tokens.use.direct',resource,state,nonce,code_challenge_method:'S256',code_challenge:createHash('sha256').update(verifier).digest('base64url')};
    if(!metadata.clientID)args.agent_name_hint='Inigo';if(record?.idToken)args.id_token_hint=record.idToken;
    const url=new URL(d.authorization_endpoint);url.search=form(args).toString();combined.throwIfAborted();openBrowser(url.href);
    const response=await callback;combined.throwIfAborted();if(response.has('error'))throw Error('ChatGPT sign-in was not authorized.');
    const issued=response.get('client_id')??metadata.clientID;
    if(!issued||issued==='dynamic_agent_client'||!/^[-\w]{1,200}$/.test(issued)||(metadata.clientID&&issued!==metadata.clientID))throw Error('The registration did not match the pending request.');
    metadata.clientID=issued;await saveMetadata();const code=response.get('code');if(!code)throw Error('No sign-in code was returned.');
    const t=await token({grant_type:'authorization_code',client_id:issued,code,code_verifier:verifier,redirect_uri:redirect,resource},combined);
    if(typeof t.id_token!=='string')throw Error('No verified account identity was returned.');
    const identity=await verify(t.id_token,nonce,metadata.subject);metadata.subject=identity.sub;await save({...credentials(t),email:identity.email,pending:false});return session();
   }finally{combined.removeEventListener('abort',abort);server.close();server.closeAllConnections()}
  },
  async disconnect(){await init();let revoked=true;if(record?.refreshToken){try{const d=await config();const r=await fetch(d.revocation_endpoint,{method:'POST',headers:{'Content-Type':'application/x-www-form-urlencoded'},body:form({token:record.refreshToken,token_type_hint:'refresh_token',client_id:metadata.clientID}),signal:AbortSignal.timeout(15000)});revoked=r.status===200}catch{revoked=false}}const old=metadata.credentialRef;delete metadata.credentialRef;await saveMetadata();record=undefined;if(old)await vault('delete',old);return{status:'disconnected',sharing:false,revoked}},
  async rewrite(instructions,input,signal){const access=await ensure(signal);const r=await fetch(resource+'/models',{headers:{Authorization:'Bearer '+access},signal});if(!r.ok)throw Error('Your ChatGPT model list is unavailable. Check plan usage permissions.');const catalog=await r.json();const model=selectModel(catalog.models??[]);if(!model)throw Error('No eligible writing model is available.');const client=new OpenAI({apiKey:access,baseURL:resource,maxRetries:0});const stream=await client.responses.create({model:model.slug,instructions,input:[{role:'user',content:input}],store:false,stream:true},{signal});let text='',completed=false;for await(const event of stream){if(event.type==='response.output_text.delta')text+=event.delta;if(event.type==='response.completed')completed=true;if(['response.failed','response.incomplete','error'].includes(event.type))throw Error('ChatGPT did not complete the rewrite. Check your plan usage or try again.')}if(!completed||!text)throw Error('The rewrite stream ended before completion.');return{text}}
 };
}
