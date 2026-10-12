import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/constants/app_colors.dart';
import '../models/workout.dart';
import '../providers/gym_provider.dart';
import '../widgets/app_ui.dart';

class RestScreen extends StatefulWidget {
  const RestScreen({super.key, required this.liftId});

  final String liftId;

  @override
  State<RestScreen> createState() => _RestScreenState();
}

class _RestScreenState extends State<RestScreen> {
  Timer? _timer;
  var _closed = false;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(milliseconds: 250), (_) {
      if (!mounted || _closed) return;
      final gym = context.read<GymProvider>();
      if (!gym.restPaused && gym.restRemaining == 0 && gym.restEnds != null) {
        gym.endRest();
        _close();
        return;
      }
      setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _close() {
    if (_closed || !mounted) return;
    _closed = true;
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final gym = context.watch<GymProvider>();
    final routine = gym.selected;
    final lift = gym.findLift(widget.liftId);
    final session = gym.active;
    if (routine == null || lift == null || session == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _close());
      return const Scaffold(backgroundColor: Color(0xFF111110), body: SizedBox.shrink());
    }
    final done = gym.setsFor(session.id, lift.id);
    final last = done.isEmpty ? null : done.last;
    final next = _upcoming(gym, routine, lift);
    final left = gym.restRemaining;
    final total = gym.restTotal <= 0 ? 1 : gym.restTotal;
    final progress = (1 - left / total).clamp(0.0, 1.0);
    return Scaffold(
      backgroundColor: const Color(0xFF111110),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  IconButton(onPressed: _close, icon: const Icon(Icons.arrow_back, color: Colors.white)),
                  const Text('Workout', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                  const Spacer(),
                  const Text('REST MODE', style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w800, letterSpacing: 0.6)),
                ],
              ),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      last == null ? 'Set saved' : 'Set ${last.index} saved · ${kgText(last.kgTenths)} kg × ${last.reps}',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
                    ),
                  ),
                  TextButton(onPressed: () async { await gym.undoLast(); _close(); }, child: const Text('Undo')),
                ],
              ),
              const Spacer(),
              Center(child: Text(clockText(Duration(seconds: left), padMinutes: true), style: AppTypography.archivo(size: 84, weight: FontWeight.w800, height: 0.9, color: Colors.white))),
              Center(child: Text('of ${clockText(Duration(seconds: gym.restTotal), padMinutes: true)} remaining', style: const TextStyle(color: Colors.white70))),
              const SizedBox(height: 16),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(value: progress, minHeight: 8, color: AppColors.primary, backgroundColor: const Color(0xFF3A3836)),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  _RestKey(label: '-15 sec', onTap: () => gym.shiftRest(-15)),
                  const SizedBox(width: 8),
                  _RestKey(label: gym.restPaused ? 'Resume' : 'Pause', onTap: () => gym.restPaused ? gym.resumeRest() : gym.pauseRest()),
                  const SizedBox(width: 8),
                  _RestKey(label: '+15 sec', onTap: () => gym.shiftRest(15)),
                ],
              ),
              const Spacer(),
              if (next != null) ...[
                const Text('UP NEXT', style: TextStyle(color: Colors.white54, fontWeight: FontWeight.w800, fontSize: 12)),
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(color: const Color(0xFFF7F4EF), borderRadius: BorderRadius.circular(16)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(next.name.toUpperCase(), style: AppTypography.archivo(size: 22, weight: FontWeight.w800, color: const Color(0xFF141414))),
                      Text('${kgText(next.kg)} kg × ${next.reps}', style: AppTypography.archivo(size: 28, weight: FontWeight.w800, color: const Color(0xFF141414))),
                      const Text('Planned from last session', style: TextStyle(color: Color(0xFF667085))),
                      const SizedBox(height: 8),
                      _Pills(total: next.total, done: next.done, current: next.done),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: () async { await gym.endRest(); _close(); },
                icon: const Icon(Icons.fast_forward_rounded),
                label: const Text('Skip rest', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
                style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(56), backgroundColor: AppColors.primary, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
              ),
              const SizedBox(height: 8),
              const Center(child: Text('Next set stays unlogged until you confirm.', style: TextStyle(color: Colors.white54, fontSize: 12))),
            ],
          ),
        ),
      ),
    );
  }

  _Next? _upcoming(GymProvider gym, Routine routine, Lift lift) {
    if (gym.loggedCount(lift.id) < lift.sets) {
      final draft = gym.draftFor(lift.id);
      return _Next(gym.liftName(lift), draft.kgTenths, draft.reps, lift.sets, gym.loggedCount(lift.id));
    }
    for (final item in routine.lifts) {
      if (gym.loggedCount(item.id) < item.sets) {
        final draft = gym.draftFor(item.id);
        return _Next(gym.liftName(item), draft.kgTenths, draft.reps, item.sets, gym.loggedCount(item.id));
      }
    }
    return null;
  }
}

class _Next {
  const _Next(this.name, this.kg, this.reps, this.total, this.done);

  final String name;
  final int kg;
  final int reps;
  final int total;
  final int done;
}

class _Pills extends StatelessWidget {
  const _Pills({required this.total, required this.done, required this.current});

  final int total;
  final int done;
  final int current;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var i = 0; i < total; i++) ...[
          if (i > 0) const SizedBox(width: 6),
          Container(
            width: 32,
            height: 28,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: i < done ? const Color(0xFF141414) : i == current ? AppColors.primary : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: i == current ? AppColors.primary : const Color(0xFF141414)),
            ),
            child: i < done
                ? const Icon(Icons.check, size: 14, color: Colors.white)
                : Text('${i + 1}'.padLeft(2, '0'), style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: i == current ? Colors.white : const Color(0xFF141414))),
          ),
        ],
      ],
    );
  }
}

class _RestKey extends StatelessWidget {
  const _RestKey({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Material(
        color: const Color(0xFF2A2826),
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: SizedBox(height: 64, child: Center(child: Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800)))),
        ),
      ),
    );
  }
}
