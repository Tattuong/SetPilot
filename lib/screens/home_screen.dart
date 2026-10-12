import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../core/constants/app_colors.dart';
import '../core/constants/app_strings.dart';
import '../core/navigation/app_navigator.dart';
import '../models/workout.dart';
import '../providers/gym_provider.dart';
import '../providers/shop_provider.dart';
import '../widgets/ad_banner_slot.dart';
import '../widgets/app_toast.dart';
import '../widgets/app_ui.dart';
import '../widgets/coin_balance_chip.dart';
import 'log_screen.dart';
import 'rest_screen.dart';
import 'routine_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _tab = 0;
  Timer? _clock;

  @override
  void initState() {
    super.initState();
    AppTabs.tabIndex.addListener(_syncTab);
    _clock = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      final gym = context.read<GymProvider>();
      if (!gym.restPaused && gym.restEnds != null && gym.restRemaining == 0) {
        gym.endRest();
        return;
      }
      if (gym.resting || gym.active != null) setState(() {});
    });
  }

  void _syncTab() {
    if (!mounted) return;
    final next = AppTabs.tabIndex.value;
    if (next >= 0 && next < 3 && next != _tab) setState(() => _tab = next);
  }

  void _selectTab(int index) {
    AppTabs.tabIndex.value = index;
    setState(() => _tab = index);
  }

  @override
  void dispose() {
    AppTabs.tabIndex.removeListener(_syncTab);
    _clock?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            const _Header(),
            Expanded(
              child: IndexedStack(
                index: _tab,
                children: [
                  _TrainTab(onHistory: () => _selectTab(1)),
                  const _HistoryTab(),
                  const _ProgressTab(),
                ],
              ),
            ),
            const AdBannerSlot(),
            _Nav(index: _tab, onSelect: _selectTab),
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 8, 0),
      child: Row(
        children: [
          const _Mark(),
          const SizedBox(width: 8),
          Text('SetPilot', style: AppTypography.title(size: 22, context: context)),
          const Spacer(),
          const CoinBalanceChip(variant: CoinChipVariant.header),
          const IconButton(visualDensity: VisualDensity.compact, onPressed: AppTabs.goSettings, icon: Icon(Icons.settings_outlined)),
        ],
      ),
    );
  }
}

class _Mark extends StatelessWidget {
  const _Mark();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 22,
      height: 18,
      child: CustomPaint(painter: _MarkPainter()),
    );
  }
}

class _MarkPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = AppColors.primary;
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(0, 2, 6, size.height), const Radius.circular(2)), paint);
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(9, 0, 6, size.height - 2), const Radius.circular(2)), paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _TrainTab extends StatelessWidget {
  const _TrainTab({required this.onHistory});

  final VoidCallback onHistory;

  @override
  Widget build(BuildContext context) {
    final gym = context.watch<GymProvider>();
    final routine = gym.selected;
    final now = DateTime.now();
    if (routine == null) {
      return ListView(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
        children: [
          Text(_dateLine(now), style: AppTypography.labelBold(size: 12, context: context)),
          const SizedBox(height: 8),
          Text('No routine yet.', style: AppTypography.archivo(size: 36, weight: FontWeight.w800, height: 0.95, color: AppColors.inkOf(context))),
          const SizedBox(height: 8),
          Text('Save a program, then log each set with one tap.', style: AppTypography.body(size: 15, context: context)),
          const SizedBox(height: 20),
          FilledButton(onPressed: () => _openEditor(context), style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)), child: const Text('Create a routine')),
        ],
      );
    }
    final active = gym.active?.routineId == routine.id;
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
      children: [
        Row(
          children: [
            Text(_dateLine(now), style: AppTypography.labelBold(size: 12, context: context)),
            const Spacer(),
            IconButton(onPressed: onHistory, icon: const Icon(Icons.calendar_today_outlined)),
          ],
        ),
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(child: Text(routine.name.toUpperCase(), style: AppTypography.archivo(size: 40, weight: FontWeight.w800, height: 0.95, letterSpacing: -1, color: AppColors.inkOf(context)))),
            IconButton(onPressed: () => _switch(context, gym), icon: const Icon(Icons.chevron_right)),
          ],
        ),
        Row(
          children: [
            Expanded(child: Text('${routine.lifts.length} EXERCISES / ${routine.setCount} SETS / ~${routine.minutes} MIN', maxLines: 2, style: AppTypography.body(size: 12, context: context))),
            TextButton(onPressed: () => _openEditor(context, routine.id), child: const Text('Edit routine')),
          ],
        ),
        const SizedBox(height: 8),
        for (var i = 0; i < routine.lifts.length; i++)
          _LiftRow(index: i, lift: routine.lifts[i], highlight: _highlight(gym, routine, i)),
        const SizedBox(height: 8),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.timer_outlined),
          title: const Text('REST PRESET'),
          trailing: Text('${routine.restSeconds} sec', style: AppTypography.labelBold(context: context)),
          onTap: () => _pickRest(context, gym, routine),
        ),
        if (gym.resting) ...[
          const SizedBox(height: 8),
          FilledButton.icon(
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => RestScreen(liftId: _restLift(gym, routine)))),
            icon: const Icon(Icons.timer_outlined),
            label: Text('Rest ${clockText(Duration(seconds: gym.restRemaining), padMinutes: true)}'),
          ),
        ],
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: () => _start(context, gym, routine),
          icon: Icon(active ? Icons.play_arrow_rounded : Icons.play_arrow_rounded),
          label: Text(active ? 'Continue workout' : 'Start workout', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
          style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(56), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
        ),
        Center(child: TextButton(onPressed: () => _switch(context, gym), child: const Text('Switch routine'))),
        if (active)
          Center(
            child: TextButton(
              onPressed: () => gym.finish(),
              child: const Text('Finish workout'),
            ),
          ),
      ],
    );
  }

  bool _highlight(GymProvider gym, Routine routine, int index) {
    if (gym.active == null) return index == 0;
    for (var i = 0; i < routine.lifts.length; i++) {
      if (gym.loggedCount(routine.lifts[i].id) < routine.lifts[i].sets) return i == index;
    }
    return false;
  }

  Future<void> _start(BuildContext context, GymProvider gym, Routine routine) async {
    if (gym.active == null) {
      final ok = await gym.start(routineId: routine.id);
      if (!ok) {
        if (context.mounted) AppToast.show(context, title: 'Add an exercise before you start');
        return;
      }
    }
    if (!context.mounted) return;
    Lift next = routine.lifts.first;
    for (final lift in routine.lifts) {
      if (gym.loggedCount(lift.id) < lift.sets) {
        next = lift;
        break;
      }
    }
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => LogScreen(liftId: next.id)));
  }
}

class _LiftRow extends StatelessWidget {
  const _LiftRow({required this.index, required this.lift, required this.highlight});

  final int index;
  final Lift lift;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final gym = context.watch<GymProvider>();
    final name = gym.liftName(lift);
    final done = gym.loggedCount(lift.id);
    final previous = gym.previousSet(name, 1, basedOn: gym.active?.basedOn);
    return InkWell(
      onTap: () async {
        if (gym.active == null) {
          final routine = gym.selected;
          if (routine == null) return;
          final ok = await gym.start(routineId: routine.id);
          if (!ok || !context.mounted) return;
        }
        if (!context.mounted) return;
        await Navigator.of(context).push(MaterialPageRoute(builder: (_) => LogScreen(liftId: lift.id)));
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 36,
              height: 36,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: highlight ? AppColors.primary : Colors.transparent,
                shape: BoxShape.circle,
                border: Border.all(color: highlight ? AppColors.primary : AppColors.inkOf(context), width: 1.4),
              ),
              child: Text('${index + 1}'.padLeft(2, '0'), style: TextStyle(color: highlight ? Colors.white : AppColors.inkOf(context), fontWeight: FontWeight.w800, fontSize: 12)),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(child: Text(name.toUpperCase(), style: AppTypography.archivo(size: 18, weight: FontWeight.w800, height: 1.05, color: AppColors.inkOf(context)))),
                      Text(done == 0 ? '${lift.sets} SETS' : '$done/${lift.sets}', style: AppTypography.body(size: 12, context: context)),
                    ],
                  ),
                  Text(previous == null ? 'Last: —' : 'Last: ${kgText(previous.kgTenths)} kg × ${previous.reps}', style: AppTypography.body(size: 13, context: context)),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      for (var i = 0; i < lift.sets; i++)
                        Container(
                          width: 22,
                          height: 14,
                          margin: const EdgeInsets.only(right: 4),
                          decoration: BoxDecoration(
                            color: i < done ? AppColors.inkOf(context) : Colors.transparent,
                            borderRadius: BorderRadius.circular(3),
                            border: Border.all(color: AppColors.inkOf(context).withValues(alpha: 0.45)),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HistoryTab extends StatelessWidget {
  const _HistoryTab();

  @override
  Widget build(BuildContext context) {
    final gym = context.watch<GymProvider>();
    final rows = gym.history;
    if (rows.isEmpty) {
      return Center(child: Text('Finish a workout to see it here.', style: AppTypography.body(size: 15, context: context)));
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
      children: [
        Text('History', style: AppTypography.archivo(size: 32, weight: FontWeight.w800, color: AppColors.inkOf(context))),
        const SizedBox(height: 8),
        for (final session in rows)
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(session.routineName),
            subtitle: Text('${_dateLine(session.started)} · ${gym.sets.where((set) => set.sessionId == session.id).length} sets · ${kgText(gym.volumeOf(session.id))} kg'),
            onTap: () => _open(context, gym, session),
          ),
      ],
    );
  }

  Future<void> _open(BuildContext context, GymProvider gym, SessionLog session) async {
    final host = context;
    final logged = gym.sets.where((set) => set.sessionId == session.id).toList();
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.72),
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
            children: [
              Text(session.routineName.toUpperCase(), style: AppTypography.archivo(size: 28, weight: FontWeight.w800, color: AppColors.inkOf(context))),
              const SizedBox(height: 8),
              for (final set in logged)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text('${set.name}  ${set.index.toString().padLeft(2, '0')}  ${kgText(set.kgTenths)} kg × ${set.reps}', style: AppTypography.body(size: 14, context: context)),
                ),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: () async {
                  Navigator.pop(context);
                  final ok = await gym.start(routineId: session.routineId, basedOn: session.id);
                  if (!host.mounted) return;
                  if (!ok) {
                    AppToast.show(host, title: 'Finish the open workout first, or copy this one');
                    return;
                  }
                  AppTabs.goHome();
                  final routine = gym.findRoutine(session.routineId);
                  if (routine == null || routine.lifts.isEmpty) return;
                  await Navigator.of(host).push(MaterialPageRoute(builder: (_) => LogScreen(liftId: routine.lifts.first.id)));
                },
                child: const Text('Repeat this workout'),
              ),
              TextButton(
                onPressed: () async {
                  final copy = await gym.copyFromSession(session.id);
                  if (!host.mounted) return;
                  Navigator.pop(context);
                  if (copy == null) {
                    final shop = host.read<ShopProvider>();
                    AppToast.show(host, title: AppStrings.t(host, 'needProFlows', {'n': '${shop.maxArchive}'}), actionLabel: 'Shop', onAction: AppTabs.goShop);
                    return;
                  }
                  AppToast.show(host, title: 'Copied ${copy.name}');
                },
                child: const Text('Copy routine'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProgressTab extends StatelessWidget {
  const _ProgressTab();

  @override
  Widget build(BuildContext context) {
    final gym = context.watch<GymProvider>();
    final groups = gym.progressByName();
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
      children: [
        Text('Progress', style: AppTypography.archivo(size: 32, weight: FontWeight.w800, color: AppColors.inkOf(context))),
        const SizedBox(height: 6),
        Text('Best weight from the sessions you logged.', style: AppTypography.body(size: 14, context: context)),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: groups.isEmpty ? null : () => Share.share(gym.exportCsv(), subject: 'SetPilot workouts'),
          icon: const Icon(Icons.ios_share),
          label: const Text('Export data'),
        ),
        const SizedBox(height: 12),
        if (groups.isEmpty)
          Text('Log a set to see a lift move.', style: AppTypography.body(size: 15, context: context))
        else
          for (final entry in groups.entries) _ProgressCard(name: entry.key, sets: entry.value),
      ],
    );
  }
}

class _ProgressCard extends StatelessWidget {
  const _ProgressCard({required this.name, required this.sets});

  final String name;
  final List<LoggedSet> sets;

  @override
  Widget build(BuildContext context) {
    final byDay = <String, int>{};
    for (final set in sets) {
      final key = '${set.at.year}-${set.at.month}-${set.at.day}';
      final best = byDay[key] ?? 0;
      if (set.kgTenths > best) byDay[key] = set.kgTenths;
    }
    final points = byDay.values.toList();
    final recent = points.length > 6 ? points.sublist(points.length - 6) : points;
    final peak = recent.fold<int>(0, (max, value) => value > max ? value : max);
    final last = sets.last;
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(name.toUpperCase(), style: AppTypography.labelBold(size: 16, context: context)),
          Text('Latest ${kgText(last.kgTenths)} kg × ${last.reps}', style: AppTypography.body(size: 13, context: context)),
          const SizedBox(height: 6),
          SizedBox(
            height: 36,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (final value in recent)
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 2),
                      child: FractionallySizedBox(
                        heightFactor: peak == 0 ? 0.08 : (value / peak).clamp(0.08, 1.0),
                        child: DecoratedBox(decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(3))),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Nav extends StatelessWidget {
  const _Nav({required this.index, required this.onSelect});

  final int index;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    const labels = ['Train', 'History', 'Progress'];
    const icons = [Icons.fitness_center, Icons.history, Icons.bar_chart_rounded];
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 6, top: 4),
        child: Row(
          children: [
            for (var i = 0; i < labels.length; i++)
              Expanded(
                child: InkWell(
                  onTap: () => onSelect(i),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(icons[i], color: index == i ? AppColors.primary : AppColors.mutedInk(context)),
                      Text(labels[i], style: TextStyle(fontWeight: index == i ? FontWeight.w800 : FontWeight.w600, fontSize: 12, color: index == i ? AppColors.primary : AppColors.mutedInk(context))),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

String _dateLine(DateTime date) {
  const days = ['MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT', 'SUN'];
  const months = ['JAN', 'FEB', 'MAR', 'APR', 'MAY', 'JUN', 'JUL', 'AUG', 'SEP', 'OCT', 'NOV', 'DEC'];
  return '${days[date.weekday - 1]}, ${months[date.month - 1]} ${date.day.toString().padLeft(2, '0')}';
}

Future<void> _openEditor(BuildContext context, [String? id]) {
  return Navigator.of(context).push(MaterialPageRoute(builder: (_) => RoutineScreen(routineId: id)));
}

String _restLift(GymProvider gym, Routine routine) {
  for (final lift in routine.lifts) {
    if (gym.loggedCount(lift.id) < lift.sets) return lift.id;
  }
  return routine.lifts.last.id;
}

Future<void> _switch(BuildContext context, GymProvider gym) async {
  if (gym.active != null) {
    AppToast.show(context, title: 'Finish this workout before switching');
    return;
  }
  final host = context;
  await showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (context) => SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.72),
        child: ListView(
          shrinkWrap: true,
          children: [
            for (final routine in gym.routines)
              ListTile(title: Text(routine.name), onTap: () { gym.selectRoutine(routine.id); Navigator.pop(context); }),
            ListTile(
              leading: const Icon(Icons.add),
              title: const Text('New routine'),
              onTap: () {
                Navigator.pop(context);
                _openEditor(host);
              },
            ),
          ],
        ),
      ),
    ),
  );
}

Future<void> _pickRest(BuildContext context, GymProvider gym, Routine routine) async {
  await showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (context) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final seconds in [60, 90, 120, 180])
            ListTile(title: Text('$seconds sec'), onTap: () { gym.setRest(routine.id, seconds); Navigator.pop(context); }),
        ],
      ),
    ),
  );
}
