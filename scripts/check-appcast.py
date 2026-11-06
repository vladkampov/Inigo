#!/usr/bin/env python3
import sys,xml.etree.ElementTree as ET,urllib.parse,base64
root=ET.parse(sys.argv[1]).getroot();ns='{http://www.andymatuschak.org/xml-namespaces/sparkle}'
items=root.findall('./channel/item')
if not items:raise SystemExit('Refusing to deploy an empty release feed')
for item in items:
 enclosure=item.find('enclosure')
 if enclosure is None:raise SystemExit('Missing enclosure')
 url=urllib.parse.urlparse(enclosure.get('url',''))
 if url.scheme!='https' or url.netloc!='github.com' or not url.path.startswith('/vladkampov/Inigo/releases/download/v'):
  raise SystemExit('Unexpected release archive destination')
 signature=enclosure.get(ns+'edSignature','')
 if len(base64.b64decode(signature,validate=True))!=64:raise SystemExit('Missing Ed25519 archive signature')
 if int(enclosure.get('length','0'))<=0:raise SystemExit('Invalid archive size')
 if item.find(ns+'version') is None and not enclosure.get(ns+'version'):raise SystemExit('Missing build number')
print('Appcast shape verified. Cryptographic archive verification and update smoke test remain mandatory.')
