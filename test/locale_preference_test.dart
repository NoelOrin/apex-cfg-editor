import 'package:apex_cfg_editor/ui/locale_preference.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('appLocalePreferenceFromRaw', () {
    test('maps persisted values to locale preferences', () {
      expect(appLocalePreferenceFromRaw('system'), AppLocalePreference.system);
      expect(appLocalePreferenceFromRaw('zh'), AppLocalePreference.zh);
      expect(appLocalePreferenceFromRaw('en'), AppLocalePreference.en);
    });

    test('invalid or missing values fall back to system', () {
      expect(appLocalePreferenceFromRaw(null), AppLocalePreference.system);
      expect(appLocalePreferenceFromRaw(''), AppLocalePreference.system);
      expect(appLocalePreferenceFromRaw('fr'), AppLocalePreference.system);
    });
  });

  group('AppLocalePreference mappings', () {
    test('system has no explicit locale and fixed values map to Locale', () {
      expect(AppLocalePreference.system.locale, isNull);
      expect(AppLocalePreference.zh.locale, const Locale('zh'));
      expect(AppLocalePreference.en.locale, const Locale('en'));
    });

    test('raw values are stable for settings.json', () {
      expect(AppLocalePreference.system.raw, 'system');
      expect(AppLocalePreference.zh.raw, 'zh');
      expect(AppLocalePreference.en.raw, 'en');
    });
  });
}
