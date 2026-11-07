import importlib.util,pathlib,tempfile,subprocess,plistlib,os,unittest,json
root=pathlib.Path(__file__).resolve().parents[2]
spec=importlib.util.spec_from_file_location('version',root/'scripts/version.py');version=importlib.util.module_from_spec(spec);spec.loader.exec_module(version)
class ReleaseTests(unittest.TestCase):
 def test_semver(self):
  for value in ['0.2.0','1.2.3-beta.1','1.2.3+build.2']:self.assertEqual(version.validate(value),value)
  for value in ['1.2','01.2.3','1.2.3-01','v1.2.3','1.2.3;echo bad']:
   with self.assertRaises(ValueError):version.validate(value)
 def test_bundle_update_security_defaults(self):
  with tempfile.TemporaryDirectory() as tmp:
   file=pathlib.Path(tmp)/'Info.plist';file.write_bytes(plistlib.dumps({'SUPublicEDKey':'old','SUFeedURL':'https://old.example/feed'}))
   env=dict(os.environ);env.pop('INIGO_UPDATE_PUBLIC_KEY',None);env.pop('INIGO_PUBLIC_LINKS',None);env.pop('INIGO_ENABLE_UPDATES',None)
   subprocess.run(['python3',str(root/'scripts/configure-bundle.py'),str(file)],env=env,check=True)
   data=plistlib.loads(file.read_bytes())
   self.assertEqual(data['SUScheduledCheckInterval'],3600)
   self.assertFalse(data['SUAutomaticallyUpdate']);self.assertFalse(data['SUAllowsAutomaticUpdates'])
   self.assertFalse(data['SUEnableSystemProfiling']);self.assertTrue(data['SUVerifyUpdateBeforeExtraction'])
   self.assertNotIn('SUPublicEDKey',data);self.assertNotIn('SUFeedURL',data)
 def test_enabled_beta_uses_separate_feed(self):
  with tempfile.TemporaryDirectory() as tmp:
   file=pathlib.Path(tmp)/'Info.plist';file.write_bytes(plistlib.dumps({}))
   env=dict(os.environ,INIGO_ENABLE_UPDATES='1');env.pop('INIGO_UPDATE_PUBLIC_KEY',None)
   subprocess.run(['python3',str(root/'scripts/configure-bundle.py'),str(file)],env=env,check=True)
   data=plistlib.loads(file.read_bytes());config=json.loads((root/'release/config.json').read_text())
   self.assertEqual(data['SUFeedURL'],config['betaFeedURL'])
   self.assertEqual(data['SUPublicEDKey'],config['publicEDKey'])
 def test_stable_and_prerelease_bundle_channels(self):
  import shutil
  with tempfile.TemporaryDirectory() as tmp:
   checkout=pathlib.Path(tmp)
   (checkout/'scripts').mkdir();(checkout/'release').mkdir()
   for name in ['configure-bundle.py','version.py']:
    shutil.copyfile(root/'scripts'/name,checkout/'scripts'/name)
   shutil.copyfile(root/'release/config.json',checkout/'release/config.json')
   (checkout/'BUILD_NUMBER').write_text('2000')
   config=json.loads((checkout/'release/config.json').read_text())
   self.assertNotEqual(config['feedURL'],config['betaFeedURL'])
   env=dict(os.environ,INIGO_ENABLE_UPDATES='1');env.pop('INIGO_UPDATE_PUBLIC_KEY',None)
   for version,channel in [('1.0.0','feedURL'),('1.0.0+build.1','feedURL'),('1.0.0-beta.8','betaFeedURL')]:
    with self.subTest(version=version):
     (checkout/'VERSION').write_text(version)
     file=checkout/'Info.plist';file.write_bytes(plistlib.dumps({}))
     subprocess.run(['python3',str(checkout/'scripts/configure-bundle.py'),str(file)],env=env,check=True)
     data=plistlib.loads(file.read_bytes())
     self.assertEqual(data['SUFeedURL'],config[channel])
     self.assertEqual(data['InigoDisplayVersion'],version)
     self.assertEqual(data['CFBundleShortVersionString'],'1.0.0')
     self.assertFalse(data['SUAutomaticallyUpdate'])
     self.assertTrue(data['SUVerifyUpdateBeforeExtraction'])
 def test_issue_forms_match_labels(self):
  labels={x['name'] for x in json.loads((root/'.github/labels.json').read_text())}
  for file in (root/'.github/ISSUE_TEMPLATE').glob('*.yml'):
   data=json.loads(file.read_text())
   for label in data.get('labels',[]):self.assertIn(label,labels)
if __name__=='__main__':unittest.main()
