import json, subprocess, urllib.request, time, pathlib, secrets
root=pathlib.Path(__file__).resolve().parent.parent; token=secrets.token_hex(24); port=49471
proc=subprocess.Popen([str(root/'.runtime/llama/llama-b12172/llama-server'),'-m',str(root/'.models/Qwen3.5-4B-Q4_K_M.gguf'),'--host','127.0.0.1','--port',str(port),'-c','32768','-ngl','99','--parallel','4','--api-key',token,'--no-webui','--log-disable','--jinja','--reasoning-budget','0'],stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL)
def request(data):
 req=urllib.request.Request(f'http://127.0.0.1:{port}/v1/chat/completions',json.dumps(data).encode(),{'Content-Type':'application/json','Authorization':'Bearer '+token})
 return json.load(urllib.request.urlopen(req,timeout=240))
langs={'pl':'Polish','uk':'Ukrainian','es':'Spanish','fr':'French','de':'German','pt':'Portuguese','it':'Italian','nl':'Dutch','tr':'Turkish','ar':'Arabic','fa':'Persian','ur':'Urdu','hi':'Hindi','bn':'Bengali','ta':'Tamil','te':'Telugu','mr':'Marathi','id':'Indonesian','vi':'Vietnamese','th':'Thai','zh':'Simplified Chinese','ja':'Japanese','ko':'Korean'}
try:
 for _ in range(180):
  try:
   urllib.request.urlopen(f'http://127.0.0.1:{port}/health',timeout=2);break
  except Exception: time.sleep(0.5)
 keys=list(json.loads((root/'Localization/en.json').read_text()))
 (root/'Localization/en.json').write_text(json.dumps({k:k for k in keys},ensure_ascii=False,indent=2))
 def translate_language(pair):
  code,name=pair
  file=root/f'Localization/{code}.json'; done=json.loads(file.read_text()) if file.exists() else {}
  for start in range(0,len(keys),16):
   batch=[k for k in keys[start:start+16] if k not in done]
   if not batch:continue
   inp={str(i):k for i,k in enumerate(batch)}
   schema={'type':'object','properties':{k:{'type':'string'} for k in inp},'required':list(inp),'additionalProperties':False}
   for attempt in range(3):
    try:
     result=request({'messages':[{'role':'system','content':f'Translate every value of this JSON object from English into natural {name} for a native macOS writing assistant. Preserve keys, brand Inigo, keyboard symbols, technical identifiers and numbers. Do not explain. Output only the translated JSON object.'},{'role':'user','content':json.dumps(inp,ensure_ascii=False)}],'temperature':0.1,'max_tokens':3000,'response_format':{'type':'json_object','schema':schema},'chat_template_kwargs':{'enable_thinking':False}})
     choice=result['choices'][0];out=json.loads(choice['message']['content'])
     assert choice['finish_reason']=='stop' and set(out)==set(inp) and all(isinstance(v,str) and v.strip() for v in out.values())
     done.update({batch[int(k)]:v for k,v in out.items()});file.write_text(json.dumps(done,ensure_ascii=False,indent=2));break
    except Exception as e:
     if attempt==2:raise
   print(code,len(done),flush=True)
  print('COMPLETE',code,flush=True)
 from concurrent.futures import ThreadPoolExecutor
 with ThreadPoolExecutor(max_workers=4) as pool:
  list(pool.map(translate_language,langs.items()))

finally:proc.terminate();proc.wait()
