class ObdResult {
  final String? vin;
  final bool milOn;
  final int dtcCount;
  final List<String> storedDtcs;
  final List<String> pendingDtcs;
  final double? coolantTempC;
  final double? batteryVoltage;
  final int? distanceWithMilKm;
  final int? timeSinceDtcClearedMin;
  final int? warmupsSinceDtcCleared;
  final String? obdCompliance;
  final int? odometerKm;

  const ObdResult({
    this.vin,
    this.milOn = false,
    this.dtcCount = 0,
    this.storedDtcs = const [],
    this.pendingDtcs = const [],
    this.coolantTempC,
    this.batteryVoltage,
    this.distanceWithMilKm,
    this.timeSinceDtcClearedMin,
    this.warmupsSinceDtcCleared,
    this.obdCompliance,
    this.odometerKm,
  });

  Map<String, dynamic> toJson() => {
        'vin': vin,
        'mil_on': milOn,
        'dtc_count': dtcCount,
        'stored_dtcs': storedDtcs,
        'pending_dtcs': pendingDtcs,
        'coolant_temp_c': coolantTempC,
        'battery_voltage': batteryVoltage,
        'distance_with_mil_km': distanceWithMilKm,
        'time_since_dtc_cleared_min': timeSinceDtcClearedMin,
        'warmups_since_dtc_cleared': warmupsSinceDtcCleared,
        'obd_compliance': obdCompliance,
        'odometer_km': odometerKm,
      };

  factory ObdResult.fromJson(Map<String, dynamic> json) => ObdResult(
        vin: json['vin'] as String?,
        milOn: json['mil_on'] as bool? ?? false,
        dtcCount: json['dtc_count'] as int? ?? 0,
        storedDtcs: (json['stored_dtcs'] as List?)?.cast<String>() ?? [],
        pendingDtcs: (json['pending_dtcs'] as List?)?.cast<String>() ?? [],
        coolantTempC: (json['coolant_temp_c'] as num?)?.toDouble(),
        batteryVoltage: (json['battery_voltage'] as num?)?.toDouble(),
        distanceWithMilKm: json['distance_with_mil_km'] as int?,
        timeSinceDtcClearedMin: json['time_since_dtc_cleared_min'] as int?,
        warmupsSinceDtcCleared: json['warmups_since_dtc_cleared'] as int?,
        obdCompliance: json['obd_compliance'] as String?,
        odometerKm: json['odometer_km'] as int?,
      );

  /// Suspicious indicators for the inspection report.
  List<String> get warnings {
    final w = <String>[];
    if (milOn) w.add('لمبة المحرك شغالة — في مشكلة في المحرك');
    if (dtcCount > 0) w.add('في $dtcCount كود عطل مسجل');
    if (timeSinceDtcClearedMin != null && timeSinceDtcClearedMin! < 30) {
      w.add('تم مسح أكواد الأعطال من أقل من نص ساعة — مشبوه');
    }
    if (warmupsSinceDtcCleared != null && warmupsSinceDtcCleared! < 3) {
      w.add('المحرك اتشغل ${warmupsSinceDtcCleared} مرة بس من بعد مسح الأكواد — مشبوه');
    }
    if (coolantTempC != null && coolantTempC! > 105) {
      w.add('حرارة المحرك عالية: ${coolantTempC!.toInt()}°C');
    }
    if (batteryVoltage != null && batteryVoltage! < 11.5) {
      w.add('البطارية ضعيفة: ${batteryVoltage!.toStringAsFixed(1)}V');
    }
    return w;
  }
}
