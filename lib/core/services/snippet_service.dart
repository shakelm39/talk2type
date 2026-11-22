import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../../data/models/voice_snippet.dart';

class SnippetService {
  SnippetService._();
  static final SnippetService instance = SnippetService._();

  static const String prefKey = 'vf_voice_snippets';

  List<VoiceSnippet> _cachedSnippets = [];
  List<VoiceSnippet> get snippets => List.unmodifiable(_cachedSnippets);

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = prefs.getString(prefKey);
    if (jsonStr != null && jsonStr.isNotEmpty) {
      try {
        final List list = jsonDecode(jsonStr);
        _cachedSnippets = list.map((item) => VoiceSnippet.fromMap(item)).toList();
      } catch (_) {
        _cachedSnippets = _defaultSnippets();
        await _save();
      }
    } else {
      _cachedSnippets = _defaultSnippets();
      await _save();
    }
  }

  List<VoiceSnippet> _defaultSnippets() {
    return [
      VoiceSnippet(
        id: '1',
        trigger: 'আমার ঠিকানা',
        expansion: 'বাসা ১২, রোড ৫, ধানমন্ডি, ঢাকা।',
      ),
      VoiceSnippet(
        id: '2',
        trigger: 'ডেলিভারি চার্জ',
        expansion: 'ঢাকার ভিতরে ডেলিভারি চার্জ ৮০ টাকা, ঢাকার বাইরে ১৩০ টাকা।',
      ),
      VoiceSnippet(
        id: '3',
        trigger: 'ধন্যবাদ',
        expansion: 'আমাদের সাথে থাকার জন্য আপনাকে অনেক ধন্যবাদ!',
      ),
    ];
  }

  Future<void> addSnippet(String trigger, String expansion) async {
    final newSnippet = VoiceSnippet(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      trigger: trigger.trim(),
      expansion: expansion.trim(),
    );
    _cachedSnippets.insert(0, newSnippet);
    await _save();
  }

  Future<void> updateSnippet(String id, String trigger, String expansion) async {
    final index = _cachedSnippets.indexWhere((s) => s.id == id);
    if (index != -1) {
      _cachedSnippets[index] = VoiceSnippet(
        id: id,
        trigger: trigger.trim(),
        expansion: expansion.trim(),
        createdAt: _cachedSnippets[index].createdAt,
      );
      await _save();
    }
  }

  Future<void> deleteSnippet(String id) async {
    _cachedSnippets.removeWhere((s) => s.id == id);
    await _save();
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    final list = _cachedSnippets.map((s) => s.toMap()).toList();
    await prefs.setString(prefKey, jsonEncode(list));
  }

  /// Normalize utterance for matching: trim, lower-case, strip trailing punctuation
  static String normalizeUtterance(String text) {
    return text.trim().toLowerCase().replaceAll(RegExp(r'[।?!,\.\n]+$'), '').trim();
  }

  /// Check if utterance matches any snippet trigger
  String? matchSnippet(String utterance) {
    final normalized = normalizeUtterance(utterance);
    for (final s in _cachedSnippets) {
      if (normalizeUtterance(s.trigger) == normalized) {
        return s.expansion;
      }
    }
    return null;
  }
}
