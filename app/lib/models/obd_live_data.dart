/// Real-time OBD-II data from a single poll cycle.
class ObdLiveData {
  // Core gauges
  final int? rpm;
  final int? speedKmh;

  // Engine health
  final double? coolantTempC;
  final int? engineLoadPct;
  final int? throttlePct;
  final double? intakeAirTempC;

  // Fuel system health (fraud indicators)
  final double? shortTermFuelTrimB1;
  final double? longTermFuelTrimB1;
  final double? o2VoltageB1S1;

  // Electrical
  final double? batteryVoltage;
  final double? controlModuleVoltage;

  // Usage indicators
  final int? fuelLevelPct;
  final int? runTimeSec;
  final int? distanceWithMilKm;

  const ObdLiveData({
    this.rpm,
    this.speedKmh,
    this.coolantTempC,
    this.engineLoadPct,
    this.throttlePct,
    this.intakeAirTempC,
    this.shortTermFuelTrimB1,
    this.longTermFuelTrimB1,
    this.o2VoltageB1S1,
    this.batteryVoltage,
    this.controlModuleVoltage,
    this.fuelLevelPct,
    this.runTimeSec,
    this.distanceWithMilKm,
  });

  Map<String, dynamic> toJson() => {
    'rpm': rpm,
    'speed_kmh': speedKmh,
    'coolant_temp_c': coolantTempC,
    'engine_load_pct': engineLoadPct,
    'throttle_pct': throttlePct,
    'intake_air_temp_c': intakeAirTempC,
    'short_term_fuel_trim_b1': shortTermFuelTrimB1,
    'long_term_fuel_trim_b1': longTermFuelTrimB1,
    'o2_voltage_b1s1': o2VoltageB1S1,
    'battery_voltage': batteryVoltage,
    'control_module_voltage': controlModuleVoltage,
    'fuel_level_pct': fuelLevelPct,
    'run_time_sec': runTimeSec,
    'distance_with_mil_km': distanceWithMilKm,
  };
}
