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

class ChannelIsolationTests(unittest.TestCase):
 def test_release_flags_and_versions_must_agree(self):
  for tag,prerelease,expected in [('v1.0.0',False,'stable'),('v1.0.0-beta.1',True,'beta'),('v1.0.0',True,None),('v1.0.0-beta.1',False,None),('v1.0.0-rc.1',True,None)]:
   for channel in ['stable','beta']:
    with self.subTest(tag=tag,channel=channel):
     release={'tag_name':tag,'prerelease':prerelease,'draft':False}
     self.assertEqual(feed.eligible_release(release,channel),channel==expected)
     release['draft']=True
     self.assertFalse(feed.eligible_release(release,channel))
 def test_stable_publish_does_not_touch_beta(self):
  import json
  from unittest.mock import patch
  responses=[json.dumps([{'ref':'refs/heads/update-feed'}]),json.dumps({'tree':[{'path':'beta/appcast.xml','sha':'beta'}]})]
  with patch.object(feed,'output',side_effect=responses),patch.object(feed,'api') as api:
   feed.publish(b'<rss/>',2000,'stable')
   self.assertEqual(api.call_args.args[1],'contents/stable/appcast.xml')
   self.assertNotIn('sha',api.call_args.args[2])
 def test_unknown_channel_fails_before_network(self):
  from unittest.mock import patch
  with patch.object(feed,'output') as output:
   with self.assertRaises(ValueError):feed.publish(b'',2000,'../beta')
   output.assert_not_called()
 def test_missing_stable_does_not_publish_beta(self):
  from unittest.mock import patch
  import json
  releases=[[{'tag_name':'v1.0.0-beta.1','prerelease':True,'draft':False}]]
  with patch.object(feed.sys,'argv',['feed','--channel','stable','--publish']),patch.object(feed,'output',return_value=json.dumps(releases)),patch.object(feed,'publish') as publish:
   with self.assertRaisesRegex(ValueError,'No published signed stable'):feed.main()
   publish.assert_not_called()

class PublicationFailureTests(unittest.TestCase):
 def test_failed_verification_never_publishes(self):
  import tempfile,json,hashlib,base64,subprocess
  from unittest.mock import patch
  for failure in ['checksum','size','key','signature']:
   with self.subTest(failure=failure),tempfile.TemporaryDirectory() as tmp:
    root=pathlib.Path(tmp);(root/'release').mkdir()
    (root/'release/config.json').write_text(json.dumps({'publicEDKey':base64.b64encode(bytes(31 if failure=='key' else 32)).decode()}))
    tag='v1.0.0';name='Inigo-1.0.0.zip';archive=b'synthetic archive'
    xml=BetaFeedTests().data(url=f'https://github.com/vladkampov/Inigo/releases/download/{tag}/{name}',build='2000').replace('length="100"',f'length="{len(archive)+(1 if failure=="size" else 0)}"')
    releases=[[{'tag_name':tag,'draft':False,'prerelease':False,'assets':[{'name':n} for n in ['appcast.xml','SHA256SUMS',name]]}]]
    def run(args,**kw):
     if args[0]=='gh':
      folder=pathlib.Path(args[args.index('--dir')+1]);pattern=args[args.index('--pattern')+1]
      contents={'appcast.xml':xml.encode(),name:archive,'SHA256SUMS':f'{"0"*64 if failure=="checksum" else hashlib.sha256(archive).hexdigest()}  {name}\n'.encode()}
      (folder/pattern).write_bytes(contents[pattern])
     else: raise subprocess.CalledProcessError(1,args)
    with patch.object(feed,'ROOT',root),patch.object(feed.sys,'argv',['feed','--channel','stable','--publish']),patch.object(feed,'output',return_value=json.dumps(releases)),patch.object(feed,'run',side_effect=run),patch.object(feed,'publish') as publish:
     with self.assertRaises((ValueError,subprocess.CalledProcessError)):feed.main()
     publish.assert_not_called()
     self.assertFalse((root/'updates/stable/appcast.xml').exists())
