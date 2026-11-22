import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../core/config/app_config.dart';
import '../../core/config/plan_limits.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/tone_modes.dart';
import '../../core/native/native_bridge.dart';
import '../../core/services/app_update_service.dart';
import '../providers/permission_provider.dart';
import '../providers/voiceflow_provider.dart';
import 'api_key_setup_screen.dart';
import 'history_screen.dart';
import 'permission_dashboard_screen.dart';
import 'test_ai_dialog.dart';
import 'upgrade_screen.dart';
import 'voice_note_transcribe_screen.dart';
import 'voice_snippets_screen.dart';

class HomeControlScreen extends StatefulWidget {
  const HomeControlScreen({super.key});

  @override
  State<HomeControlScreen> createState() => _HomeControlScreenState();
}

class _HomeControlScreenState extends State<HomeControlScreen> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    NativeBridge.registerRouteCallback((route) {
      if (route == 'upgrade' && mounted) {
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const UpgradeScreen()),
        );
      }
    });

    NativeBridge.registerAudioSharedCallback((audioPath) {
      if (mounted) {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => VoiceNoteTranscribeScreen(audioPath: audioPath),
          ),
        );
      }
    });

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      Provider.of<VoiceFlowProvider>(context, listen: false).checkServiceStatus();
      Provider.of<PermissionProvider>(context, listen: false).checkAllPermissions();
      await AppConfig.getDailyUsageCount();
      if (mounted) setState(() {});
      _checkForAppUpdate();

      // Check cold-start shared audio
      final initialSharedAudio = await NativeBridge.getInitialSharedAudio();
      if (initialSharedAudio != null && mounted) {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => VoiceNoteTranscribeScreen(audioPath: initialSharedAudio),
          ),
        );
      }
    });
  }

  Future<void> _checkForAppUpdate() async {
    await Future.delayed(const Duration(milliseconds: 1200));
    if (!mounted) return;
    // Quiet automatic check on launch (only prompts if update exists)
    await AppUpdateService.instance.checkForUpdate(
      context: context,
      isManual: false,
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      final vfProv = Provider.of<VoiceFlowProvider>(context, listen: false);
      vfProv.checkServiceStatus();
      vfProv.refreshActiveMode();
      Provider.of<PermissionProvider>(context, listen: false).checkAllPermissions();
      AppConfig.getDailyUsageCount().then((_) {
        if (mounted) setState(() {});
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final vfProv = Provider.of<VoiceFlowProvider>(context);
    final permProv = Provider.of<PermissionProvider>(context);
    final activeModeInfo = ToneModes.getByKey(vfProv.activeMode);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: vfProv.isServiceRunning ? AppColors.success : AppColors.textMuted,
                boxShadow: [
                  if (vfProv.isServiceRunning)
                    BoxShadow(
                      color: AppColors.success.withValues(alpha: 0.6),
                      blurRadius: 8,
                      spreadRadius: 2,
                    ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Text(
              "Talk2Type",
              style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 0.5),
            ),
            const SizedBox(width: 8),
            InkWell(
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const UpgradeScreen()),
                );
              },
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  gradient: AppConfig.isPro
                      ? const LinearGradient(colors: [Color(0xFFE11D48), Color(0xFF9333EA)])
                      : null,
                  color: AppConfig.isPro ? null : const Color(0xFF334155),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  AppConfig.isPro ? "PRO" : "FREE (${AppConfig.dailyCount}/${PlanLimits.freeDailyLimit})",
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    letterSpacing: 0.8,
                  ),
                ),
              ),
            ),
          ],
        ),
        actions: [
          // Permissions status badge button
          IconButton(
            icon: Icon(
              permProv.allGranted ? Icons.verified_user_rounded : Icons.warning_amber_rounded,
              color: permProv.allGranted ? AppColors.success : AppColors.warning,
            ),
            tooltip: "Permissions",
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const PermissionDashboardScreen()),
              );
            },
          ),
          // History button
          IconButton(
            icon: const Icon(Icons.history_rounded),
            tooltip: "History",
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const HistoryScreen()),
              );
            },
          ),
          // Settings & Testing dialog
          IconButton(
            icon: const Icon(Icons.tune_rounded),
            tooltip: "AI Config & Settings",
            onPressed: () {
              showDialog(
                context: context,
                builder: (_) => const TestAiDialog(),
              );
            },
          ),
          // Manual update check button
          IconButton(
            icon: const Icon(Icons.system_update_rounded),
            tooltip: "আপডেট চেক করুন",
            onPressed: () {
              AppUpdateService.instance.checkForUpdate(
                context: context,
                isManual: true,
              );
            },
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 1. Clean, Modern Enable / Disable Floating Mic Toggle Card
              _buildFloatingMicToggleCard(vfProv, permProv),

              const SizedBox(height: 12),

              // AI Key Status Chip (Opens Key Setup Wizard)
              _buildAiKeyStatusChip(),

              const SizedBox(height: 14),

              // 2. Permission Status Checklist
              _buildPermissionsStatusSection(permProv),

              const SizedBox(height: 22),

              // 3. Compact 4-Mode Selector Section
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    "টাইপিং মোড নির্বাচন করুন",
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: activeModeInfo.accentColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: activeModeInfo.accentColor.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Text(
                      activeModeInfo.bengaliTitle,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: activeModeInfo.accentColor,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              const Text(
                "ভাসমান মাইকে চাপ দিয়ে কথা বললে নিচের নির্বাচিত মোডে স্বয়ংক্রিয় টাইপ হবে।",
                style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
              ),

              const SizedBox(height: 12),

              // 4 Compact Mode Cards (সুন্দর করে, ফরমাল, হুবহু, English)
              ...ToneModes.allModes.map((mode) => _buildModeCard(mode, vfProv)),

              const SizedBox(height: 16),

              // 4. Last Transcribed Output Preview (if available)
              if (vfProv.lastTranscribedText != null) ...[
                _buildLastTranscriptionCard(vfProv),
                const SizedBox(height: 16),
              ],

              // 5. Quick Action Navigation Buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        showDialog(
                          context: context,
                          builder: (_) => const TestAiDialog(),
                        );
                      },
                      icon: const Icon(Icons.tune_rounded, size: 18),
                      label: const Text("এআই সেটিংস"),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const HistoryScreen()),
                        );
                      },
                      icon: const Icon(Icons.history_rounded, size: 18),
                      label: const Text("হিস্ট্রি দেখুন"),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.surfaceLight,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const VoiceSnippetsScreen()),
                  );
                },
                icon: const Icon(Icons.bolt_rounded, color: Color(0xFFF59E0B), size: 20),
                label: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text("ভয়েস শর্টকাট (Snippets)"),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFFE11D48), Color(0xFF9333EA)],
                        ),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text(
                        "Pro",
                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                    ),
                  ],
                ),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  side: const BorderSide(color: AppColors.surfaceLight),
                ),
              ),

              const SizedBox(height: 18),

              // 6. Voice Commands Help Card (Pro)
              _buildVoiceCommandsHelpCard(),

              const SizedBox(height: 18),

              // 7. Manual Update & Version Card
              _buildAppUpdateCard(),

              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  /// Small status chip showing AI key readiness and linking to key setup wizard
  Widget _buildAiKeyStatusChip() {
    final hasKey = AppConfig.hasAnyAiKey;
    return Align(
      alignment: Alignment.centerLeft,
      child: InkWell(
        onTap: () async {
          await Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const ApiKeySetupScreen()),
          );
          if (mounted) setState(() {});
        },
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: hasKey
                ? AppColors.success.withValues(alpha: 0.12)
                : AppColors.warning.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: hasKey
                  ? AppColors.success.withValues(alpha: 0.35)
                  : AppColors.warning.withValues(alpha: 0.4),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                hasKey ? Icons.check_circle_rounded : Icons.vpn_key_rounded,
                size: 14,
                color: hasKey ? AppColors.success : AppColors.warning,
              ),
              const SizedBox(width: 6),
              Text(
                hasKey ? "AI: সক্রিয় (নিজস্ব key)" : "AI: key নেই (সেট করুন)",
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: hasKey ? AppColors.success : AppColors.warning,
                ),
              ),
              const SizedBox(width: 4),
              Icon(
                Icons.arrow_forward_ios_rounded,
                size: 10,
                color: hasKey ? AppColors.success : AppColors.warning,
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Clean modern card controlling the 48dp floating mic overlay.
  Widget _buildFloatingMicToggleCard(VoiceFlowProvider vfProv, PermissionProvider permProv) {
    final isRunning = vfProv.isServiceRunning;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isRunning ? AppColors.primaryLight : const Color(0xFF334155),
          width: 1.4,
        ),
        boxShadow: [
          if (isRunning)
            BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.22),
              blurRadius: 20,
              offset: const Offset(0, 6),
            ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: isRunning
                      ? AppColors.primaryGradient
                      : const LinearGradient(
                          colors: [Color(0xFF334155), Color(0xFF1E293B)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                  boxShadow: [
                    if (isRunning)
                      BoxShadow(
                        color: AppColors.primary.withValues(alpha: 0.4),
                        blurRadius: 14,
                      ),
                  ],
                ),
                child: Center(
                  child: Icon(
                    isRunning ? Icons.mic_rounded : Icons.mic_off_rounded,
                    color: isRunning ? Colors.white : AppColors.textMuted,
                    size: 26,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isRunning ? "ভাসমান মাইক সক্রিয় আছে" : "ভাসমান মাইক বন্ধ আছে",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: isRunning ? Colors.white : AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      isRunning
                          ? "স্ক্রিনে ৪৮dp ছোট বোতাম দৃশ্যমান"
                          : "অন্যান্য অ্যাপের উপর মাইক চালু করুন",
                      style: TextStyle(
                        fontSize: 12,
                        color: isRunning ? AppColors.success : AppColors.textMuted,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              Switch(
                value: isRunning,
                activeTrackColor: AppColors.primary,
                activeThumbColor: Colors.white,
                onChanged: (val) async {
                  if (!permProv.overlayGranted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text("ভাসমান বোতাম চালু করতে Overlay পারমিশন প্রয়োজন।"),
                        backgroundColor: AppColors.warning,
                      ),
                    );
                    await permProv.requestOverlay();
                    return;
                  }
                  await vfProv.toggleFloatingService();
                },
              ),
            ],
          ),

          const SizedBox(height: 14),

          // Informative helper tip
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.background.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline_rounded, size: 16, color: AppColors.textMuted),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    isRunning
                        ? "হোয়াটসঅ্যাপ, মেসেঞ্জার বা ব্রাউজারে যেয়ে ভাসমান মাইকে চাপ দিয়ে কথা বলুন।"
                        : "সুইচটি অন করলে স্ক্রিনের প্রান্তে একটি ছোট আধা-স্বচ্ছ মাইক ভাসমান থাকবে।",
                    style: const TextStyle(fontSize: 11.5, color: AppColors.textSecondary, height: 1.3),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // Active AI Engine Indicator
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(
                    vfProv.lastUsedEngine.contains("Auto-Switched")
                        ? Icons.sync_problem_rounded
                        : Icons.electric_bolt_rounded,
                    size: 14,
                    color: vfProv.lastUsedEngine.contains("Auto-Switched")
                        ? AppColors.warning
                        : AppColors.primaryLight,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    "AI ইঞ্জিন: ${vfProv.lastUsedEngine}",
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: vfProv.lastUsedEngine.contains("Auto-Switched")
                          ? AppColors.warning
                          : AppColors.primaryLight,
                    ),
                  ),
                ],
              ),
              if (isRunning)
                InkWell(
                  onTap: () async => await vfProv.toggleFloatingService(),
                  child: const Text(
                    "বন্ধ করুন",
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.error,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  /// Compact Permissions Status Checklist
  Widget _buildPermissionsStatusSection(PermissionProvider permProv) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: permProv.allGranted
              ? AppColors.success.withValues(alpha: 0.3)
              : AppColors.warning.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(
                    permProv.allGranted ? Icons.check_circle_rounded : Icons.pending_actions_rounded,
                    size: 16,
                    color: permProv.allGranted ? AppColors.success : AppColors.warning,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    permProv.allGranted ? "সব পারমিশন সক্রিয় আছে (Ready)" : "প্রয়োজনীয় পারমিশন স্ট্যাটাস",
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: permProv.allGranted ? AppColors.success : AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
              InkWell(
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const PermissionDashboardScreen()),
                  );
                },
                child: const Text(
                  "ম্যানেজ করুন >",
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primaryLight,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // 4 Item Checklist
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              _buildPermChip(
                label: "Overlay",
                granted: permProv.overlayGranted,
                onTap: () => permProv.requestOverlay(),
              ),
              _buildPermChip(
                label: "AutoType Accessibility",
                granted: permProv.accessibilityGranted,
                onTap: () => permProv.requestAccessibility(),
              ),
              _buildPermChip(
                label: "Microphone",
                granted: permProv.microphoneGranted,
                onTap: () => permProv.requestMicrophone(),
              ),
              _buildPermChip(
                label: "Battery Saver",
                granted: permProv.batteryOptimizationIgnored,
                onTap: () => permProv.requestBatteryOptimization(),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPermChip({required String label, required bool granted, required VoidCallback onTap}) {
    return InkWell(
      onTap: granted ? null : onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
        decoration: BoxDecoration(
          color: granted
              ? AppColors.success.withValues(alpha: 0.12)
              : AppColors.warning.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: granted
                ? AppColors.success.withValues(alpha: 0.35)
                : AppColors.warning.withValues(alpha: 0.4),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              granted ? Icons.check_circle_rounded : Icons.add_circle_outline_rounded,
              size: 13,
              color: granted ? AppColors.success : AppColors.warning,
            ),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: granted ? AppColors.success : AppColors.warning,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModeCard(ToneModeInfo mode, VoiceFlowProvider vfProv) {
    final isSelected = vfProv.activeMode == mode.key;
    final isLocked = !AppConfig.isPro && mode.key != ToneModes.bangla;

    return GestureDetector(
      onTap: () {
        if (isLocked) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("এটি Pro ফিচার — আনলক করতে Pro নিন"),
              backgroundColor: AppColors.primary,
              duration: Duration(seconds: 2),
            ),
          );
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const UpgradeScreen()),
          );
          return;
        }
        vfProv.setToneMode(mode.key);
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? mode.accentColor.withValues(alpha: 0.12) : AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? mode.accentColor : const Color(0xFF334155),
            width: isSelected ? 1.6 : 1.0,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: mode.accentColor.withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              child: Icon(mode.icon, color: mode.accentColor, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        mode.bengaliTitle,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: isSelected ? Colors.white : AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        "(${mode.title})",
                        style: TextStyle(
                          fontSize: 11,
                          color: isSelected ? mode.accentColor : AppColors.textMuted,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      if (isLocked) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.amber.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: Colors.amber.withValues(alpha: 0.5)),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.lock_rounded, size: 10, color: Colors.amber),
                              SizedBox(width: 2),
                              Text("Pro", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.amber)),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    mode.description,
                    style: const TextStyle(
                      fontSize: 11.5,
                      color: AppColors.textSecondary,
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected ? mode.accentColor : AppColors.textMuted,
                  width: 1.8,
                ),
                color: isSelected ? mode.accentColor : Colors.transparent,
              ),
              child: isSelected
                  ? const Center(child: Icon(Icons.check, size: 14, color: Colors.white))
                  : (isLocked ? const Center(child: Icon(Icons.lock_outline_rounded, size: 12, color: AppColors.textMuted)) : null),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLastTranscriptionCard(VoiceFlowProvider vfProv) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.primaryLight.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(Icons.check_circle_rounded, color: AppColors.success, size: 16),
                  SizedBox(width: 6),
                  Text(
                    "সর্বশেষ টাইপকৃত টেক্সট",
                    style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                  ),
                ],
              ),
              IconButton(
                icon: const Icon(Icons.copy_rounded, size: 16, color: AppColors.textSecondary),
                tooltip: "Copy Text",
                onPressed: () {
                  if (vfProv.lastTranscribedText != null) {
                    Clipboard.setData(ClipboardData(text: vfProv.lastTranscribedText!));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("ক্লিপবোর্ডে কপি হয়েছে")),
                    );
                  }
                },
              ),
            ],
          ),
          const SizedBox(height: 6),
          SelectableText(
            vfProv.lastTranscribedText!,
            style: const TextStyle(fontSize: 13.5, color: AppColors.textPrimary, height: 1.4),
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: OutlinedButton.icon(
              onPressed: () async {
                final success = await NativeBridge.injectText(vfProv.lastTranscribedText!);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(success ? "সরাসরি ইনজেক্ট হয়েছে!" : "ক্লিপবোর্ডে কপি হয়েছে"),
                      backgroundColor: success ? AppColors.success : AppColors.info,
                    ),
                  );
                }
              },
              icon: const Icon(Icons.keyboard_return_rounded, size: 14),
              label: const Text("পুনরায় টাইপ করুন (Auto-Type)"),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                textStyle: const TextStyle(fontSize: 11),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAppUpdateCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF334155), width: 1.2),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.system_update_rounded,
              color: AppColors.primaryLight,
              size: 24,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "সফ্টওয়্যার আপডেট",
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                FutureBuilder<String>(
                  future: AppUpdateService.instance.getCurrentAppVersion(),
                  builder: (context, snapshot) {
                    final ver = snapshot.data ?? "1.0.1";
                    return Text(
                      "ভার্সন: v$ver • নতুন আপডেট চেক করুন",
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
          ElevatedButton.icon(
            onPressed: () {
              AppUpdateService.instance.checkForUpdate(
                context: context,
                isManual: true,
              );
            },
            icon: const Icon(Icons.sync_rounded, size: 15),
            label: const Text("চেক করুন"),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Help card listing all Pro voice commands
  Widget _buildVoiceCommandsHelpCard() {
    final commands = [
      ("নতুন লাইন / new line", "নতুন প্যারা (\\n) তৈরি করবে"),
      ("দাঁড়ি / ফুলস্টপ", "দাঁড়ি (।) চিহ্ন বসাবে"),
      ("কমা / comma", "কমা (,) চিহ্ন বসাবে"),
      ("প্রশ্নবোধক", "প্রশ্নবোধক (?) চিহ্ন বসাবে"),
      ("শেষ বাক্য মুছো", "টাইপ করা শেষ বাক্য মুছে ফেলবে"),
      ("সব মুছো", "মাইকে ৩ সেকেন্ডে ✓ চেপে সম্পূর্ণ লেখা মুছুন"),
    ];

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.surfaceLight),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: false,
          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          leading: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFF6366F1).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.record_voice_over_rounded,
              color: Color(0xFF818CF8),
              size: 20,
            ),
          ),
          title: Row(
            children: [
              const Text(
                "ভয়েস কমান্ড ডিকশনারি",
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFE11D48), Color(0xFF9333EA)],
                  ),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text(
                  "Pro",
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          subtitle: const Text(
            "কথা বলার সময় মুখে বললে স্বয়ংক্রিয় অ্যাকশন",
            style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
          ),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                children: commands.map((cmd) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceLight,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppColors.surfaceLight.withValues(alpha: 0.5)),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: const Color(0xFF3B82F6).withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: const Color(0xFF3B82F6).withValues(alpha: 0.4)),
                            ),
                            child: Text(
                              cmd.$1,
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF60A5FA),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              cmd.$2,
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
