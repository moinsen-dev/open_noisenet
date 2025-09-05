import 'package:json_annotation/json_annotation.dart';

part 'hourly_statistics.g.dart';

@JsonSerializable()
class HourlyStatistics {
  final int? id;
  @JsonKey(name: 'hour_timestamp')
  final int hourTimestamp; // Unix timestamp for start of hour
  @JsonKey(name: 'avg_leq')
  final double avgLeq;
  @JsonKey(name: 'max_leq')
  final double maxLeq;
  @JsonKey(name: 'min_leq')
  final double minLeq;
  final double? l10;
  final double? l50;
  final double? l90;
  @JsonKey(name: 'exceedance_count')
  final int exceedanceCount;
  @JsonKey(name: 'total_samples')
  final int totalSamples;

  const HourlyStatistics({
    this.id,
    required this.hourTimestamp,
    required this.avgLeq,
    required this.maxLeq,
    required this.minLeq,
    this.l10,
    this.l50,
    this.l90,
    this.exceedanceCount = 0,
    this.totalSamples = 0,
  });

  /// Create from database map
  factory HourlyStatistics.fromMap(Map<String, dynamic> map) {
    return HourlyStatistics(
      id: map['id'] as int?,
      hourTimestamp: map['hour_timestamp'] as int,
      avgLeq: map['avg_leq'] as double,
      maxLeq: map['max_leq'] as double,
      minLeq: map['min_leq'] as double,
      l10: map['l10'] as double?,
      l50: map['l50'] as double?,
      l90: map['l90'] as double?,
      exceedanceCount: map['exceedance_count'] as int? ?? 0,
      totalSamples: map['total_samples'] as int? ?? 0,
    );
  }

  /// Convert to database map
  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'hour_timestamp': hourTimestamp,
      'avg_leq': avgLeq,
      'max_leq': maxLeq,
      'min_leq': minLeq,
      'l10': l10,
      'l50': l50,
      'l90': l90,
      'exceedance_count': exceedanceCount,
      'total_samples': totalSamples,
    };
  }

  /// Get DateTime for the hour
  DateTime get dateTime => DateTime.fromMillisecondsSinceEpoch(hourTimestamp * 1000);

  /// Get hour of day (0-23)
  int get hourOfDay => dateTime.hour;

  /// Check if this is from today
  bool get isToday {
    final now = DateTime.now();
    final hourDate = dateTime;
    return now.year == hourDate.year &&
           now.month == hourDate.month &&
           now.day == hourDate.day;
  }

  /// Get dynamic range
  double get dynamicRange => maxLeq - minLeq;

  /// Create copy with updated values
  HourlyStatistics copyWith({
    int? id,
    int? hourTimestamp,
    double? avgLeq,
    double? maxLeq,
    double? minLeq,
    double? l10,
    double? l50,
    double? l90,
    int? exceedanceCount,
    int? totalSamples,
  }) {
    return HourlyStatistics(
      id: id ?? this.id,
      hourTimestamp: hourTimestamp ?? this.hourTimestamp,
      avgLeq: avgLeq ?? this.avgLeq,
      maxLeq: maxLeq ?? this.maxLeq,
      minLeq: minLeq ?? this.minLeq,
      l10: l10 ?? this.l10,
      l50: l50 ?? this.l50,
      l90: l90 ?? this.l90,
      exceedanceCount: exceedanceCount ?? this.exceedanceCount,
      totalSamples: totalSamples ?? this.totalSamples,
    );
  }

  /// Convert to JSON
  Map<String, dynamic> toJson() => _$HourlyStatisticsToJson(this);

  /// Create from JSON
  factory HourlyStatistics.fromJson(Map<String, dynamic> json) =>
      _$HourlyStatisticsFromJson(json);

  @override
  String toString() {
    return 'HourlyStatistics(${dateTime.hour}:00, avg: ${avgLeq.toStringAsFixed(1)} dB, samples: $totalSamples)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is HourlyStatistics && 
           other.hourTimestamp == hourTimestamp;
  }

  @override
  int get hashCode => hourTimestamp.hashCode;
}