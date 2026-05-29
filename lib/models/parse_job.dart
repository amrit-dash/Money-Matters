enum ParseJobStatus {
  pending,
  done,
  failed;

  static ParseJobStatus fromString(String value) {
    return ParseJobStatus.values.firstWhere(
      (e) => e.name == value,
      orElse: () => ParseJobStatus.pending,
    );
  }
}

class ParseJob {
  const ParseJob({
    required this.id,
    required this.rawIngestId,
    required this.status,
    required this.rulesVersion,
    this.error,
    required this.updatedAt,
  });

  final String id;
  final String rawIngestId;
  final ParseJobStatus status;
  final String rulesVersion;
  final String? error;
  final DateTime updatedAt;

  Map<String, dynamic> toJson() => {
        'id': id,
        'rawIngestId': rawIngestId,
        'status': status.name,
        'rulesVersion': rulesVersion,
        if (error != null) 'error': error,
        'updatedAt': updatedAt.toIso8601String(),
      };

  factory ParseJob.fromJson(Map<String, dynamic> json) {
    return ParseJob(
      id: json['id'] as String,
      rawIngestId: json['rawIngestId'] as String,
      status: ParseJobStatus.fromString(json['status'] as String? ?? 'pending'),
      rulesVersion: json['rulesVersion'] as String,
      error: json['error'] as String?,
      updatedAt: DateTime.parse(json['updatedAt'] as String),
    );
  }

  ParseJob copyWith({
    String? id,
    String? rawIngestId,
    ParseJobStatus? status,
    String? rulesVersion,
    String? error,
    DateTime? updatedAt,
  }) {
    return ParseJob(
      id: id ?? this.id,
      rawIngestId: rawIngestId ?? this.rawIngestId,
      status: status ?? this.status,
      rulesVersion: rulesVersion ?? this.rulesVersion,
      error: error ?? this.error,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
