import json, pathlib, plistlib, subprocess, tempfile, unittest
root = pathlib.Path(__file__).resolve().parents[2]
class MobileReleaseTests(unittest.TestCase):
 def test_generated_version_is_current(self):
  subprocess.run(['python3',str(root/'scripts/mobile-version.py'),'--check'],check=True,capture_output=True)
 def test_bundle_alignment_and_rejection(self):
  version=(root/'Mobile/VERSION').read_text().strip();build=(root/'Mobile/BUILD_NUMBER').read_text().strip()
  expected={'CFBundleShortVersionString':version.split('-')[0].split('+')[0],'CFBundleVersion':build,'InigoDisplayVersion':version}
  with tempfile.TemporaryDirectory() as tmp:
   app=pathlib.Path(tmp)/'Inigo.app';extension=app/'PlugIns/InigoShare.appex';extension.mkdir(parents=True)
   for bundle in [app,extension]:(bundle/'Info.plist').write_bytes(plistlib.dumps(expected))
   command=['python3',str(root/'scripts/check-mobile-bundle.py'),str(app)]
   self.assertEqual(subprocess.run(command,capture_output=True).returncode,0)
   for change in [{'CFBundleShortVersionString':'9.9.9'},{'CFBundleVersion':'9999'},{'SUFeedURL':'https://example.com'}]:
    (extension/'Info.plist').write_bytes(plistlib.dumps(dict(expected,**change)))
    self.assertNotEqual(subprocess.run(command,capture_output=True).returncode,0)
 def test_mobile_localizations_are_complete_and_packaged(self):
  subprocess.run(['python3',str(root/'scripts/mobile-localizations.py'),'--check'],check=True,capture_output=True)
 def test_shared_group_and_privacy_manifest(self):
  entitlements=plistlib.loads((root/'Mobile/Shared.entitlements').read_bytes())
  self.assertEqual(entitlements['com.apple.security.application-groups'],['group.app.inigo.mobile'])
  project=(root/'Mobile/project.yml').read_text()
  self.assertEqual(project.count('CODE_SIGN_ENTITLEMENTS: Shared.entitlements'),2)
  privacy=plistlib.loads((root/'Mobile/Resources/PrivacyInfo.xcprivacy').read_bytes())
  self.assertFalse(privacy['NSPrivacyTracking'])
  self.assertEqual(privacy['NSPrivacyCollectedDataTypes'],[])
