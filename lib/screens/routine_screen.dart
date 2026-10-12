import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import '../core/constants/app_colors.dart';
import '../core/constants/app_strings.dart';
import '../core/navigation/app_navigator.dart';
import '../models/workout.dart';
import '../providers/gym_provider.dart';
import '../providers/shop_provider.dart';
import '../widgets/app_toast.dart';
import '../widgets/app_ui.dart';

class RoutineScreen extends StatefulWidget {
  const RoutineScreen({super.key, this.routineId});

  final String? routineId;

  @override
  State<RoutineScreen> createState() => _RoutineScreenState();
}

class _RoutineScreenState extends State<RoutineScreen> {
  final _name = TextEditingController();
  final _rows = <_Row>[];
  int _rest = 90;
  var _ready = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_ready) return;
    _ready = true;
    final routine = widget.routineId == null ? null : context.read<GymProvider>().findRoutine(widget.routineId!);
    _name.text = routine?.name ?? '';
    _rest = routine?.restSeconds ?? 90;
    final lifts = routine?.lifts ?? [Lift(id: const Uuid().v4(), name: '', sets: 3)];
    for (final lift in lifts) {
      _rows.add(_Row(lift.id, lift.name, lift.sets, [...lift.swaps]));
    }
  }

  @override
  void dispose() {
    _name.dispose();
    for (final row in _rows) {
      row.name.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.routineId == null ? 'New routine' : 'Edit routine')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        children: [
          TextField(
            controller: _name,
            textCapitalization: TextCapitalization.characters,
            decoration: const InputDecoration(labelText: 'Routine name'),
          ),
          const SizedBox(height: 16),
          Text('Rest preset', style: AppTypography.labelBold(context: context)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              for (final seconds in [60, 90, 120, 180])
                ChoiceChip(
                  label: Text('$seconds sec'),
                  selected: _rest == seconds,
                  onSelected: (_) => setState(() => _rest = seconds),
                ),
            ],
          ),
          const SizedBox(height: 18),
          for (var i = 0; i < _rows.length; i++) ...[
            _LiftEditor(
              index: i,
              row: _rows[i],
              onChanged: () => setState(() {}),
              onRemove: _rows.length == 1
                  ? null
                  : () => setState(() {
                        _rows.removeAt(i).name.dispose();
                      }),
            ),
            const SizedBox(height: 12),
          ],
          OutlinedButton.icon(
            onPressed: () => setState(() => _rows.add(_Row(const Uuid().v4(), '', 3, []))),
            icon: const Icon(Icons.add),
            label: const Text('Add exercise'),
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _save,
            style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
            child: const Text('Save routine', style: TextStyle(fontWeight: FontWeight.w800)),
          ),
          if (widget.routineId != null)
            TextButton(
              onPressed: _delete,
              child: const Text('Delete routine'),
            ),
        ],
      ),
    );
  }

  Future<void> _save() async {
    final gym = context.read<GymProvider>();
    final lifts = <Lift>[];
    for (final row in _rows) {
      final title = row.name.text.trim();
      if (title.isEmpty) continue;
      lifts.add(Lift(id: row.id, name: title, sets: row.sets, swaps: [...row.swaps]));
    }
    if (_name.text.trim().isEmpty || lifts.isEmpty) {
      AppToast.show(context, title: 'Add a name and one exercise');
      return;
    }
    final existing = widget.routineId == null ? null : gym.findRoutine(widget.routineId!);
    if (existing == null) {
      final created = await gym.createRoutine(name: _name.text, restSeconds: _rest, lifts: lifts);
      if (!mounted) return;
      if (created == null) {
        final shop = context.read<ShopProvider>();
        AppToast.show(context, title: AppStrings.t(context, 'needProFlows', {'n': '${shop.maxArchive}'}), actionLabel: 'Shop', onAction: AppTabs.goShop);
        return;
      }
    } else {
      existing.name = _name.text.trim();
      existing.restSeconds = _rest;
      existing.lifts
        ..clear()
        ..addAll(lifts);
      await gym.updateRoutine(existing);
    }
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _delete() async {
    final id = widget.routineId;
    if (id == null) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete this routine?'),
        content: const Text('Logged workouts stay in History.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete')),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final removed = await context.read<GymProvider>().deleteRoutine(id);
    if (!mounted) return;
    if (!removed) {
      AppToast.show(context, title: 'Finish the workout before deleting it');
      return;
    }
    Navigator.of(context).pop();
  }
}

class _Row {
  _Row(this.id, String name, this.sets, this.swaps) : name = TextEditingController(text: name);

  final String id;
  final TextEditingController name;
  int sets;
  final List<String> swaps;
}

class _LiftEditor extends StatelessWidget {
  const _LiftEditor({required this.index, required this.row, required this.onChanged, required this.onRemove});

  final int index;
  final _Row row;
  final VoidCallback onChanged;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surfaceOf(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderOf(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text((index + 1).toString().padLeft(2, '0'), style: AppTypography.labelBold(context: context)),
              const Spacer(),
              if (onRemove != null) IconButton(onPressed: onRemove, icon: const Icon(Icons.close)),
            ],
          ),
          TextField(
            controller: row.name,
            textCapitalization: TextCapitalization.characters,
            decoration: const InputDecoration(labelText: 'Exercise'),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Text('${row.sets} sets', style: AppTypography.labelBold(context: context)),
              const Spacer(),
              IconButton(
                onPressed: row.sets <= 1 ? null : () { row.sets -= 1; onChanged(); },
                icon: const Icon(Icons.remove),
              ),
              IconButton(
                onPressed: row.sets >= 12 ? null : () { row.sets += 1; onChanged(); },
                icon: const Icon(Icons.add),
              ),
            ],
          ),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final swap in row.swaps)
                InputChip(
                  label: Text(swap),
                  onDeleted: () {
                    row.swaps.remove(swap);
                    onChanged();
                  },
                ),
              ActionChip(
                label: const Text('Add swap'),
                onPressed: () async {
                  final name = await showDialog<String>(context: context, builder: (_) => const _SwapDialog());
                  if (name == null || name.trim().isEmpty) return;
                  row.swaps.add(name.trim());
                  onChanged();
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SwapDialog extends StatefulWidget {
  const _SwapDialog();

  @override
  State<_SwapDialog> createState() => _SwapDialogState();
}

class _SwapDialogState extends State<_SwapDialog> {
  final _text = TextEditingController();

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Substitute exercise'),
      content: TextField(
        controller: _text,
        autofocus: true,
        textCapitalization: TextCapitalization.characters,
        inputFormatters: [LengthLimitingTextInputFormatter(40)],
        decoration: const InputDecoration(hintText: 'Dumbbell bench press'),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(onPressed: () => Navigator.pop(context, _text.text), child: const Text('Add')),
      ],
    );
  }
}
