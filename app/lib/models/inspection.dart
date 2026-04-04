enum InspectionStatus {
  created, uploading, processing, completed, failed;
  static InspectionStatus fromString(String s) => InspectionStatus.values.firstWhere((e) => e.name == s, orElse: () => InspectionStatus.created);
}

enum CaptureMode {
  quick(4, 'فحص سريع'),
  full(15, 'فحص شامل');
  final int photoCount;
  final String labelAr;
  const CaptureMode(this.photoCount, this.labelAr);
}

class Inspection {
  final String id;
  final InspectionStatus status;
  final String carModel;
  final int year;
  final int mileage;
  final int photoCount;
  final int? trustScore;
  final Map<String, dynamic>? result;
  final String? error;
  final String createdAt;
  final String? completedAt;

  const Inspection({required this.id, required this.status, required this.carModel, required this.year, required this.mileage, this.photoCount = 0, this.trustScore, this.result, this.error, required this.createdAt, this.completedAt});

  factory Inspection.fromJson(Map<String, dynamic> json) => Inspection(
    id: json['id'] as String, status: InspectionStatus.fromString(json['status'] as String),
    carModel: json['car_model'] as String, year: json['year'] as int, mileage: json['mileage'] as int,
    photoCount: json['photo_count'] as int? ?? 0, trustScore: json['trust_score'] as int?,
    result: json['result'] as Map<String, dynamic>?, error: json['error'] as String?,
    createdAt: json['created_at'] as String, completedAt: json['completed_at'] as String?,
  );

  String get scoreLabelAr {
    final s = trustScore ?? 0;
    if (s >= 85) return 'اشتري بثقة';
    if (s >= 65) return 'فاوض على السعر';
    if (s >= 40) return 'اعمل فحص ميكانيكي';
    return 'ابعد عن العربية دي';
  }
}
