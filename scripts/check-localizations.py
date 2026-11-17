import json
import pathlib

ROOT = pathlib.Path(__file__).resolve().parent.parent
EXPECTED_LOCALES = set('en es fr de pt it nl pl uk tr ar fa ur hi bn ta te mr id vi th zh ja ko'.split())


def validate_catalogs(source, critical_messages):
    english = json.loads((source / 'en.json').read_text())
    issues = []
    if {p.stem for p in source.glob('*.json')} != EXPECTED_LOCALES:
        issues.append('Language catalogs do not match the 24 supported locales')
    catalogs = {}
    for file in sorted(source.glob('*.json')):
        data = json.loads(file.read_text())
        catalogs[file.stem] = data
        missing = set(english) - set(data)
        if missing:
            issues.append(f'{file.stem}: {len(missing)} missing keys')
        for key, value in data.items():
            if not isinstance(value, str) or not value.strip():
                issues.append(f'{file.stem}: empty or invalid {key!r}')
                continue
            for placeholder in ['%d', '%@']:
                if key.count(placeholder) != value.count(placeholder):
                    issues.append(f'{file.stem}: placeholder {placeholder} differs: {key!r}')

    # Exact curated copy protects known meaning reversals from regeneration.
    # It does not infer the quality or semantics of arbitrary translations.
    fixtures = json.loads(critical_messages.read_text())['messages']
    for item in fixtures:
        locale, source_key, expected = item['locale'], item['source'], item['expected']
        if locale not in EXPECTED_LOCALES or source_key not in english or not expected.strip():
            issues.append(f'Invalid critical-message fixture: {locale}: {source_key!r}')
        elif catalogs.get(locale, {}).get(source_key) != expected:
            issues.append(f'{locale}: critical message differs from curated copy: {source_key!r}')
    return issues


if __name__ == '__main__':
    errors = validate_catalogs(ROOT / 'Localization', ROOT / 'scripts/fixtures/critical-localizations.json')
    print('\n'.join(errors) if errors else 'All interface catalogs complete; placeholders and critical-message fixtures preserved.')
    raise SystemExit(bool(errors))
