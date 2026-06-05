class Shift {
  final int? id;
  final String name;
  final String startTime; // "HH:MM"
  final String endTime;   // "HH:MM"
  final int gracePeriodMins;
  final bool isOvertimeEnabled;
  final double overtimeThresholdHours;

  final Map<String, dynamic> policyRules;

  // Helpers for UI
  bool get entrySelfie => policyRules['entry_requirements']?['selfie'] ?? false;
  bool get entryGeofence => policyRules['entry_requirements']?['geofence'] ?? false;
  bool get exitSelfie => policyRules['exit_requirements']?['selfie'] ?? false;
  bool get exitGeofence => policyRules['exit_requirements']?['geofence'] ?? false;
  int get correctionDeadline => policyRules['correction_deadline'] is int 
      ? policyRules['correction_deadline'] 
      : (int.tryParse(policyRules['correction_deadline']?.toString() ?? '') ?? 2);

  Shift({
    this.id,
    required this.name,
    required this.startTime,
    required this.endTime,
    required this.gracePeriodMins, 
    required this.isOvertimeEnabled,
    required this.overtimeThresholdHours,
    this.policyRules = const {},
  });

  factory Shift.fromJson(Map<String, dynamic> json) {
    return Shift(
      id: json['shift_id'],
      name: json['shift_name'] ?? '',
      startTime: json['start_time'] ?? '09:00',
      endTime: json['end_time'] ?? '18:00',
      gracePeriodMins: json['grace_period_mins'] is int ? json['grace_period_mins'] : int.tryParse(json['grace_period_mins']?.toString() ?? '0') ?? 0,
      isOvertimeEnabled: json['is_overtime_enabled'] == 1 || json['is_overtime_enabled'] == true,
      overtimeThresholdHours: double.tryParse(json['overtime_threshold_hours']?.toString() ?? '0') ?? 8.0,
      policyRules: json['policy_rules'] is Map<String, dynamic> ? json['policy_rules'] : {},
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'shift_name': name,
      'start_time': startTime,
      'end_time': endTime,
      'grace_period_mins': gracePeriodMins,
      'is_overtime_enabled': isOvertimeEnabled,
      'overtime_threshold_hours': overtimeThresholdHours,
      'policy_rules': policyRules,
    };
  }
}
