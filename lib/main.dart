import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'core/config/app_config.dart';
import 'core/native/native_bridge.dart';
import 'core/theme/app_theme.dart';
import 'presentation/providers/history_provider.dart';
import 'presentation/providers/license_provider.dart';
import 'presentation/providers/permission_provider.dart';
import 'presentation/providers/voiceflow_provider.dart';
import 'presentation/screens/splash_gate_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Set system UI overlay style
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: Color(0xFF0F172A),
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );

  // Load saved configurations and keys
  await AppConfig.loadConfig();

  // Initialize Native bridge
  NativeBridge.initialize();

  runApp(const Talk2TypeApp());
}

class Talk2TypeApp extends StatelessWidget {
  const Talk2TypeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => LicenseProvider()),
        ChangeNotifierProvider(create: (_) => PermissionProvider()),
        ChangeNotifierProvider(create: (_) => HistoryProvider()),
        ChangeNotifierProvider(create: (_) => VoiceFlowProvider()),
      ],
      child: MaterialApp(
        title: 'Talk2Type',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.darkTheme,
        home: const SplashGateScreen(),
      ),
    );
  }
}
