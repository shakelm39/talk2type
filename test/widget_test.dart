import 'package:flutter_test/flutter_test.dart';
import 'package:voiceflow_ai/core/config/app_config.dart';
import 'package:voiceflow_ai/core/constants/tone_modes.dart';
import 'package:voiceflow_ai/core/services/license_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('AppConfig default properties', () {
    expect(AppConfig.enableLicenseCheck, true);
    expect(AppConfig.licenseApiEndpoint, isNotEmpty);
    expect(AppConfig.aiProcessEndpoint, isNotEmpty);
  });

  test('ToneModes 5-mode configuration and normalization check', () {
    expect(ToneModes.allModes.length, 5);
    expect(ToneModes.getByKey(ToneModes.bangla).key, ToneModes.bangla);
    expect(ToneModes.getByKey(ToneModes.formal).key, ToneModes.formal);
    expect(ToneModes.getByKey(ToneModes.support).key, ToneModes.support);
    expect(ToneModes.getByKey(ToneModes.casual).key, ToneModes.casual);
    expect(ToneModes.getByKey(ToneModes.english).key, ToneModes.english);

    // Normalization & backward compatibility checks
    expect(ToneModes.getByKey("clean_bangla").key, ToneModes.bangla);
    expect(ToneModes.getByKey("guchiye").key, ToneModes.bangla);
    expect(ToneModes.getByKey("sundor").key, ToneModes.bangla);
    expect(ToneModes.getByKey("hubohu").key, ToneModes.bangla);
    expect(ToneModes.getByKey("office_formal").key, ToneModes.formal);
    expect(ToneModes.getByKey("customer_support").key, ToneModes.support);
    expect(ToneModes.getByKey("friend_casual").key, ToneModes.casual);
    expect(ToneModes.getByKey("bangla_to_english").key, ToneModes.english);
    expect(ToneModes.getByKey("english_translate").key, ToneModes.english);
    expect(ToneModes.getByKey("unknown_mode").key, ToneModes.bangla);
  });

  test('LicenseService check with enableLicenseCheck=false bypass', () async {
    AppConfig.enableLicenseCheck = false;
    final isValid = await LicenseService.instance.isLicenseValid();
    expect(isValid, true);
  });
}
