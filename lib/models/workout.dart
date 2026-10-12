class Lift {
  Lift({
    required this.id,
    required this.name,
    this.sets = 3,
    List<String>? swaps,
  }) : swaps = swaps ?? [];

  final String id;
  String name;
  int sets;
  final List<String> swaps;

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'sets': sets,
        'swaps': swaps,
      };

  factory Lift.fromJson(Map<String, dynamic> json) => Lift(
        id: json['id'] as String? ?? '',
        name: json['name'] as String? ?? '',
        sets: (json['sets'] as num?)?.toInt() ?? 3,
        swaps: (json['swaps'] as List?)?.map((e) => '$e').where((e) => e.trim().isNotEmpty).toList() ?? [],
      );
}

class Routine {
  Routine({
    required this.id,
    required this.name,
    this.restSeconds = 90,
    List<Lift>? lifts,
  }) : lifts = lifts ?? [];

  final String id;
  String name;
  int restSeconds;
  final List<Lift> lifts;

  int get setCount => lifts.fold(0, (sum, lift) => sum + lift.sets);

  int get minutes {
    if (setCount == 0) return 0;
    return ((setCount * (restSeconds + 118)) / 60).round();
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'rest': restSeconds,
        'lifts': lifts.map((lift) => lift.toJson()).toList(),
      };

  factory Routine.fromJson(Map<String, dynamic> json) => Routine(
        id: json['id'] as String? ?? '',
        name: json['name'] as String? ?? '',
        restSeconds: (json['rest'] as num?)?.toInt() ?? 90,
        lifts: (json['lifts'] as List?)
                ?.whereType<Map>()
                .map((e) => Lift.fromJson(Map<String, dynamic>.from(e)))
                .where((lift) => lift.id.isNotEmpty && lift.name.trim().isNotEmpty)
                .toList() ??
            [],
      );
}

class SessionLog {
  SessionLog({
    required this.id,
    required this.routineId,
    required this.routineName,
    required this.started,
    this.finished,
    this.basedOn,
    this.rewarded = false,
    Map<String, String>? names,
  }) : names = names ?? {};

  final String id;
  final String routineId;
  String routineName;
  final DateTime started;
  DateTime? finished;
  String? basedOn;
  bool rewarded;
  final Map<String, String> names;

  Map<String, dynamic> toJson() => {
        'id': id,
        'routineId': routineId,
        'routineName': routineName,
        'started': started.toIso8601String(),
        'finished': finished?.toIso8601String(),
        'basedOn': basedOn,
        'rewarded': rewarded,
        'names': names,
      };

  factory SessionLog.fromJson(Map<String, dynamic> json) {
    final rawNames = json['names'];
    return SessionLog(
      id: json['id'] as String? ?? '',
      routineId: json['routineId'] as String? ?? '',
      routineName: json['routineName'] as String? ?? '',
      started: DateTime.tryParse(json['started'] as String? ?? '') ?? DateTime.now(),
      finished: DateTime.tryParse(json['finished'] as String? ?? ''),
      basedOn: json['basedOn'] as String?,
      rewarded: json['rewarded'] == true,
      names: rawNames is Map ? rawNames.map((key, value) => MapEntry('$key', '$value')) : {},
    );
  }
}

class LoggedSet {
  LoggedSet({
    required this.id,
    required this.sessionId,
    required this.liftId,
    required this.name,
    required this.index,
    required this.kgTenths,
    required this.reps,
    required this.at,
  });

  final String id;
  final String sessionId;
  final String liftId;
  String name;
  int index;
  int kgTenths;
  int reps;
  final DateTime at;

  Map<String, dynamic> toJson() => {
        'id': id,
        'sessionId': sessionId,
        'liftId': liftId,
        'name': name,
        'index': index,
        'kg': kgTenths,
        'reps': reps,
        'at': at.toIso8601String(),
      };

  factory LoggedSet.fromJson(Map<String, dynamic> json) => LoggedSet(
        id: json['id'] as String? ?? '',
        sessionId: json['sessionId'] as String? ?? '',
        liftId: json['liftId'] as String? ?? '',
        name: json['name'] as String? ?? '',
        index: (json['index'] as num?)?.toInt() ?? 1,
        kgTenths: (json['kg'] as num?)?.toInt() ?? 0,
        reps: (json['reps'] as num?)?.toInt() ?? 0,
        at: DateTime.tryParse(json['at'] as String? ?? '') ?? DateTime.now(),
      );
}

String kgText(int tenths) {
  final sign = tenths < 0 ? '-' : '';
  final value = tenths.abs();
  final whole = value ~/ 10;
  final frac = value % 10;
  if (frac == 0) return '$sign$whole';
  return '$sign$whole.$frac';
}

String clockText(Duration duration, {bool padMinutes = false}) {
  final minutes = duration.inMinutes.remainder(60);
  final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
  final hours = duration.inHours;
  final minuteText = padMinutes ? minutes.toString().padLeft(2, '0') : '$minutes';
  if (hours > 0) return '$hours:$minuteText:$seconds';
  return '$minuteText:$seconds';
}
