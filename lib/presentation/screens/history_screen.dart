import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import '../../core/config/app_config.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/tone_modes.dart';
import '../../core/native/native_bridge.dart';
import '../../data/models/transcription_item.dart';
import '../providers/history_provider.dart';
import 'upgrade_screen.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<HistoryProvider>(context, listen: false).loadHistory();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _confirmClearAll() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text("সব হিস্ট্রি মুছবেন?"),
        content: const Text("আপনি কি নিশ্চিত যে সকল অতীতের ভয়েস ট্রান্সক্রিপশন মুছে ফেলতে চান?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text("বাতিল", style: TextStyle(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () {
              Navigator.of(ctx).pop();
              Provider.of<HistoryProvider>(context, listen: false).clearAll();
            },
            child: const Text("সব মুছুন"),
          ),
        ],
      ),
    );
  }

  void _showExportDialog(List<TranscriptionItem> items) {
    if (!AppConfig.isPro) {
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
            "হিস্ট্রি এক্সপোর্ট শুধুমাত্র Pro ব্যবহারকারীদের জন্য। সম্পূর্ণ রেকর্ড .txt বা .csv আকারে ডাউনলোড করতে Pro নিন।",
            style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text("বাতিল", style: TextStyle(color: AppColors.textSecondary)),
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
      return;
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Icon(Icons.file_download_outlined, color: AppColors.info),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    "হিস্ট্রি এক্সপোর্ট (${items.length} টি আইটেম)",
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              "ফরম্যাট নির্বাচন করুন (বাংলা অক্ষরের জন্য UTF-8 সাপোর্টেড):",
              style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 18),
            ListTile(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: const BorderSide(color: AppColors.surfaceLight),
              ),
              leading: const Icon(Icons.description_outlined, color: Color(0xFF60A5FA)),
              title: const Text("টেক্সট ফাইল (.txt)", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
              subtitle: const Text("নোটপ্যাড বা মোবাইল টেক্সট রিডারের জন্য", style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
              trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: AppColors.textMuted),
              onTap: () {
                Navigator.of(ctx).pop();
                _exportHistory(items, isCsv: false);
              },
            ),
            const SizedBox(height: 10),
            ListTile(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: const BorderSide(color: AppColors.surfaceLight),
              ),
              leading: const Icon(Icons.table_chart_outlined, color: Color(0xFF34D399)),
              title: const Text("এক্সেল / স্প্রেডশিট (.csv)", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
              subtitle: const Text("Microsoft Excel বা Google Sheets (UTF-8 BOM সহ)", style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
              trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: AppColors.textMuted),
              onTap: () {
                Navigator.of(ctx).pop();
                _exportHistory(items, isCsv: true);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _exportHistory(List<TranscriptionItem> items, {required bool isCsv}) async {
    try {
      final tempDir = await getTemporaryDirectory();
      final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());

      if (isCsv) {
        final filePath = '${tempDir.path}/talk2type_history_$timestamp.csv';
        final file = File(filePath);
        final buffer = StringBuffer();
        // UTF-8 BOM so Microsoft Excel renders Bengali characters correctly
        buffer.write('\uFEFF');
        buffer.writeln('"ID","তারিখ ও সময়","মোড","টেক্সট","ফলাফল"');

        for (final item in items) {
          final id = item.id?.toString() ?? '';
          final time = DateFormat('yyyy-MM-dd HH:mm:ss').format(item.timestamp);
          final mode = item.mode;
          final textEscaped = item.text.replaceAll('"', '""');
          final status = item.isSuccess ? 'সফল' : 'ব্যর্থ';
          buffer.writeln('"$id","$time","$mode","$textEscaped","$status"');
        }

        await file.writeAsString(buffer.toString(), encoding: utf8);
        await NativeBridge.shareFile(filePath, mimeType: 'text/csv');
      } else {
        final filePath = '${tempDir.path}/talk2type_history_$timestamp.txt';
        final file = File(filePath);
        final buffer = StringBuffer();
        buffer.writeln("==================================================");
        buffer.writeln("  Talk2Type ভয়েস ট্রান্সক্রিপশন হিস্ট্রি");
        buffer.writeln("  মোট আইটেম: ${items.length} টি");
        buffer.writeln("  এক্সপোর্ট তারিখ: ${DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now())}");
        buffer.writeln("==================================================\n");

        for (int i = 0; i < items.length; i++) {
          final item = items[i];
          final time = DateFormat('yyyy-MM-dd HH:mm').format(item.timestamp);
          buffer.writeln("[$time] • মোড: ${item.mode}");
          buffer.writeln(item.text);
          buffer.writeln("--------------------------------------------------");
        }

        await file.writeAsString(buffer.toString(), encoding: utf8);
        await NativeBridge.shareFile(filePath, mimeType: 'text/plain');
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("এক্সপোর্ট ফাইল তৈরি হয়েছে")),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("এক্সপোর্ট ব্যর্থ হয়েছে: $e")),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final historyProv = Provider.of<HistoryProvider>(context);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text("হিস্ট্রি ও রেকর্ড"),
        actions: [
          if (historyProv.items.isNotEmpty) ...[
            IconButton(
              icon: const Icon(Icons.file_download_outlined, color: AppColors.info),
              tooltip: "এক্সপোর্ট (Export)",
              onPressed: () => _showExportDialog(historyProv.items),
            ),
            IconButton(
              icon: const Icon(Icons.delete_sweep_rounded, color: AppColors.error),
              tooltip: "সব মুছুন",
              onPressed: _confirmClearAll,
            ),
          ],
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Search Bar
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: TextField(
                controller: _searchController,
                style: const TextStyle(color: Colors.white, fontSize: 14),
                decoration: InputDecoration(
                  hintText: "খুঁজুন (Search transcription or mode)...",
                  prefixIcon: const Icon(Icons.search_rounded, color: AppColors.textSecondary),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, color: AppColors.textMuted),
                          onPressed: () {
                            _searchController.clear();
                            historyProv.search('');
                          },
                        )
                      : null,
                ),
                onChanged: (val) => historyProv.search(val),
              ),
            ),

            // Content List
            Expanded(
              child: historyProv.isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : historyProv.items.isEmpty
                      ? _buildEmptyState()
                      : ListView.separated(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          itemCount: historyProv.items.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 12),
                          itemBuilder: (context, index) {
                            final item = historyProv.items[index];
                            return _buildHistoryCard(item, historyProv);
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.surface,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.history_toggle_off_rounded,
              size: 48,
              color: AppColors.textMuted,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            "কোনো হিস্ট্রি পাওয়া যায়নি",
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
          ),
          const SizedBox(height: 6),
          const Text(
            "ভাসমান Orb বোতাম দিয়ে ভয়েস ইনপুট দিলে এখানে জমা হবে।",
            style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryCard(TranscriptionItem item, HistoryProvider provider) {
    final modeInfo = ToneModes.getByKey(item.mode);
    final formattedDate = DateFormat('dd MMM yyyy, hh:mm a').format(item.timestamp);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: item.isSuccess ? const Color(0xFF334155) : AppColors.error.withValues(alpha: 0.4),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Mode Tag & Date
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: modeInfo.accentColor.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: modeInfo.accentColor.withValues(alpha: 0.4)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(modeInfo.icon, size: 14, color: modeInfo.accentColor),
                    const SizedBox(width: 6),
                    Text(
                      modeInfo.title,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: modeInfo.accentColor,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                formattedDate,
                style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Transcribed Text
          SelectableText(
            item.text,
            style: TextStyle(
              fontSize: 15,
              height: 1.45,
              color: item.isSuccess ? AppColors.textPrimary : AppColors.error,
              fontWeight: FontWeight.w400,
            ),
          ),

          const SizedBox(height: 14),

          // Action Buttons: Copy, Auto-Type Again, Delete
          Align(
            alignment: Alignment.centerRight,
            child: Wrap(
              alignment: WrapAlignment.end,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 8,
              runSpacing: 6,
              children: [
                // Copy Button
                OutlinedButton.icon(
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: item.text));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text("টেক্সট ক্লিপবোর্ডে কপি হয়েছে"),
                        duration: Duration(seconds: 2),
                      ),
                    );
                  },
                  icon: const Icon(Icons.copy_rounded, size: 15),
                  label: const Text("কপি"),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    textStyle: const TextStyle(fontSize: 12),
                  ),
                ),

                // Auto-Type Button
                ElevatedButton.icon(
                  onPressed: () async {
                    final typed = await NativeBridge.injectText(item.text);
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(typed ? "সরাসরি ইনজেক্ট করা হয়েছে!" : "ক্লিপবোর্ডে কপি করা হয়েছে।"),
                          backgroundColor: typed ? AppColors.success : AppColors.info,
                        ),
                      );
                    }
                  },
                  icon: const Icon(Icons.keyboard_return_rounded, size: 15),
                  label: const Text("Auto-Type"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    textStyle: const TextStyle(fontSize: 12),
                  ),
                ),

                // Delete Button
                IconButton(
                  icon: const Icon(Icons.delete_outline_rounded, size: 20, color: AppColors.textMuted),
                  tooltip: "Delete",
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                  onPressed: () {
                    if (item.id != null) {
                      provider.deleteItem(item.id!);
                    }
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
