class RunnerConfig {
  final bool enabled;
  final int intervalMinutes;
  final String claudePath;
  final DateTime? lastRun;

  const RunnerConfig({
    this.enabled = false,
    this.intervalMinutes = 60,
    this.claudePath = '',
    this.lastRun,
  });

  factory RunnerConfig.fromJson(Map<String, dynamic> json) {
    return RunnerConfig(
      enabled: json['enabled'] as bool? ?? false,
      intervalMinutes: json['intervalMinutes'] as int? ?? 60,
      claudePath: json['claudePath'] as String? ?? '',
      lastRun: json['lastRun'] != null
          ? DateTime.tryParse(json['lastRun'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'enabled': enabled,
      'intervalMinutes': intervalMinutes,
      'claudePath': claudePath,
      'lastRun': lastRun?.toIso8601String(),
    };
  }

  RunnerConfig copyWith({
    bool? enabled,
    int? intervalMinutes,
    String? claudePath,
    DateTime? lastRun,
    bool clearLastRun = false,
  }) {
    return RunnerConfig(
      enabled: enabled ?? this.enabled,
      intervalMinutes: intervalMinutes ?? this.intervalMinutes,
      claudePath: claudePath ?? this.claudePath,
      lastRun: clearLastRun ? null : (lastRun ?? this.lastRun),
    );
  }
}
