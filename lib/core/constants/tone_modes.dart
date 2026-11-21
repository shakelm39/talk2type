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
  static const String formal = "formal";
  static const String support = "support";
  static const String casual = "casual";
  static const String english = "english";

  static const List<ToneModeInfo> allModes = [
    ToneModeInfo(
      key: bangla,
      title: "বাংলা",
      bengaliTitle: "বাংলা",
      description: "মুখে যেভাবে বলবেন তা স্বয়ংক্রিয়ভাবে পরিমার্জিত, সঠিক দাঁড়ি-কমা যতিচিহ্নসহ প্রমিত ও নির্ভুল বাংলায় রূপান্তরিত হবে।",
      icon: Icons.edit_note_rounded,
      accentColor: Color(0xFFC81E2E),
      defaultSystemPrompt:
          "You are an expert Bengali typist and grammar specialist. Transcribe and format the spoken Bengali naturally and accurately. Add appropriate standard punctuation marks (দাঁড়ি '।', কমা ',', প্রশ্নবোধক '?'). Ensure sentences are properly completed with '।'. Do NOT alter original meaning, numbers, or key words. Output ONLY the polished Bengali text without any explanations or quotes.",
    ),
    ToneModeInfo(
      key: formal,
      title: "অফিসিয়াল",
      bengaliTitle: "অফিসিয়াল",
      description: "কর্মক্ষেত্র ও অফিসিয়াল যোগাযোগের জন্য মার্জিত, প্রফেশনাল ও বিনম্র ভাষা — ইমেইল ও গুরুত্বপূর্ণ বার্তার জন্য উপযুক্ত।",
      icon: Icons.business_center_rounded,
      accentColor: Color(0xFF8B5CF6),
      defaultSystemPrompt:
          "You are an executive Bengali communication assistant. Convert the spoken Bengali into polite, elegant, and professional standard Bengali suitable for official corporate emails, formal correspondence, and workplace communication. Add proper punctuation (দাঁড়ি '।', কমা ',', প্রশ্নবোধক '?'). Maintain the original meaning, facts, and numbers precisely. Output ONLY the final formal Bengali text without any explanations, markdown, or quotes.",
    ),
    ToneModeInfo(
      key: support,
      title: "কাস্টমার সার্ভিস",
      bengaliTitle: "কাস্টমার সার্ভিস",
      description: "অনলাইন বিক্রেতা ও সাপোর্ট টিমের জন্য বিনীত ও সহানুভূতিশীল উত্তর — সুন্দর সম্ভাষণসহ স্পষ্ট সমাধান।",
      icon: Icons.support_agent_rounded,
      accentColor: Color(0xFF10B981),
      defaultSystemPrompt:
          "You are a polite and helpful Bengali customer support assistant for online businesses. Transform the spoken Bengali into a courteous, friendly, and respectful customer reply. Greet appropriately and provide a clear, helpful response based strictly on what was spoken without inventing any facts, prices, or policies. Add proper punctuation (দাঁড়ি '।', কমা ',', প্রশ্নবোধক '?'). Output ONLY the final customer support reply without any explanations, markdown, or quotes.",
    ),
    ToneModeInfo(
      key: casual,
      title: "বন্ধুসুলভ",
      bengaliTitle: "বন্ধুসুলভ",
      description: "বন্ধু ও পরিচিতদের সাথে আড্ডার সাবলীল ও উষ্ণ কথোপকথন — কথ্য ও ঘরোয়া ভাব বজায় রেখে প্রাণবন্ত টেক্সট।",
      icon: Icons.forum_rounded,
      accentColor: Color(0xFFF59E0B),
      defaultSystemPrompt:
          "You are a friendly Bengali conversational typist. Convert the spoken Bengali into warm, casual, and colloquial Bengali as used in friendly social chats, retaining informal and conversational expressions naturally. Remove awkward stutters while keeping the relaxed personal tone. Add proper punctuation (দাঁড়ি '।', কমা ',', প্রশ্নবোধক '?'). Never omit key details, names, or numbers. Output ONLY the final casual Bengali text without any explanations, markdown, or quotes.",
    ),
    ToneModeInfo(
      key: english,
      title: "English",
      bengaliTitle: "English",
      description: "বাংলায় মুখে বলুন, বিদেশী ক্লায়েন্ট ও কাস্টমারদের জন্য সরাসরি ফ্লুয়েন্ট ও নির্ভুল ইংরেজিতে অনুবাদ হয়ে টাইপ হবে।",
      icon: Icons.translate_rounded,
      accentColor: Color(0xFF3B82F6),
      defaultSystemPrompt:
          "You are an expert speech translator. Listen to the spoken Bengali and translate it directly into fluent, natural, grammatically correct modern English with proper punctuation. Output ONLY the translated English text without notes or quotes.",
    ),
  ];

  static ToneModeInfo getByKey(String key) {
    final normalized = switch (key.toLowerCase().trim()) {
      'formal' || 'office_formal' => formal,
      'support' || 'customer_support' => support,
      'casual' || 'friend_casual' => casual,
      'english' || 'bangla_to_english' || 'english_translate' || 'en' => english,
      'bangla' || 'guchiye' || 'sundor' || 'clean_bangla' || 'hubohu' => bangla,
      _ => bangla,
    };

    return allModes.firstWhere(
      (m) => m.key == normalized,
      orElse: () => allModes.first,
    );
  }
}
