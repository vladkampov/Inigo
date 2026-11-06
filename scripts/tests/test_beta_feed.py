import importlib.util,pathlib,unittest
spec=importlib.util.spec_from_file_location('feed',pathlib.Path(__file__).resolve().parents[1]/'prepare-beta-feed.py');feed=importlib.util.module_from_spec(spec);spec.loader.exec_module(feed)
class BetaFeedTests(unittest.TestCase):
 def data(self,url=None,build='1016'):
  import base64
  url=url or 'https://github.com/vladkampov/Inigo/releases/download/v0.2.0-beta.5/Inigo-0.2.0-beta.5.zip'
  return f'<rss xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle"><channel><item><sparkle:version>{build}</sparkle:version><enclosure url="{url}" length="100" sparkle:edSignature="{base64.b64encode(bytes(64)).decode()}"/></item></channel></rss>'
 def test_valid_structure(self):self.assertEqual(feed.validate_item(self.data(),'v0.2.0-beta.5')[0],1016)
 def test_wrong_destination(self):
  with self.assertRaises(ValueError):feed.validate_item(self.data(url='https://example.com/file'),'v0.2.0-beta.5')
 def test_invalid_build(self):
  with self.assertRaises(ValueError):feed.validate_item(self.data(build='0'),'v0.2.0-beta.5')
 def test_wrong_release(self):
  with self.assertRaises(ValueError):feed.validate_item(self.data(),'v0.2.0-beta.6')
 def test_feed_rollback_is_rejected(self):
  import json,base64
  from unittest.mock import patch
  responses=[json.dumps([{'ref':'refs/heads/update-feed'}]),json.dumps({'tree':[{'path':'beta/appcast.xml','sha':'old'}]}),json.dumps({'content':base64.b64encode(self.data(build='1017').encode()).decode()})]
  with patch.object(feed,'output',side_effect=responses),patch.object(feed,'api') as api:
   with self.assertRaises(ValueError):feed.publish(self.data().encode(),1016)
   api.assert_not_called()
 def test_same_build_cannot_change_artifacts(self):
  import json,base64
  from unittest.mock import patch
  responses=[json.dumps([{'ref':'refs/heads/update-feed'}]),json.dumps({'tree':[{'path':'beta/appcast.xml','sha':'old'}]}),json.dumps({'content':base64.b64encode(self.data().encode()).decode()})]
  with patch.object(feed,'output',side_effect=responses),patch.object(feed,'api') as api:
   with self.assertRaises(ValueError):feed.publish(self.data(url='https://changed.example').encode(),1016)
   api.assert_not_called()
