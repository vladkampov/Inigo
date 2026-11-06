#!/usr/bin/env python3
"""Synthetic, serial comparison using the app's exported production prompts."""
import json,pathlib,subprocess,time,urllib.request,statistics,re,threading,hashlib,platform,os
def digest_file(file):
 h=hashlib.sha256()
 while chunk:=file.read(4*1024*1024):h.update(chunk)
 return h.hexdigest()
root=pathlib.Path(__file__).resolve().parent.parent
cases={x['id']:x for x in json.loads((root/'benchmarks/cases.json').read_text())}
prompts=json.loads((root/'benchmarks/prompts.json').read_text())
source=(root/'Sources/InigoCore/LocalModels.swift').read_text()
models=re.findall(r'\.init\(id:"([^"]+)",name:"[^"]+",filename:"([^"]+)",revision:"([^"]+)",bytes:\d+,sha256:"([^"]+)"',source)
out=root/'benchmarks/results';out.mkdir(exist_ok=True)
hardware={k:subprocess.check_output(cmd,text=True).strip() for k,cmd in {'chip':['sysctl','-n','machdep.cpu.brand_string'],'memory_bytes':['sysctl','-n','hw.memsize'],'macos':['sw_vers','-productVersion']}.items()}
for model,filename,revision,digest in models:
 path=root/'.models'/filename
 while not path.exists():print('Waiting for verified download',model,flush=True);time.sleep(15)
 with path.open('rb') as file:
  if digest_file(file)!=digest:raise RuntimeError('Wrong checksum')
 port=48622;log=(out/f'{model}-runtime.log').open('w')
 start=time.monotonic()
 proc=subprocess.Popen([str(root/'.runtime/llama/llama-b12172/llama-server'),'-m',str(path),'--host','127.0.0.1','--port',str(port),'-c','8192','-ngl','99','--parallel','1','--no-webui','--jinja','--reasoning-budget','0'],stdout=log,stderr=log)
 stop=threading.Event();rss=[]
 def monitor():
  while not stop.wait(.25):
   try:rss.append(int(subprocess.check_output(['ps','-o','rss=','-p',str(proc.pid)],text=True).strip())*1024)
   except Exception:pass
 thread=threading.Thread(target=monitor);thread.start()
 result=dict(model=model,revision=revision,sha256=digest,hardware=hardware,runtime='llama.cpp b12172',context=8192,repetitions=2,results=[])
 try:
  for _ in range(240):
   if proc.poll() is not None:raise RuntimeError('Runtime exited')
   try:urllib.request.urlopen(f'http://127.0.0.1:{port}/health',timeout=2);break
   except Exception:time.sleep(.25)
  else:raise RuntimeError('Startup timeout')
  result['startup_seconds']=time.monotonic()-start
  for repetition in range(2):
   for prompt in prompts:
    case=cases[prompt['id']]
    body=dict(messages=prompt['messages'],temperature=.1,max_tokens=4096,stream=False,cache_prompt=False,chat_template_kwargs={'enable_thinking':False})
    req=urllib.request.Request(f'http://127.0.0.1:{port}/v1/chat/completions',json.dumps(body).encode(),{'Content-Type':'application/json'})
    t=time.monotonic()
    try:
     response=json.load(urllib.request.urlopen(req,timeout=180));elapsed=time.monotonic()-t
     choice=response['choices'][0];text=choice['message']['content']
     markers=re.findall(r'⟦INIGO_[^⟧]*⟧',text)
     missing=[v for v in case['must'] if v not in text and not (v.startswith(('@','#','http')) and prompt['tokens'])]
     record=dict(id=case['id'],repetition=repetition,seconds=elapsed,output=text,complete=choice['finish_reason']=='stop',protected_ok=markers==prompt['tokens'],missing=missing,forbidden_found=[v for v in case['forbid'] if v in text],timings=response.get('timings',{}))
    except Exception as e:record=dict(id=case['id'],repetition=repetition,error=type(e).__name__)
    result['results'].append(record)
    (out/f'{model}.json').write_text(json.dumps(result,ensure_ascii=False,indent=2))
    print(model,repetition,case['id'],round(record.get('seconds',0),2),record.get('error',''),flush=True)
 finally:
  stop.set();thread.join();proc.terminate();proc.wait();log.close()
  result['peak_process_rss_bytes']=max(rss,default=0)
  result['memory_measurement_note']='Process RSS only, not total Metal/unified-memory allocation. Runtime log lists GPU buffers.'
  (out/f'{model}.json').write_text(json.dumps(result,ensure_ascii=False,indent=2))
 print('COMPLETE',model,flush=True)
