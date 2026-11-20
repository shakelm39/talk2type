import 'package:flutter/material.dart';

class ToneModeInfo {
  final String key;
  final String title;
  final String bengaliTitle;
  final String description;
  final IconData icon;
  final Color accentColor;
  final String defaultSystemPrompt;

  const ToneModeInfo({
    required this.key,
    required this.title,
    required this.bengaliTitle,
    required this.description,
    required this.icon,
    required this.accentColor,
    required this.defaultSystemPrompt,
  });
}

class ToneModes {
  static const String bangla = "bangla";
  static const String english = "english";

  // Backward compatibility aliases
  static const String sundor = bangla;
  static const String formal = bangla;
  static const String hubohu = bangla;
  static const String cleanBangla = bangla;
  static const String officeFormal = bangla;
  static const String banglaToEnglish = english;

  static const List<ToneModeInfo> allModes = [
    ToneModeInfo(
      key: bangla,
      title: "গুছিয়ে বাংলায়",
      bengaliTitle: "গুছিয়ে বাংলায়",
      description: "মুখে যেভাবে বলবেন তা স্বয়ংক্রিয়ভাবে পরিমার্জিত, সঠিক দাঁড়ি-কমা যতিচিহ্নসহ সুন্দর ও গোছানো বাংলায় রূপান্তরিত হবে।",
      icon: Icons.edit_note_rounded,
      accentColor: Color(0xFFC81E2E),
      defaultSystemPrompt:
          "You are an executive Bengali communication assistant. Transcribe the spoken audio and rewrite it into polite, professional, elegant standard Bengali suitable for customer messages, formal emails, or social chat. Add proper punctuation (।, ,, ?). Output ONLY the polished Bengali text without commentary.",
    ),
    ToneModeInfo(
      key: english,
      title: "English",
      bengaliTitle: "English",
      description: "বাংলায় মুখে বলুন, বিদেশী ক্লায়েন্ট ও কাস্টমারদের জন্য সরাসরি ফ্লুয়েন্ট ও নির্ভুল ইংরেজিতে অনুবাদ হয়ে টাইপ হবে।",
      icon: Icons.translate_rounded,
      accentColor: Color(0xFFC81E2E),
      defaultSystemPrompt:
          "You are an expert speech translator. Listen to the spoken Bengali and translate it directly into fluent, natural, grammatically correct modern English with proper punctuation. Output ONLY the translated English text without notes or quotes.",
    ),
  ];

  static ToneModeInfo getByKey(String key) {
    final normalized = switch (key.toLowerCase().trim()) {
      'bangla' || 'guchiye' || 'sundor' || 'clean_bangla' || 'formal' || 'hubohu' => bangla,
      'english' || 'bangla_to_english' || 'english_translate' => english,
      _ => bangla,
    };

    return allModes.firstWhere(
      (m) => m.key == normalized,
      orElse: () => allModes.first,
    );
  }
}
