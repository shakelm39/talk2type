import 'package:flutter/material.dart';
import '../../core/config/app_config.dart';
import '../../core/constants/app_colors.dart';
import '../../core/services/snippet_service.dart';
import '../../data/models/voice_snippet.dart';
import 'upgrade_screen.dart';

class VoiceSnippetsScreen extends StatefulWidget {
  const VoiceSnippetsScreen({super.key});

  @override
  State<VoiceSnippetsScreen> createState() => _VoiceSnippetsScreenState();
}

class _VoiceSnippetsScreenState extends State<VoiceSnippetsScreen> {
  final _searchController = TextEditingController();
  String _filter = '';

  @override
  void initState() {
    super.initState();
    SnippetService.instance.init().then((_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<VoiceSnippet> get _filteredSnippets {
    final all = SnippetService.instance.snippets;
    if (_filter.trim().isEmpty) return all;
    final f = _filter.trim().toLowerCase();
    return all.where((s) =>
        s.trigger.toLowerCase().contains(f) ||
        s.expansion.toLowerCase().contains(f)).toList();
  }

  void _showAddEditDialog([VoiceSnippet? existing]) {
    if (!AppConfig.isPro) {
      _showUpgradePrompt();
      return;
    }

    final triggerCtrl = TextEditingController(text: existing?.trigger ?? '');
    final expansionCtrl = TextEditingController(text: existing?.expansion ?? '');
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          existing == null ? "নতুন ভয়েস শর্টকাট" : "শর্টকাট সম্পাদনা",
          style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.textPrimary),
        ),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: triggerCtrl,
                style: const TextStyle(color: AppColors.textPrimary),
                decoration: InputDecoration(
                  labelText: "ট্রিগার বাক্য (মুখে যা বলবেন)",
                  labelStyle: const TextStyle(color: AppColors.textSecondary),
                  hintText: "যেমন: আমার ঠিকানা",
                  hintStyle: const TextStyle(color: AppColors.textMuted),
                  filled: true,
                  fillColor: AppColors.surfaceLight,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
                validator: (val) => val == null || val.trim().isEmpty ? "ট্রিগার বাক্য লিখুন" : null,
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: expansionCtrl,
                maxLines: 3,
                style: const TextStyle(color: AppColors.textPrimary),
                decoration: InputDecoration(
                  labelText: "যা টাইপ হবে (পূর্ণ লেখা)",
                  labelStyle: const TextStyle(color: AppColors.textSecondary),
                  hintText: "যেমন: বাসা ১২, রোড ৫, ধানমন্ডি, ঢাকা।",
                  hintStyle: const TextStyle(color: AppColors.textMuted),
                  filled: true,
                  fillColor: AppColors.surfaceLight,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
                validator: (val) => val == null || val.trim().isEmpty ? "পূর্ণ লেখা লিখুন" : null,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text("বাতিল", style: TextStyle(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () async {
              if (formKey.currentState?.validate() ?? false) {
                Navigator.of(ctx).pop();
                if (existing == null) {
                  await SnippetService.instance.addSnippet(
                    triggerCtrl.text,
                    expansionCtrl.text,
                  );
                } else {
                  await SnippetService.instance.updateSnippet(
                    existing.id,
                    triggerCtrl.text,
                    expansionCtrl.text,
                  );
                }
                if (mounted) setState(() {});
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
            child: const Text("সংরক্ষণ করুন", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showUpgradePrompt() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.lock_rounded, color: Color(0xFFE11D48)),
            SizedBox(width: 8),
            Text("Pro ফিচার", style: TextStyle(color: AppColors.textPrimary)),
          ],
        ),
        content: const Text(
          "ভয়েস শর্টকাট (Snippets) শুধুমাত্র Pro ব্যবহারকারীদের জন্য। কোনো AI খরচ ছাড়াই এক কথায় পুরো প্যারা টাইপ করার সুবিধা পান।",
          style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text("পরে", style: TextStyle(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const UpgradeScreen()),
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFE11D48)),
            child: const Text("Pro আনলক করুন", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isPro = AppConfig.isPro;
    final items = _filteredSnippets;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text("ভয়েস শর্টকাট", style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                gradient: isPro
                    ? const LinearGradient(colors: [Color(0xFFE11D48), Color(0xFF9333EA)])
                    : null,
                color: isPro ? null : const Color(0xFF334155),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                isPro ? "PRO" : "FREE",
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: AppColors.background,
        elevation: 0,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddEditDialog(),
        backgroundColor: AppColors.primary,
        icon: const Icon(Icons.add_rounded, color: Colors.white),
        label: const Text("নতুন শর্টকাট", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
      ),
      body: Column(
        children: [
          if (!isPro)
            Container(
              margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFE11D48).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE11D48).withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.lock_rounded, color: Color(0xFFF43F5E), size: 18),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      "শর্টকাট একটি Pro ফিচার — কথা বলে শর্টকাট টাইপ করতে Pro নিন।",
                      style: TextStyle(fontSize: 12, color: Color(0xFFFDA4AF)),
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const UpgradeScreen()),
                      );
                    },
                    child: const Text("আপগ্রেড", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white)),
                  ),
                ],
              ),
            ),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: TextField(
              controller: _searchController,
              onChanged: (val) => setState(() => _filter = val),
              style: const TextStyle(color: AppColors.textPrimary),
              decoration: InputDecoration(
                hintText: "শর্টকাট খুঁজুন...",
                hintStyle: const TextStyle(color: AppColors.textMuted, fontSize: 14),
                prefixIcon: const Icon(Icons.search_rounded, color: AppColors.textMuted),
                filled: true,
                fillColor: AppColors.surface,
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),

          Expanded(
            child: items.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.bolt_rounded, size: 54, color: AppColors.textMuted.withValues(alpha: 0.4)),
                        const SizedBox(height: 12),
                        const Text(
                          "কোনো শর্টকাট নেই",
                          style: TextStyle(color: AppColors.textSecondary, fontSize: 16),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          "নিচের বোতাম চেপে নতুন শর্টকাট যোগ করুন।",
                          style: TextStyle(color: AppColors.textMuted, fontSize: 13),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 80),
                    itemCount: items.length,
                    itemBuilder: (context, index) {
                      final item = items[index];
                      return Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: AppColors.surfaceLight),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF3B82F6).withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: const Color(0xFF3B82F6).withValues(alpha: 0.3)),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.mic_none_rounded, size: 14, color: Color(0xFF60A5FA)),
                                      const SizedBox(width: 4),
                                      Text(
                                        item.trigger,
                                        style: const TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.bold,
                                          color: Color(0xFF93C5FD),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const Spacer(),
                                IconButton(
                                  icon: const Icon(Icons.edit_outlined, size: 18, color: AppColors.textSecondary),
                                  onPressed: () => _showAddEditDialog(item),
                                  tooltip: "সম্পাদনা",
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete_outline_rounded, size: 18, color: AppColors.error),
                                  onPressed: () async {
                                    await SnippetService.instance.deleteSnippet(item.id);
                                    if (mounted) setState(() {});
                                  },
                                  tooltip: "মুছে ফেলুন",
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Text(
                              item.expansion,
                              style: const TextStyle(
                                fontSize: 14,
                                color: AppColors.textPrimary,
                                height: 1.4,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
