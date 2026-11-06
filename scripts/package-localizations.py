import json, pathlib, sys, plistlib, re
source=pathlib.Path('Localization'); output=pathlib.Path(sys.argv[1]); output.mkdir(parents=True,exist_ok=True)
data={p.stem:json.loads(p.read_text()) for p in source.glob('*.json')}
if len(data)!=24: raise SystemExit('Expected 24 complete language catalogs')
keys=set(data['en'])
for code,strings in data.items():
 if set(strings)!=keys or any(not isinstance(v,str) or not v.strip() for v in strings.values()):raise SystemExit('Incomplete catalog: '+code)
 for key,value in strings.items():
  for marker in ['%d','%@']:
   if key.count(marker)!=value.count(marker):raise SystemExit('Invalid placeholder in '+code+': '+key)
 folder=output/(code+'.lproj');folder.mkdir(exist_ok=True)
 with (folder/'InfoPlist.strings').open('wb') as f:plistlib.dump({'CFBundleDisplayName':'Inigo'},f)
 with (folder/'ServicesMenu.strings').open('wb') as f:plistlib.dump({key:strings[key] for key in ['Refine with Inigo','Translate with Inigo']},f)
(output/'Translations.json').write_text(json.dumps(data,ensure_ascii=False))
