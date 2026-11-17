import importlib.util
import json
import pathlib
import tempfile
import unittest

ROOT = pathlib.Path(__file__).resolve().parents[2]
spec = importlib.util.spec_from_file_location('check_localizations', ROOT / 'scripts/check-localizations.py')
checker = importlib.util.module_from_spec(spec)
spec.loader.exec_module(checker)


class CriticalLocalizationTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.folder = pathlib.Path(self.temporary.name)
        self.fixtures = ROOT / 'scripts/fixtures/critical-localizations.json'
        self.messages = json.loads(self.fixtures.read_text())['messages']
        source = {item['source']: item['source'] for item in self.messages}
        source['Hello %@'] = 'Hello %@'
        for locale in checker.EXPECTED_LOCALES:
            data = dict(source)
            for item in self.messages:
                if item['locale'] == locale:
                    data[item['source']] = item['expected']
            self.write(locale, data)

    def write(self, locale, data):
        (self.folder / f'{locale}.json').write_text(json.dumps(data, ensure_ascii=False))

    def change(self, locale, key, value):
        data = json.loads((self.folder / f'{locale}.json').read_text())
        data[key] = value
        self.write(locale, data)

    def check(self):
        return checker.validate_catalogs(self.folder, self.fixtures)

    def test_curated_messages_and_all_catalogs_pass(self):
        self.assertEqual(self.check(), [])

    def test_reversed_keychain_actions_are_rejected(self):
        for locale, reversed_copy in [
            ('de', 'Schließen Sie Ihren Keychain, um ChatGPT zu verwenden.'),
            ('ta', 'ChatGPT-ஐ பயன்படுத்த Keychain-ஐ அடைக்கவும்.'),
            ('te', 'ChatGPT ను ఉపయోగించడానికి మీ కీచేయిని (Keychain) లాక్ చేయండి.'),
        ]:
            with self.subTest(locale=locale):
                self.change(locale, 'Unlock your Keychain to use ChatGPT.', reversed_copy)
                self.assertTrue(any(f'{locale}: critical message' in issue for issue in self.check()))

    def test_omitted_failure_negations_are_rejected(self):
        for locale, reversed_copy in [
            ('ta', 'ChatGPT முடிந்த மீள் எழுத்துக்களைத் திரும்பத் தந்தது.'),
            ('te', 'ChatGPT పూర్తి రీవైట్‌ను తిరిగి ఇచ్చింది.'),
        ]:
            with self.subTest(locale=locale):
                self.change(locale, 'ChatGPT returned no completed rewrite.', reversed_copy)
                self.assertTrue(any(f'{locale}: critical message' in issue for issue in self.check()))

    def test_missing_keys_and_placeholders_are_still_rejected(self):
        data = json.loads((self.folder / 'pl.json').read_text())
        del data['Unlock your Keychain to use ChatGPT.']
        data['Hello %@'] = 'Hello'
        self.write('pl', data)
        errors = self.check()
        self.assertTrue(any('pl: 1 missing keys' in issue for issue in errors))
        self.assertTrue(any('pl: placeholder %@ differs' in issue for issue in errors))

    def test_privacy_eligibility_and_recovery_meaning_regressions_are_rejected(self):
        cases = [item for item in self.messages if 'rejected' in item]
        self.assertTrue(cases)
        for item in cases:
            with self.subTest(locale=item['locale'], source=item['source']):
                self.change(item['locale'], item['source'], item['rejected'])
                self.assertTrue(any(
                    f"{item['locale']}: critical message" in issue and repr(item['source']) in issue
                    for issue in self.check()))
                self.change(item['locale'], item['source'], item['expected'])
                self.assertEqual(self.check(), [])
