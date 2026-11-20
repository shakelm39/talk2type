class TranscriptionItem {
  final int? id;
  final String text;
  final String? audioPath;
  final String mode;
  final DateTime timestamp;
  final bool isSuccess;
  final bool isDirectTyped;

  TranscriptionItem({
    this.id,
    required this.text,
    this.audioPath,
    required this.mode,
    required this.timestamp,
    this.isSuccess = true,
    this.isDirectTyped = true,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'text': text,
      'audio_path': audioPath,
      'mode': mode,
      'timestamp': timestamp.toIso8601String(),
      'is_success': isSuccess ? 1 : 0,
      'is_direct_typed': isDirectTyped ? 1 : 0,
    };
  }

  factory TranscriptionItem.fromMap(Map<String, dynamic> map) {
    return TranscriptionItem(
      id: map['id'] as int?,
      text: map['text'] as String,
      audioPath: map['audio_path'] as String?,
      mode: (map['mode'] as String?) ?? 'clean_bangla',
      timestamp: DateTime.tryParse(map['timestamp'] as String? ?? '') ?? DateTime.now(),
      isSuccess: (map['is_success'] as int?) == 1,
      isDirectTyped: (map['is_direct_typed'] as int?) == 1,
    );
  }

  TranscriptionItem copyWith({
    int? id,
    String? text,
    String? audioPath,
    String? mode,
    DateTime? timestamp,
    bool? isSuccess,
    bool? isDirectTyped,
  }) {
    return TranscriptionItem(
      id: id ?? this.id,
      text: text ?? this.text,
      audioPath: audioPath ?? this.audioPath,
      mode: mode ?? this.mode,
      timestamp: timestamp ?? this.timestamp,
      isSuccess: isSuccess ?? this.isSuccess,
      isDirectTyped: isDirectTyped ?? this.isDirectTyped,
    );
  }
}
