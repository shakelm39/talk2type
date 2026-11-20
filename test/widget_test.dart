import 'package:flutter_test/flutter_test.dart';
import 'package:voiceflow_ai/core/config/app_config.dart';
import 'package:voiceflow_ai/core/constants/tone_modes.dart';
import 'package:voiceflow_ai/core/services/license_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('AppConfig default properties', () {
    expect(AppConfig.enableLicenseCheck, false);
    expect(AppConfig.licenseApiEndpoint, isNotEmpty);
    expect(AppConfig.aiProcessEndpoint, isNotEmpty);
  });

  test('ToneModes 4-mode configuration check', () {
    expect(ToneModes.allModes.length, 4);
    expect(ToneModes.getByKey(ToneModes.sundor).key, ToneModes.sundor);
    expect(ToneModes.getByKey(ToneModes.formal).key, ToneModes.formal);
    expect(ToneModes.getByKey(ToneModes.hubohu).key, ToneModes.hubohu);
    expect(ToneModes.getByKey(ToneModes.english).key, ToneModes.english);

    // Backward compatibility checks
    expect(ToneModes.getByKey("clean_bangla").key, ToneModes.sundor);
    expect(ToneModes.getByKey("office_formal").key, ToneModes.formal);
    expect(ToneModes.getByKey("bangla_to_english").key, ToneModes.english);
  });

  test('LicenseService check with enableLicenseCheck=false bypass', () async {
    AppConfig.enableLicenseCheck = false;
    final isValid = await LicenseService.instance.isLicenseValid();
    expect(isValid, true);
  });
}
