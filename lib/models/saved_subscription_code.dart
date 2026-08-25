class SavedSubscriptionCode {
  final String code;
  final String label;
  final String status;
  final int? lastCheckedAt;
  final String? message;

  const SavedSubscriptionCode({
    required this.code,
    this.label = '',
    this.status = 'unknown',
    this.lastCheckedAt,
    this.message,
  });

  SavedSubscriptionCode copyWith({
    String? code,
    String? label,
    String? status,
    int? lastCheckedAt,
    String? message,
  }) {
    return SavedSubscriptionCode(
      code: code ?? this.code,
      label: label ?? this.label,
      status: status ?? this.status,
      lastCheckedAt: lastCheckedAt ?? this.lastCheckedAt,
      message: message ?? this.message,
    );
  }

  Map<String, dynamic> toJson() => {
        'code': code,
        'label': label,
        'status': status,
        'last_checked_at': lastCheckedAt,
        'message': message,
      };

  factory SavedSubscriptionCode.fromJson(Map<String, dynamic> json) {
    return SavedSubscriptionCode(
      code: (json['code'] ?? '').toString().trim(),
      label: (json['label'] ?? '').toString().trim(),
      status: (json['status'] ?? 'unknown').toString(),
      lastCheckedAt: json['last_checked_at'] is int
          ? json['last_checked_at'] as int
          : int.tryParse(json['last_checked_at']?.toString() ?? ''),
      message: json['message']?.toString(),
    );
  }
}
