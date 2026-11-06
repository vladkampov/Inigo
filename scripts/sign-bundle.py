#!/usr/bin/env python3
"""Sign nested Mach-O files and bundles inside-out for Developer ID distribution."""
import os,pathlib,subprocess,sys
app=pathlib.Path(sys.argv[1]);identity=sys.argv[2]
if not identity.startswith('Developer ID Application:'):raise SystemExit('A Developer ID Application identity is required.')
def sign(path):
 keychain = ['--keychain',os.environ['INIGO_SIGN_KEYCHAIN']] if os.environ.get('INIGO_SIGN_KEYCHAIN') else []
 subprocess.run(['codesign',*keychain,'--force','--options','runtime','--preserve-metadata=entitlements','--timestamp','--sign',os.environ.get('INIGO_SIGN_HASH',identity),str(path)],check=True)
# Do not use --deep for signing: every nested executable needs its own signature.
for path in sorted(app.rglob('*'),key=lambda x:len(x.parts),reverse=True):
 if path.is_symlink():continue
 if path.is_file():
  description=subprocess.check_output(['file','-b',str(path)],text=True)
  if 'Mach-O' in description:sign(path)
 elif path.suffix in ['.xpc','.app','.framework']:sign(path)
sign(app)
subprocess.run(['codesign','--verify','--deep','--strict',str(app)],check=True)
