class Finding {
  final String type, location, severity, confidence, source;
  final int? costMin, costMax;
  final String? note;

  const Finding({required this.type, required this.location, required this.severity, required this.confidence, required this.source, this.costMin, this.costMax, this.note});

  factory Finding.fromArabicJson(Map<String, dynamic> json) {
    final cost = json['تكلفة_الإصلاح'];
    return Finding(
      type: json['النوع'] as String? ?? '', location: json['الموقع'] as String? ?? '',
      severity: json['الخطورة'] as String? ?? 'بسيط', confidence: json['مستوى_الثقة'] as String? ?? 'متوسط',
      source: json['المصدر'] as String? ?? '',
      costMin: cost is Map ? cost['من'] as int? : null, costMax: cost is Map ? cost['إلى'] as int? : null,
      note: json['ملاحظة'] as String?,
    );
  }

  bool get isMajor => severity == 'خطير';
}
