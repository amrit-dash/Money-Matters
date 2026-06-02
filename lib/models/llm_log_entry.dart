import 'package:cloud_firestore/cloud_firestore.dart';

class LlmLogEntry {
  const LlmLogEntry({
    required this.id,
    required this.level,
    required this.message,
    required this.createdAt,
    this.detail,
    this.provider,
    this.model,
    this.source,
  });

  final String id;
  final String level;
  final String message;
  final DateTime createdAt;
  final String? detail;
  final String? provider;
  final String? model;
  final String? source;

  bool get isError => level == 'error';
  bool get isWarning => level == 'warn';

  factory LlmLogEntry.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    final created = data['createdAt'];
    return LlmLogEntry(
      id: doc.id,
      level: data['level'] as String? ?? 'info',
      message: data['message'] as String? ?? '',
      detail: data['detail'] as String?,
      provider: data['provider'] as String?,
      model: data['model'] as String?,
      source: data['source'] as String?,
      createdAt: created is Timestamp
          ? created.toDate()
          : DateTime.fromMillisecondsSinceEpoch(0),
    );
  }
}
