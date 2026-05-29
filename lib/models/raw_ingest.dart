class RawIngest {
  const RawIngest({
    required this.id,
    required this.body,
    required this.sender,
    required this.receivedAt,
    required this.deviceId,
    required this.source,
    this.batchHint,
    required this.createdAt,
    this.duplicate = false,
  });

  final String id;
  final String body;
  final String sender;
  final DateTime receivedAt;
  final String deviceId;
  final String source;
  final String? batchHint;
  final DateTime createdAt;
  final bool duplicate;

  Map<String, dynamic> toJson() => {
        'id': id,
        'body': body,
        'sender': sender,
        'receivedAt': receivedAt.toIso8601String(),
        'deviceId': deviceId,
        'source': source,
        if (batchHint != null) 'batchHint': batchHint,
        'createdAt': createdAt.toIso8601String(),
        'duplicate': duplicate,
      };

  factory RawIngest.fromJson(Map<String, dynamic> json) {
    return RawIngest(
      id: json['id'] as String,
      body: json['body'] as String,
      sender: json['sender'] as String,
      receivedAt: DateTime.parse(json['receivedAt'] as String),
      deviceId: json['deviceId'] as String,
      source: json['source'] as String,
      batchHint: json['batchHint'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
      duplicate: json['duplicate'] as bool? ?? false,
    );
  }
}
