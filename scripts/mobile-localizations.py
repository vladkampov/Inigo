#!/usr/bin/env python3
"""Validate and deterministically package the mobile interface catalogs."""
import argparse, collections, json, pathlib, re
root = pathlib.Path(__file__).resolve().parents[1]
parser = argparse.ArgumentParser(); parser.add_argument('--check', action='store_true'); args = parser.parse_args()
folder = root/'Mobile/Localization'
catalogs = {p.stem: json.loads(p.read_text()) for p in sorted(folder.glob('*.json'))}
expected = {p.stem for p in (root/'Localization').glob('*.json')}
assert set(catalogs) == expected, 'Mobile language coverage differs from desktop'
base = catalogs['en']
for language, catalog in catalogs.items():
    assert catalog.keys() == base.keys(), f'{language}: incomplete catalog'
    for key, value in catalog.items():
        assert isinstance(value, str) and value.strip(), f'{language}: empty value'
        placeholders = lambda s: collections.Counter(re.findall(r'%(?:@|d)', s))
        assert placeholders(key) == placeholders(value), f'{language}: changed placeholders'
packed = json.dumps(catalogs, ensure_ascii=False, sort_keys=True, indent=2) + '\n'
output = root/'Mobile/Resources/Translations.json'
if args.check:
    assert output.read_text() == packed, 'Run scripts/mobile-localizations.py'
else:
    output.parent.mkdir(parents=True, exist_ok=True); output.write_text(packed)
print(f'Validated {len(catalogs)} languages, {len(base)} messages each.')
