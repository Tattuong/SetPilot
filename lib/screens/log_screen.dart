import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../core/constants/app_colors.dart';
import '../models/shop_item.dart';
import '../models/workout.dart';
import '../providers/gym_provider.dart';
import '../providers/shop_provider.dart';
import '../widgets/app_toast.dart';
import '../widgets/app_ui.dart';
import 'rest_screen.dart';

class LogScreen extends StatefulWidget {
  const LogScreen({super.key, required this.liftId});

  final String liftId;

  @override
  State<LogScreen> createState() => _LogScreenState();
}

class _LogScreenState extends State<LogScreen> {
  var _awake = false;
  var _leaving = false;
  Timer? _clock;

  @override
  void initState() {
    super.initState();
    _clock = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      if (context.read<ShopProvider>().featureOn(ShopCatalog.featAwake)) {
        _awake = true;
        await WakelockPlus.enable();
      }
    });
  }

  @override
  void dispose() {
    _clock?.cancel();
    if (_awake) WakelockPlus.disable();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final gym = context.watch<GymProvider>();
    final routine = gym.selected;
    final lift = gym.findLift(widget.liftId);
    if (routine == null || lift == null || gym.active == null) {
      if (!_leaving) {
        _leaving = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) Navigator.maybePop(context);
        });
      }
      return const Scaffold(body: SizedBox.shrink());
    }
    final done = gym.setsFor(gym.active!.id, lift.id);
    final draft = gym.draftFor(lift.id);
    final previous = gym.previousSet(gym.liftName(lift), done.length + 1, basedOn: gym.active!.basedOn);
    final elapsed = DateTime.now().difference(gym.active!.started);
    final finishedLift = done.length >= lift.sets;
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 4, 16, 0),
              child: Row(
                children: [
                  IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.arrow_back)),
                  Expanded(child: Text(routine.name.toUpperCase(), style: AppTypography.labelBold(context: context))),
                  Text(clockText(elapsed), style: AppTypography.title(size: 18, context: context)),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                children: [
                  Text(gym.liftName(lift).toUpperCase(), style: AppTypography.archivo(size: 34, weight: FontWeight.w800, height: 0.95, letterSpacing: -0.8, color: AppColors.inkOf(context))),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(onPressed: () => _swap(gym, lift), child: const Text('Swap exercise')),
                  ),
                  Text('SET ${finishedLift ? lift.sets : done.length + 1} OF ${lift.sets}', style: AppTypography.labelBold(size: 12, context: context)),
                  const SizedBox(height: 8),
                  _Pills(total: lift.sets, done: done.length),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Text('LAST TIME', style: AppTypography.labelBold(size: 12, context: context)),
                      const Spacer(),
                      Text(previous == null ? 'No log yet' : '${kgText(previous.kgTenths)} kg × ${previous.reps} reps', style: AppTypography.labelBold(context: context)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (finishedLift)
                    Text('All sets on this exercise are logged.', style: AppTypography.body(size: 15, context: context))
                  else ...[
                    Text('TODAY', style: AppTypography.labelBold(size: 12, context: context)),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(child: _StepperCard(label: 'WEIGHT', value: kgText(draft.kgTenths), unit: 'kg', step: '2.5 kg steps', onMinus: () => gym.nudge(lift.id, kgSteps: -1), onPlus: () => gym.nudge(lift.id, kgSteps: 1))),
                        const SizedBox(width: 10),
                        Expanded(child: _StepperCard(label: 'REPS', value: '${draft.reps}', unit: '', step: '1 rep', onMinus: () => gym.nudge(lift.id, reps: -1), onPlus: () => gym.nudge(lift.id, reps: 1))),
                      ],
                    ),
                  ],
                  const SizedBox(height: 16),
                  Text('COMPLETED SETS TODAY', style: AppTypography.labelBold(size: 12, context: context)),
                  const SizedBox(height: 6),
                  if (done.isEmpty)
                    Text('Nothing logged on this exercise yet.', style: AppTypography.body(size: 13, context: context))
                  else
                    for (final set in done)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text('${set.index.toString().padLeft(2, '0')}    ${kgText(set.kgTenths)} kg × ${set.reps}'),
                        trailing: const Icon(Icons.check),
                        onTap: () => _edit(gym, set),
                      ),
                  TextButton(onPressed: done.isEmpty ? null : () => _edit(gym, done.last), child: const Text('Edit completed sets')),
                  if (!finishedLift)
                    Text(
                      draft.fromHistory ? 'Prefilled from your previous session' : 'Adjust it, then confirm with one tap',
                      textAlign: TextAlign.center,
                      style: AppTypography.body(size: 12, context: context),
                    ),
                ],
              ),
            ),
            if (gym.resting)
              _RestChip(label: clockText(Duration(seconds: gym.restRemaining), padMinutes: true), onOpen: () => _openRest()),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
              child: _CompleteButton(
                dark: dark,
                label: finishedLift ? _nextLabel(gym, routine, lift.id) : 'Complete set',
                caption: finishedLift ? '' : 'Starts your ${routine.restSeconds}-sec rest timer',
                onPressed: () => finishedLift ? _advance(gym, routine, lift.id) : _complete(gym, lift.id),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _nextLabel(GymProvider gym, Routine routine, String liftId) {
    final more = routine.lifts.any((item) => item.id != liftId && gym.loggedCount(item.id) < item.sets);
    return more ? 'Next exercise' : 'Finish workout';
  }

  Future<void> _complete(GymProvider gym, String liftId) async {
    if (context.read<ShopProvider>().featureOn(ShopCatalog.featSound)) {
      await HapticFeedback.mediumImpact();
    }
    final logged = await gym.completeSet(liftId);
    if (!mounted || logged == null) return;
    if (gym.active == null) {
      Navigator.pop(context);
      return;
    }
    await _openRest();
  }

  Future<void> _advance(GymProvider gym, Routine routine, String liftId) async {
    Lift? next;
    final index = routine.lifts.indexWhere((lift) => lift.id == liftId);
    for (var i = 1; i <= routine.lifts.length; i++) {
      final lift = routine.lifts[(index + i) % routine.lifts.length];
      if (gym.loggedCount(lift.id) < lift.sets) {
        next = lift;
        break;
      }
    }
    if (next == null) {
      await gym.finish();
      if (mounted) Navigator.pop(context);
      return;
    }
    if (!mounted) return;
    Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => LogScreen(liftId: next!.id)));
  }

  Future<void> _openRest() {
    return Navigator.of(context).push(MaterialPageRoute(builder: (_) => RestScreen(liftId: widget.liftId)));
  }

  Future<void> _swap(GymProvider gym, Lift lift) async {
    final picks = lift.swaps;
    final chosen = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const ListTile(title: Text('Swap this exercise')),
            if (picks.isEmpty) const ListTile(title: Text('Add substitutes when you edit the routine.')),
            for (final name in picks) ListTile(title: Text(name), onTap: () => Navigator.pop(context, name)),
            ListTile(
              title: const Text('Type another'),
              onTap: () async {
                final typed = await showDialog<String>(context: context, builder: (_) => const _NameDialog());
                if (context.mounted) Navigator.pop(context, typed);
              },
            ),
          ],
        ),
      ),
    );
    if (chosen == null || chosen.trim().isEmpty) return;
    await gym.swapLift(lift.id, chosen);
    if (mounted) AppToast.show(context, title: 'Using $chosen for the rest of this exercise');
  }

  Future<void> _edit(GymProvider gym, LoggedSet set) async {
    final next = await showDialog<(int, int)>(context: context, builder: (_) => _EditSetDialog(kg: set.kgTenths, reps: set.reps));
    if (next == null) return;
    await gym.editSet(set.id, kgTenths: next.$1, reps: next.$2);
  }
}

class _Pills extends StatelessWidget {
  const _Pills({required this.total, required this.done});

  final int total;
  final int done;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var i = 0; i < total; i++) ...[
          if (i > 0) const SizedBox(width: 8),
          _pill(context, i),
        ],
      ],
    );
  }

  Widget _pill(BuildContext context, int index) {
    final current = index == done;
    final complete = index < done;
    final bg = complete ? AppColors.inkOf(context) : current ? AppColors.primary : Colors.transparent;
    final fg = complete || current ? (complete && Theme.of(context).brightness == Brightness.dark ? AppColors.darkBackground : Colors.white) : AppColors.inkOf(context);
    return Container(
      width: 42,
      height: 36,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: current ? AppColors.primary : AppColors.inkOf(context)),
      ),
      child: complete ? Icon(Icons.check, size: 16, color: fg) : Text('${index + 1}'.padLeft(2, '0'), style: TextStyle(color: fg, fontWeight: FontWeight.w800, fontSize: 12)),
    );
  }
}

class _StepperCard extends StatelessWidget {
  const _StepperCard({required this.label, required this.value, required this.unit, required this.step, required this.onMinus, required this.onPlus});

  final String label;
  final String value;
  final String unit;
  final String step;
  final VoidCallback onMinus;
  final VoidCallback onPlus;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
      decoration: BoxDecoration(
        color: AppColors.surfaceOf(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderOf(context)),
      ),
      child: Column(
        children: [
          Text(label, style: AppTypography.labelBold(size: 11, context: context)),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text.rich(
              TextSpan(children: [
                TextSpan(text: value, style: AppTypography.archivo(size: 56, weight: FontWeight.w800, height: 1, color: AppColors.inkOf(context))),
                if (unit.isNotEmpty) TextSpan(text: ' $unit', style: AppTypography.labelBold(context: context)),
              ]),
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              IconButton(onPressed: onMinus, icon: const Icon(Icons.remove), iconSize: 28),
              IconButton(onPressed: onPlus, icon: const Icon(Icons.add), iconSize: 28),
            ],
          ),
          Text(step, style: AppTypography.body(size: 12, context: context)),
        ],
      ),
    );
  }
}

class _CompleteButton extends StatelessWidget {
  const _CompleteButton({required this.dark, required this.label, required this.caption, required this.onPressed});

  final bool dark;
  final String label;
  final String caption;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final bg = dark ? AppColors.darkInk : const Color(0xFF141414);
    final fg = dark ? const Color(0xFF141414) : Colors.white;
    return Column(
      children: [
        Material(
          color: bg,
          borderRadius: BorderRadius.circular(16),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: onPressed,
            child: SizedBox(
              height: 58,
              child: Stack(
                children: [
                  Center(child: Row(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.check, color: fg), const SizedBox(width: 8), Text(label, style: TextStyle(color: fg, fontWeight: FontWeight.w800, fontSize: 18))])),
                  const Positioned(right: 0, bottom: 0, child: _Corner()),
                ],
              ),
            ),
          ),
        ),
        if (caption.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(caption, style: AppTypography.body(size: 12, context: context)),
        ],
      ],
    );
  }
}

class _Corner extends StatelessWidget {
  const _Corner();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(size: const Size(18, 18), painter: _CornerPainter());
  }
}

class _CornerPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(size.width, 0)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(path, Paint()..color = AppColors.primary);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _RestChip extends StatelessWidget {
  const _RestChip({required this.label, required this.onOpen});

  final String label;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
      child: Material(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onOpen,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(
              children: [
                const Icon(Icons.timer_outlined, color: Colors.white),
                const SizedBox(width: 8),
                Text('Rest $label', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
                const Spacer(),
                const Icon(Icons.chevron_right, color: Colors.white),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NameDialog extends StatefulWidget {
  const _NameDialog();

  @override
  State<_NameDialog> createState() => _NameDialogState();
}

class _NameDialogState extends State<_NameDialog> {
  final _text = TextEditingController();

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Swap to'),
      content: TextField(controller: _text, autofocus: true, textCapitalization: TextCapitalization.characters, decoration: const InputDecoration(hintText: 'Exercise name')),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(onPressed: () => Navigator.pop(context, _text.text), child: const Text('Use')),
      ],
    );
  }
}

class _EditSetDialog extends StatefulWidget {
  const _EditSetDialog({required this.kg, required this.reps});

  final int kg;
  final int reps;

  @override
  State<_EditSetDialog> createState() => _EditSetDialogState();
}

class _EditSetDialogState extends State<_EditSetDialog> {
  late int _kg = widget.kg;
  late int _reps = widget.reps;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Edit set'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(onPressed: () => setState(() => _kg = (_kg - GymProvider.kgStep).clamp(0, 4000)), icon: const Icon(Icons.remove)),
              Text('${kgText(_kg)} kg', style: const TextStyle(fontWeight: FontWeight.w800)),
              IconButton(onPressed: () => setState(() => _kg = (_kg + GymProvider.kgStep).clamp(0, 4000)), icon: const Icon(Icons.add)),
            ],
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(onPressed: () => setState(() => _reps = (_reps - 1).clamp(1, 50)), icon: const Icon(Icons.remove)),
              Text('$_reps reps', style: const TextStyle(fontWeight: FontWeight.w800)),
              IconButton(onPressed: () => setState(() => _reps = (_reps + 1).clamp(1, 50)), icon: const Icon(Icons.add)),
            ],
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(onPressed: () => Navigator.pop(context, (_kg, _reps)), child: const Text('Save')),
      ],
    );
  }
}
