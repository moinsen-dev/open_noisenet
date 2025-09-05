import 'package:json_annotation/json_annotation.dart';

part 'noise_measurement.g.dart';

@JsonSerializable()
class NoiseMeasurement {
  final int? id;
  final int timestamp; // Unix timestamp for the minute
  @JsonKey(name: 'leq_db')
  final double leqDb; // Average dB for the minute
  @JsonKey(name: 'lmax_db')
  final double? lmaxDb; // Max dB in the minute
  @JsonKey(name: 'lmin_db')
  final double? lminDb; // Min dB in the minute
  @JsonKey(name: 'l10_db')
  final double? l10Db; // 90th percentile - loud events
  @JsonKey(name: 'l50_db')
  final double? l50Db; // Median noise level
  @JsonKey(name: 'l90_db')
  final double? l90Db; // 10th percentile - background noise
  @JsonKey(name: 'samples_count')
  final int? samplesCount;
  @JsonKey(name: 'created_at')
  final int createdAt;

  const NoiseMeasurement({
    this.id,
    required this.timestamp,
    required this.leqDb,
    this.lmaxDb,
    this.lminDb,
    this.l10Db,
    this.l50Db,
    this.l90Db,
    this.samplesCount,
    required this.createdAt,
  });

  /// Create from database map
  factory NoiseMeasurement.fromMap(Map<String, dynamic> map) {
    return NoiseMeasurement(
      id: map['id'] as int?,
      timestamp: map['timestamp'] as int,
      leqDb: map['leq_db'] as double,
      lmaxDb: map['lmax_db'] as double?,
      lminDb: map['lmin_db'] as double?,
      l10Db: map['l10_db'] as double?,
      l50Db: map['l50_db'] as double?,
      l90Db: map['l90_db'] as double?,
      samplesCount: map['samples_count'] as int?,
      createdAt: map['created_at'] as int,
    );
  }

  /// Convert to database map
  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'timestamp': timestamp,
      'leq_db': leqDb,
      'lmax_db': lmaxDb,
      'lmin_db': lminDb,
      'l10_db': l10Db,
      'l50_db': l50Db,
      'l90_db': l90Db,
      'samples_count': samplesCount,
      'created_at': createdAt,
    };
  }

  /// Create copy with updated values
  NoiseMeasurement copyWith({
    int? id,
    int? timestamp,
    double? leqDb,
    double? lmaxDb,
    double? lminDb,
    double? l10Db,
    double? l50Db,
    double? l90Db,
    int? samplesCount,
    int? createdAt,
  }) {
    return NoiseMeasurement(
      id: id ?? this.id,
      timestamp: timestamp ?? this.timestamp,
      leqDb: leqDb ?? this.leqDb,
      lmaxDb: lmaxDb ?? this.lmaxDb,
      lminDb: lminDb ?? this.lminDb,
      l10Db: l10Db ?? this.l10Db,
      l50Db: l50Db ?? this.l50Db,
      l90Db: l90Db ?? this.l90Db,
      samplesCount: samplesCount ?? this.samplesCount,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  /// Get DateTime for the timestamp
  DateTime get dateTime => DateTime.fromMillisecondsSinceEpoch(timestamp * 1000);

  /// Get hour of the day (0-23)
  int get hourOfDay => dateTime.hour;

  /// Check if measurement is from today
  bool get isToday {
    final now = DateTime.now();
    final measurementDate = dateTime;
    return now.year == measurementDate.year &&
           now.month == measurementDate.month &&
           now.day == measurementDate.day;
  }

  /// Get dynamic range (difference between max and min)
  double? get dynamicRange {
    if (lmaxDb == null || lminDb == null) return null;
    return lmaxDb! - lminDb!;
  }

  /// Convert to JSON
  Map<String, dynamic> toJson() => _$NoiseMeasurementToJson(this);

  /// Create from JSON
  factory NoiseMeasurement.fromJson(Map<String, dynamic> json) =>
      _$NoiseMeasurementFromJson(json);

  @override
  String toString() {
    return 'NoiseMeasurement(${dateTime.toIso8601String()}, ${leqDb.toStringAsFixed(1)} dB)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is NoiseMeasurement && 
           other.timestamp == timestamp &&
           other.leqDb == leqDb;
  }

  @override
  int get hashCode => Object.hash(timestamp, leqDb);
}