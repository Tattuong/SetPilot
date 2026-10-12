import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../core/services/storage_service.dart';
import '../models/workout.dart';
import 'shop_provider.dart';

class SetDraft {
  const SetDraft(this.kgTenths, this.reps, this.fromHistory);

  final int kgTenths;
  final int reps;
  final bool fromHistory;
}

class GymProvider extends ChangeNotifier {
  GymProvider(this.shop);

  static const _key = 'sp_gym';
  static const kgStep = 25;

  final ShopProvider shop;
  final _uuid = const Uuid();

  final List<Routine> _routines = [];
  final List<SessionLog> _sessions = [];
  final List<LoggedSet> _sets = [];

  String? _selectedId;
  String? _activeId;
  String? _nudgeLift;
  int? _nudgeSet;
  int? _nudgeKg;
  int? _nudgeReps;
  var _endingRest = false;
  DateTime? restEnds;
  int restTotal = 90;
  bool restPaused = false;
  int restLeft = 0;

  List<Routine> get routines => List.unmodifiable(_routines);
  List<SessionLog> get sessions => List.unmodifiable(_sessions);
  List<LoggedSet> get sets => List.unmodifiable(_sets);

  bool get canAdd => _routines.length < shop.maxArchive;

  SessionLog? get active {
    final id = _activeId;
    if (id == null) return null;
    for (final session in _sessions) {
      if (session.id == id && session.finished == null) return session;
    }
    return null;
  }

  Routine? get selected {
    final id = active?.routineId ?? _selectedId;
    if (id == null) return _routines.isEmpty ? null : _routines.first;
    return findRoutine(id) ?? (_routines.isEmpty ? null : _routines.first);
  }

  bool get resting => restPaused || restRemaining > 0;

  int get restRemaining {
    if (restPaused) return restLeft;
    final ends = restEnds;
    if (ends == null) return 0;
    final left = ends.difference(DateTime.now()).inSeconds;
    return left < 0 ? 0 : left;
  }

  Routine? findRoutine(String id) {
    for (final routine in _routines) {
      if (routine.id == id) return routine;
    }
    return null;
  }

  Lift? findLift(String id) {
    for (final routine in _routines) {
      for (final lift in routine.lifts) {
        if (lift.id == id) return lift;
      }
    }
    return null;
  }

  String liftName(Lift lift) => active?.names[lift.id] ?? lift.name;

  List<LoggedSet> setsFor(String? sessionId, String liftId) {
    if (sessionId == null) return [];
    final rows = _sets.where((set) => set.sessionId == sessionId && set.liftId == liftId).toList()
      ..sort((a, b) => a.index.compareTo(b.index));
    return rows;
  }

  int loggedCount(String liftId) => setsFor(active?.id, liftId).length;

  LoggedSet? previousSet(String name, int index, {String? basedOn}) {
    final ordered = <SessionLog>[];
    if (basedOn != null) {
      for (final session in _sessions) {
        if (session.id == basedOn) ordered.add(session);
      }
    }
    final finished = _sessions.where((session) => session.finished != null && session.id != active?.id).toList()
      ..sort((a, b) => b.started.compareTo(a.started));
    for (final session in finished) {
      if (ordered.every((item) => item.id != session.id)) ordered.add(session);
    }
    LoggedSet? fallback;
    for (final session in ordered) {
      final hits = _sets.where((set) => set.sessionId == session.id && set.name.toLowerCase() == name.toLowerCase()).toList()
        ..sort((a, b) => a.index.compareTo(b.index));
      for (final set in hits) {
        if (set.index == index) return set;
      }
      if (fallback == null && hits.isNotEmpty) fallback = hits.last;
    }
    return fallback;
  }

  SetDraft draftFor(String liftId) {
    final lift = findLift(liftId);
    if (lift == null) return const SetDraft(200, 8, false);
    final next = loggedCount(liftId) + 1;
    if (_nudgeLift == liftId && _nudgeSet == next && _nudgeKg != null && _nudgeReps != null) {
      return SetDraft(_nudgeKg!, _nudgeReps!, false);
    }
    final previous = previousSet(liftName(lift), next, basedOn: active?.basedOn);
    if (previous != null) return SetDraft(previous.kgTenths, previous.reps, true);
    final today = setsFor(active?.id, liftId);
    if (today.isNotEmpty) return SetDraft(today.last.kgTenths, today.last.reps, false);
    return const SetDraft(200, 8, false);
  }

  void nudge(String liftId, {int kgSteps = 0, int reps = 0}) {
    final draft = draftFor(liftId);
    _nudgeLift = liftId;
    _nudgeSet = loggedCount(liftId) + 1;
    _nudgeKg = (draft.kgTenths + kgSteps * kgStep).clamp(0, 4000);
    _nudgeReps = (draft.reps + reps).clamp(1, 50);
    notifyListeners();
    _save();
  }

  Future<void> init() async {
    final raw = await StorageService.instance.getData(_key);
    _routines.clear();
    _sessions.clear();
    _sets.clear();
    if (raw != null) {
      _routines.addAll(_maps(raw['routines']).map(Routine.fromJson).where((routine) => routine.id.isNotEmpty));
      _sessions.addAll(_maps(raw['sessions']).map(SessionLog.fromJson).where((session) => session.id.isNotEmpty));
      _sets.addAll(_maps(raw['sets']).map(LoggedSet.fromJson).where((set) => set.id.isNotEmpty));
      _selectedId = raw['selected'] as String?;
      _activeId = raw['active'] as String?;
      restEnds = DateTime.tryParse(raw['restEnds'] as String? ?? '');
      restTotal = (raw['restTotal'] as num?)?.toInt() ?? 90;
      restPaused = raw['restPaused'] == true;
      restLeft = (raw['restLeft'] as num?)?.toInt() ?? 0;
      _nudgeLift = raw['nudgeLift'] as String?;
      _nudgeSet = (raw['nudgeSet'] as num?)?.toInt();
      _nudgeKg = (raw['nudgeKg'] as num?)?.toInt();
      _nudgeReps = (raw['nudgeReps'] as num?)?.toInt();
    }
    if (active == null) _activeId = null;
    if (restEnds != null && !restPaused && restRemaining == 0) _clearRest();
    notifyListeners();
  }

  Future<Routine?> createRoutine({
    required String name,
    int restSeconds = 90,
    List<Lift> lifts = const [],
  }) async {
    final title = name.trim();
    if (title.isEmpty || !canAdd) return null;
    final routine = Routine(id: _uuid.v4(), name: title, restSeconds: restSeconds, lifts: lifts);
    _routines.add(routine);
    _selectedId = routine.id;
    await _save();
    notifyListeners();
    return routine;
  }

  Future<void> updateRoutine(Routine routine) async {
    await _save();
    notifyListeners();
  }

  Future<bool> deleteRoutine(String id) async {
    if (active?.routineId == id) return false;
    _routines.removeWhere((routine) => routine.id == id);
    if (_selectedId == id) _selectedId = _routines.isEmpty ? null : _routines.first.id;
    await _save();
    notifyListeners();
    return true;
  }

  Future<void> selectRoutine(String id) async {
    if (active != null) return;
    _selectedId = id;
    await _save();
    notifyListeners();
  }

  Future<void> setRest(String routineId, int seconds) async {
    final routine = findRoutine(routineId);
    if (routine == null) return;
    routine.restSeconds = seconds.clamp(15, 600);
    await _save();
    notifyListeners();
  }

  Future<Routine?> copyRoutine(String id) async {
    final source = findRoutine(id);
    if (source == null || !canAdd) return null;
    return createRoutine(
      name: '${source.name} copy',
      restSeconds: source.restSeconds,
      lifts: [
        for (final lift in source.lifts) Lift(id: _uuid.v4(), name: lift.name, sets: lift.sets, swaps: [...lift.swaps]),
      ],
    );
  }

  Future<Routine?> copyFromSession(String sessionId) async {
    SessionLog? session;
    for (final item in _sessions) {
      if (item.id == sessionId) session = item;
    }
    if (session == null || !canAdd) return null;
    final routine = findRoutine(session.routineId);
    if (routine != null) return copyRoutine(routine.id);
    final names = <String>[];
    final counts = <String, int>{};
    for (final set in _sets.where((set) => set.sessionId == sessionId)) {
      final key = set.name.trim();
      if (key.isEmpty) continue;
      counts[key] = set.index > (counts[key] ?? 0) ? set.index : (counts[key] ?? 0);
      if (!names.contains(key)) names.add(key);
    }
    if (names.isEmpty) return null;
    return createRoutine(
      name: '${session.routineName} copy',
      lifts: [for (final name in names) Lift(id: _uuid.v4(), name: name, sets: counts[name] ?? 1)],
    );
  }

  Future<bool> start({String? routineId, String? basedOn}) async {
    if (active != null) return false;
    final routine = findRoutine(routineId ?? selected?.id ?? '');
    if (routine == null || routine.lifts.isEmpty) return false;
    final session = SessionLog(
      id: _uuid.v4(),
      routineId: routine.id,
      routineName: routine.name,
      started: DateTime.now(),
      basedOn: basedOn,
    );
    _sessions.add(session);
    _activeId = session.id;
    _selectedId = routine.id;
    _clearNudge();
    _clearRest();
    await _save();
    notifyListeners();
    return true;
  }

  Future<LoggedSet?> completeSet(String liftId) async {
    final session = active;
    final lift = findLift(liftId);
    if (session == null || lift == null) return null;
    if (loggedCount(liftId) >= lift.sets) return null;
    final draft = draftFor(liftId);
    final logged = LoggedSet(
      id: _uuid.v4(),
      sessionId: session.id,
      liftId: liftId,
      name: liftName(lift),
      index: loggedCount(liftId) + 1,
      kgTenths: draft.kgTenths,
      reps: draft.reps,
      at: DateTime.now(),
    );
    _sets.add(logged);
    _clearNudge();
    final routine = findRoutine(session.routineId);
    _armRest(routine?.restSeconds ?? 90);
    await _save();
    notifyListeners();
    return logged;
  }

  bool get workoutComplete {
    final session = active;
    final routine = session == null ? null : findRoutine(session.routineId);
    if (routine == null || routine.lifts.isEmpty) return false;
    return routine.lifts.every((lift) => loggedCount(lift.id) >= lift.sets);
  }

  Future<void> endRest() async {
    if (_endingRest) return;
    _endingRest = true;
    _clearRest();
    if (workoutComplete) {
      await finish();
    } else {
      await _save();
      notifyListeners();
    }
    _endingRest = false;
  }

  Future<void> undoLast() async {
    final session = active;
    if (session == null) return;
    final rows = _sets.where((set) => set.sessionId == session.id).toList();
    if (rows.isEmpty) return;
    rows.sort((a, b) => a.at.compareTo(b.at));
    _sets.remove(rows.last);
    _clearNudge();
    _clearRest();
    await _save();
    notifyListeners();
  }

  Future<void> swapLift(String liftId, String name) async {
    final session = active;
    final next = name.trim();
    if (session == null || next.isEmpty) return;
    session.names[liftId] = next;
    _clearNudge();
    await _save();
    notifyListeners();
  }

  Future<void> editSet(String id, {required int kgTenths, required int reps}) async {
    for (final set in _sets) {
      if (set.id != id) continue;
      set.kgTenths = kgTenths.clamp(0, 4000);
      set.reps = reps.clamp(1, 50);
    }
    await _save();
    notifyListeners();
  }

  Future<void> finish() async {
    final session = active;
    if (session == null) return;
    final logged = _sets.any((set) => set.sessionId == session.id);
    if (!logged) {
      _sessions.removeWhere((item) => item.id == session.id);
      _activeId = null;
      _clearRest();
      await _save();
      notifyListeners();
      return;
    }
    session.finished = DateTime.now();
    _activeId = null;
    _clearRest();
    _clearNudge();
    if (!session.rewarded) {
      session.rewarded = true;
      await shop.rewardForWorkout();
    }
    await _save();
    notifyListeners();
  }

  void shiftRest(int seconds) {
    if (!resting && restRemaining == 0 && !restPaused) return;
    if (restPaused) {
      restLeft = (restLeft + seconds).clamp(0, 3600);
    } else if (restEnds != null) {
      restEnds = restEnds!.add(Duration(seconds: seconds));
      if (restRemaining == 0) restEnds = DateTime.now();
    }
    notifyListeners();
    _save();
  }

  void pauseRest() {
    if (restPaused || restEnds == null) return;
    restLeft = restRemaining;
    restPaused = true;
    restEnds = null;
    notifyListeners();
    _save();
  }

  void resumeRest() {
    if (!restPaused) return;
    restPaused = false;
    restEnds = DateTime.now().add(Duration(seconds: restLeft));
    notifyListeners();
    _save();
  }

  Future<void> skipRest() => endRest();

  List<SessionLog> get history {
    final rows = _sessions.where((session) => session.finished != null).toList()
      ..sort((a, b) => b.started.compareTo(a.started));
    return rows;
  }

  int volumeOf(String sessionId) => _sets.where((set) => set.sessionId == sessionId).fold(0, (sum, set) => sum + set.kgTenths * set.reps);

  Map<String, List<LoggedSet>> progressByName() {
    final map = <String, List<LoggedSet>>{};
    final ordered = [..._sets]..sort((a, b) => a.at.compareTo(b.at));
    for (final set in ordered) {
      final key = set.name.trim();
      if (key.isEmpty) continue;
      (map[key] ??= []).add(set);
    }
    return map;
  }

  String exportCsv() {
    final lines = <String>['date,routine,exercise,set,kg,reps'];
    final byId = {for (final session in _sessions) session.id: session};
    final ordered = [..._sets]..sort((a, b) => a.at.compareTo(b.at));
    for (final set in ordered) {
      final session = byId[set.sessionId];
      final date = set.at.toIso8601String();
      final routine = (session?.routineName ?? '').replaceAll(',', ' ');
      final name = set.name.replaceAll(',', ' ');
      lines.add('$date,$routine,$name,${set.index},${kgText(set.kgTenths)},${set.reps}');
    }
    return lines.join('\n');
  }

  void _armRest(int seconds) {
    restTotal = seconds;
    restPaused = false;
    restLeft = seconds;
    restEnds = DateTime.now().add(Duration(seconds: seconds));
  }

  void _clearRest() {
    restEnds = null;
    restPaused = false;
    restLeft = 0;
  }

  void _clearNudge() {
    _nudgeLift = null;
    _nudgeSet = null;
    _nudgeKg = null;
    _nudgeReps = null;
  }

  List<Map<String, dynamic>> _maps(Object? raw) {
    if (raw is! List) return [];
    return raw.whereType<Map>().map((item) => Map<String, dynamic>.from(item)).toList();
  }

  Future<void> _save() async {
    await StorageService.instance.saveData(_key, {
      'routines': _routines.map((routine) => routine.toJson()).toList(),
      'sessions': _sessions.map((session) => session.toJson()).toList(),
      'sets': _sets.map((set) => set.toJson()).toList(),
      'selected': _selectedId,
      'active': _activeId,
      'restEnds': restEnds?.toIso8601String(),
      'restTotal': restTotal,
      'restPaused': restPaused,
      'restLeft': restLeft,
      'nudgeLift': _nudgeLift,
      'nudgeSet': _nudgeSet,
      'nudgeKg': _nudgeKg,
      'nudgeReps': _nudgeReps,
    });
  }
}
