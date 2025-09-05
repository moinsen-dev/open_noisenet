import 'package:json_annotation/json_annotation.dart';

part 'daily_statistics.g.dart';

@JsonSerializable()
class DailyStatistics {
  final int? id;
  final String date; // YYYY-MM-DD format
  @JsonKey(name: 'avg_leq')
  final double avgLeq;
  @JsonKey(name: 'max_leq')
  final double maxLeq;
  @JsonKey(name: 'min_leq')
  final double minLeq;
  @JsonKey(name: 'peak_hour')
  final int? peakHour; // Hour with highest average (0-23)
  @JsonKey(name: 'quiet_hour')
  final int? quietHour; // Hour with lowest average (0-23)
  @JsonKey(name: 'total_exceedances')
  final int totalExceedances;
  @JsonKey(name: 'total_samples')
  final int totalSamples;

  const DailyStatistics({
    this.id,
    required this.date,
    required this.avgLeq,
    required this.maxLeq,
    required this.minLeq,
    this.peakHour,
    this.quietHour,
    this.totalExceedances = 0,
    this.totalSamples = 0,
  });

  /// Create from database map
  factory DailyStatistics.fromMap(Map<String, dynamic> map) {
    return DailyStatistics(
      id: map['id'] as int?,
      date: map['date'] as String,
      avgLeq: map['avg_leq'] as double,
      maxLeq: map['max_leq'] as double,
      minLeq: map['min_leq'] as double,
      peakHour: map['peak_hour'] as int?,
      quietHour: map['quiet_hour'] as int?,
      totalExceedances: map['total_exceedances'] as int? ?? 0,
      totalSamples: map['total_samples'] as int? ?? 0,
    );
  }

  /// Convert to database map
  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'date': date,
      'avg_leq': avgLeq,
      'max_leq': maxLeq,
      'min_leq': minLeq,
      'peak_hour': peakHour,
      'quiet_hour': quietHour,
      'total_exceedances': totalExceedances,
      'total_samples': totalSamples,
    };
  }

  /// Get DateTime for the date
  DateTime get dateTime => DateTime.parse(date);

  /// Check if this is today's statistics
  bool get isToday {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return dateTime == today;
  }

  /// Check if this is from this week
  bool get isThisWeek {
    final now = DateTime.now();
    final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
    return dateTime.isAfter(startOfWeek) || dateTime == startOfWeek;
  }

  /// Get dynamic range
  double get dynamicRange => maxLeq - minLeq;

  /// Get weekday name
  String get weekdayName {
    const weekdays = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
    return weekdays[dateTime.weekday - 1];
  }

  /// Get formatted peak hour string
  String? get peakHourFormatted {
    if (peakHour == null) return null;
    return '${peakHour!.toString().padLeft(2, '0')}:00';
  }

  /// Get formatted quiet hour string
  String? get quietHourFormatted {
    if (quietHour == null) return null;
    return '${quietHour!.toString().padLeft(2, '0')}:00';
  }

  /// Create copy with updated values
  DailyStatistics copyWith({
    int? id,
    String? date,
    double? avgLeq,
    double? maxLeq,
    double? minLeq,
    int? peakHour,
    int? quietHour,
    int? totalExceedances,
    int? totalSamples,
  }) {
    return DailyStatistics(
      id: id ?? this.id,
      date: date ?? this.date,
      avgLeq: avgLeq ?? this.avgLeq,
      maxLeq: maxLeq ?? this.maxLeq,
      minLeq: minLeq ?? this.minLeq,
      peakHour: peakHour ?? this.peakHour,
      quietHour: quietHour ?? this.quietHour,
      totalExceedances: totalExceedances ?? this.totalExceedances,
      totalSamples: totalSamples ?? this.totalSamples,
    );
  }

  /// Convert to JSON
  Map<String, dynamic> toJson() => _$DailyStatisticsToJson(this);

  /// Create from JSON
  factory DailyStatistics.fromJson(Map<String, dynamic> json) =>
      _$DailyStatisticsFromJson(json);

  @override
  String toString() {
    return 'DailyStatistics($date, avg: ${avgLeq.toStringAsFixed(1)} dB, peak: $peakHourFormatted)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is DailyStatistics && 
           other.date == date;
  }

  @override
  int get hashCode => date.hashCode;
}