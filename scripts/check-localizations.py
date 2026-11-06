import json,pathlib,re
source=pathlib.Path(__file__).resolve().parent.parent/'Localization'
english=json.loads((source/'en.json').read_text()); issues=[]
expected=set('en es fr de pt it nl pl uk tr ar fa ur hi bn ta te mr id vi th zh ja ko'.split())
if {p.stem for p in source.glob('*.json')} != expected:issues.append('Language catalogs do not match the 24 supported locales')
for file in source.glob('*.json'):
 data=json.loads(file.read_text())
 missing=set(english)-set(data)
 if missing:issues.append(f'{file.stem}: {len(missing)} missing keys')
 for key,value in data.items():
  if not value.strip():issues.append(f'{file.stem}: empty {key!r}')
  for placeholder in ['%d','%@']:
   if key.count(placeholder)!=value.count(placeholder):issues.append(f'{file.stem}: placeholder {placeholder} differs: {key!r}')
print('\n'.join(issues) if issues else 'All interface catalogs complete; placeholders preserved.')
raise SystemExit(bool(issues))
