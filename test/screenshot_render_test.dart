import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:voiceflow_ai/core/config/app_config.dart';
import 'package:voiceflow_ai/core/constants/app_colors.dart';
import 'package:voiceflow_ai/presentation/providers/permission_provider.dart';
import 'package:voiceflow_ai/presentation/screens/permission_dashboard_screen.dart';

class MockPermissionProvider extends ChangeNotifier implements PermissionProvider {
  @override
  bool get microphoneGranted => true;
  @override
  bool get keyboardEnabled => true;
  @override
  bool get keyboardSelected => true;
  @override
  bool get keyboardReady => true;
  @override
  bool get overlayGranted => false;
  @override
  bool get batteryOptimizationIgnored => true;
  @override
  bool get isLoading => false;
  @override
  bool get allGranted => true;
  @override
  bool get isFullyReady => true;
  @override
  bool get accessibilityGranted => true;

  @override
  Future<void> checkAllPermissions() async {}
  @override
  Future<void> requestMicrophone() async {}
  @override
  Future<void> enableKeyboard() async {}
  @override
  Future<void> selectKeyboard() async {}
  @override
  Future<void> requestOverlay() async {}
  @override
  Future<void> requestBatteryOptimization() async {}
  @override
  Future<void> openAppSettingsFallback() async {}
  @override
  Future<void> requestAccessibility() async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Generate pristine setup checklist screenshot', (tester) async {
    SharedPreferences.setMockInitialValues({
      AppConfig.keyIsPro: true,
      AppConfig.keyFloatingMicEnabled: false,
    });

    final GlobalKey repaintKey = GlobalKey();

    tester.view.physicalSize = const Size(720, 1570);
    tester.view.devicePixelRatio = 2.0;

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<PermissionProvider>(
            create: (_) => MockPermissionProvider(),
          ),
        ],
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: ThemeData.dark().copyWith(
            scaffoldBackgroundColor: AppColors.background,
          ),
          home: RepaintBoundary(
            key: repaintKey,
            child: const PermissionDashboardScreen(),
          ),
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    final boundary = repaintKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
    final image = await tester.runAsync(() => boundary.toImage(pixelRatio: 2.0));
    final byteData = await tester.runAsync(() => image!.toByteData(format: ui.ImageByteFormat.png));
    final bytes = byteData!.buffer.asUint8List();

    final file = File('docs/antigravity/review/screens/02_setup_checklist.png');
    file.writeAsBytesSync(bytes);
    expect(file.existsSync(), isTrue);
  });

  testWidgets('Generate disclosure dialog screenshot', (tester) async {
    final GlobalKey repaintKey = GlobalKey();

    tester.view.physicalSize = const Size(720, 1570);
    tester.view.devicePixelRatio = 2.0;

    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: ThemeData.dark().copyWith(
          scaffoldBackgroundColor: AppColors.background,
        ),
        home: RepaintBoundary(
          key: repaintKey,
          child: Scaffold(
            backgroundColor: AppColors.background,
            body: Center(
              child: AlertDialog(
                backgroundColor: AppColors.surface,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                title: Row(
                  children: const [
                    Icon(Icons.keyboard_rounded, color: AppColors.primaryLight, size: 24),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        "Talk2Type কিবোর্ড চালু করুন",
                        style: TextStyle(fontSize: 16.5, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                    ),
                  ],
                ),
                content: const Text(
                  "Android সব কিবোর্ড চালুর সময় সতর্ক করে যে কিবোর্ড 'সব লেখা সংগ্রহ করতে পারে'।\n\n"
                  "Talk2Type শুধু আপনার বলা কথা লেখায় রূপান্তর করে। পাসওয়ার্ডের ঘরে ভয়েস টাইপিং স্বয়ংক্রিয়ভাবে বন্ধ থাকে এবং কোনো সাধারণ টাইপ করা লেখা সংরক্ষণ বা লগ করা হয় না।",
                  style: TextStyle(fontSize: 13.5, color: Colors.white70, height: 1.45),
                ),
                actions: [
                  TextButton(
                    onPressed: () {},
                    child: const Text("পরে", style: TextStyle(color: Colors.white60)),
                  ),
                  ElevatedButton(
                    onPressed: () {},
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    child: const Text("কিবোর্ড চালু করুন", style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    final boundary = repaintKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
    final image = await tester.runAsync(() => boundary.toImage(pixelRatio: 2.0));
    final byteData = await tester.runAsync(() => image!.toByteData(format: ui.ImageByteFormat.png));
    final bytes = byteData!.buffer.asUint8List();

    final file = File('docs/antigravity/review/screens/05_permission_disclosure_dialog.png');
    file.writeAsBytesSync(bytes);
    expect(file.existsSync(), isTrue);
  });
}
