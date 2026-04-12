/// Real-time OBD-II data from a single poll cycle.
class ObdLiveData {
  final int? rpm;
  final int? speedKmh;
  final double? coolantTempC;
  final double? intakeAirTempC;
  final int? engineLoadPct;
  final int? throttlePct;
  final int? fuelLevelPct;
  final int? intakeManifoldPressureKpa;
  final int? fuelPressureKpa;
  final double? batteryVoltage;
  final int? runTimeSec;
  final double? mafFlowGps;
  final int? timingAdvanceDeg;
  final int? catalystTempC;

  const ObdLiveData({
    this.rpm,
    this.speedKmh,
    this.coolantTempC,
    this.intakeAirTempC,
    this.engineLoadPct,
    this.throttlePct,
    this.fuelLevelPct,
    this.intakeManifoldPressureKpa,
    this.fuelPressureKpa,
    this.batteryVoltage,
    this.runTimeSec,
    this.mafFlowGps,
    this.timingAdvanceDeg,
    this.catalystTempC,
  });

  Map<String, dynamic> toJson() => {
    'rpm': rpm,
    'speed_kmh': speedKmh,
    'coolant_temp_c': coolantTempC,
    'intake_air_temp_c': intakeAirTempC,
    'engine_load_pct': engineLoadPct,
    'throttle_pct': throttlePct,
    'fuel_level_pct': fuelLevelPct,
    'intake_manifold_pressure_kpa': intakeManifoldPressureKpa,
    'fuel_pressure_kpa': fuelPressureKpa,
    'battery_voltage': batteryVoltage,
    'run_time_sec': runTimeSec,
    'maf_flow_gps': mafFlowGps,
    'timing_advance_deg': timingAdvanceDeg,
    'catalyst_temp_c': catalystTempC,
  };
}
