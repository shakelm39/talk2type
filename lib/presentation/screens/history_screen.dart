import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/tone_modes.dart';
import '../../core/native/native_bridge.dart';
import '../../data/models/transcription_item.dart';
import '../providers/history_provider.dart';

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

  @override
  Widget build(BuildContext context) {
    final historyProv = Provider.of<HistoryProvider>(context);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text("Transcription History"),
        actions: [
          if (historyProv.items.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_sweep_rounded, color: AppColors.error),
              tooltip: "Clear All History",
              onPressed: _confirmClearAll,
            ),
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
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
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
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  textStyle: const TextStyle(fontSize: 12),
                ),
              ),
              const SizedBox(width: 8),

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
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  textStyle: const TextStyle(fontSize: 12),
                ),
              ),
              const SizedBox(width: 8),

              // Delete Button
              IconButton(
                icon: const Icon(Icons.delete_outline_rounded, size: 20, color: AppColors.textMuted),
                tooltip: "Delete",
                onPressed: () {
                  if (item.id != null) {
                    provider.deleteItem(item.id!);
                  }
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}
