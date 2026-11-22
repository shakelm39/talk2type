import 'dart:convert';

class VoiceSnippet {
  final String id;
  final String trigger;
  final String expansion;
  final DateTime createdAt;

  VoiceSnippet({
    required this.id,
    required this.trigger,
    required this.expansion,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'trigger': trigger,
      'expansion': expansion,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory VoiceSnippet.fromMap(Map<String, dynamic> map) {
    return VoiceSnippet(
      id: map['id']?.toString() ?? '',
      trigger: map['trigger']?.toString() ?? '',
      expansion: map['expansion']?.toString() ?? '',
      createdAt: map['createdAt'] != null
          ? DateTime.tryParse(map['createdAt'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  String toJson() => jsonEncode(toMap());

  factory VoiceSnippet.fromJson(String source) => VoiceSnippet.fromMap(jsonDecode(source));
}
