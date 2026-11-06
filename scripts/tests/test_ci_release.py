import importlib.util, os, pathlib, tempfile, unittest
from unittest.mock import patch
spec = importlib.util.spec_from_file_location('ci_release', pathlib.Path(__file__).resolve().parents[1]/'ci-release.py')
ci = importlib.util.module_from_spec(spec); spec.loader.exec_module(ci)
class ReleaseSafety(unittest.TestCase):
    def test_reject_invalid_tag(self):
        for value in ['main', '--help', 'v1.0.0;echo bad', '../release']:
            with self.subTest(value=value), patch.dict(os.environ, RELEASE_TAG=value):
                with self.assertRaises(ValueError): ci.tag()
    def test_never_modify_published_release(self):
        with patch.dict(os.environ, RELEASE_TAG='v0.2.0-beta.2'), patch.object(ci,'output',return_value='{"draft":false}'):
            with self.assertRaises(ValueError): ci.release()
    def test_never_overwrite_assets(self):
        with patch.object(ci,'release',return_value={'assets':[{'name':'existing.zip'}]}), patch.object(ci,'run') as run:
            with self.assertRaises(ValueError): ci.upload()
            run.assert_not_called()
    def test_missing_secrets_fail_before_keychain_changes(self):
        with patch.dict(os.environ,{},clear=True), patch.object(ci,'run') as run:
            with self.assertRaises(ValueError): ci.credentials()
            run.assert_not_called()
    def test_cleanup_restores_original_search_list(self):
        with tempfile.TemporaryDirectory() as temp:
            state=pathlib.Path(temp)/'credentials';state.mkdir()
            (state/'original-keychains.json').write_text('["/original/login.keychain-db"]')
            (state/'release.keychain-db').touch()
            with patch.object(ci,'STATE',state), patch.object(ci,'run') as run:
                ci.cleanup()
                self.assertEqual(run.call_args_list[0].args[0],['security','list-keychains','-d','user','-s','/original/login.keychain-db'])
                self.assertFalse(state.exists())
