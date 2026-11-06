#!/usr/bin/env python3
import json,os,pathlib,plistlib,sys,base64
from version import validate
root=pathlib.Path(__file__).resolve().parent.parent
version=validate((root/'VERSION').read_text().strip());build=(root/'BUILD_NUMBER').read_text().strip()
if not build.isdigit() or not 0<int(build)<10000:raise ValueError('BUILD_NUMBER must be an increasing integer from 1 to 9999')
file=pathlib.Path(sys.argv[1]);data=plistlib.loads(file.read_bytes());config=json.loads((root/'release/config.json').read_text())
data.update(CFBundleShortVersionString=version.split('-')[0].split('+')[0],CFBundleVersion=build,InigoDisplayVersion=version,SUEnableAutomaticChecks=True,SUScheduledCheckInterval=3600,SUAutomaticallyUpdate=False,SUAllowsAutomaticUpdates=False,SUEnableSystemProfiling=False,SUVerifyUpdateBeforeExtraction=True)
key=os.environ.get('INIGO_UPDATE_PUBLIC_KEY',config['publicEDKey'])
if key and os.environ.get('INIGO_ENABLE_UPDATES') == '1':
 if len(base64.b64decode(key,validate=True))!=32:raise ValueError('Invalid Sparkle public key')
 data['SUPublicEDKey']=key;data['SUFeedURL']=config['feedURL']
if os.environ.get('INIGO_PUBLIC_LINKS')=='1':data['InigoRepositoryURL']=config['repository']
if config['supportURL']:data['InigoCoffeeURL']=config['supportURL']
if config['sentryDSN']:data['InigoSentryDSN']=config['sentryDSN']
file.write_bytes(plistlib.dumps(data))
