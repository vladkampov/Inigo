#!/usr/bin/env python3
"""Verify the built app and embedded extension agree with mobile SemVer metadata."""
import pathlib, plistlib, sys
from version import validate
root = pathlib.Path(__file__).resolve().parent.parent / 'Mobile'
version = validate((root/'VERSION').read_text().strip())
build = (root/'BUILD_NUMBER').read_text().strip()
app = pathlib.Path(sys.argv[1])
expected = {'CFBundleShortVersionString':version.split('-')[0].split('+')[0], 'CFBundleVersion':build, 'InigoDisplayVersion':version}
for bundle in [app, app/'PlugIns/InigoShare.appex']:
    data = plistlib.loads((bundle/'Info.plist').read_bytes())
    for key,value in expected.items():
        if data.get(key) != value: raise ValueError(f'{bundle.name}: wrong {key}')
    if 'SUFeedURL' in data or 'SUPublicEDKey' in data: raise ValueError('Sparkle must not be configured on iOS')
print(f'App and extension match iOS {version} ({build}); no Sparkle configuration.')
