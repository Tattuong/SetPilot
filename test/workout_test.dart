import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:setpilot/core/constants/iap_constants.dart';
import 'package:setpilot/core/services/hive_service.dart';
import 'package:setpilot/core/services/storage_service.dart';
import 'package:setpilot/models/workout.dart';
import 'package:setpilot/providers/gym_provider.dart';
import 'package:setpilot/providers/shop_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory dir;

  setUpAll(() async {
    dir = await Directory.systemTemp.createTemp('sp_gym');
    await HiveService.init(path: dir.path, suffix: '_gym');
    await StorageService.instance.init();
  });

  setUp(() async {
    await HiveService.kv.clear();
  });

  test('kg text and last session prefill the next set', () async {
    expect(kgText(600), '60');
    expect(kgText(625), '62.5');
    final shop = ShopProvider();
    await shop.init(remote: false);
    final gym = GymProvider(shop);
    await gym.init();
    final routine = await gym.createRoutine(name: 'Upper A', lifts: [Lift(id: 'bench', name: 'Barbell Bench Press', sets: 2)]);
    expect(routine, isNotNull);
    expect(await gym.start(), isTrue);
    gym.nudge('bench', kgSteps: 16);
    expect(gym.draftFor('bench').kgTenths, 600);
    final first = await gym.completeSet('bench');
    expect(first?.kgTenths, 600);
    expect(gym.resting, isTrue);
    expect(gym.restRemaining, greaterThan(80));
    await gym.finish();
    expect(gym.active, isNull);

    expect(await gym.start(basedOn: gym.history.first.id), isTrue);
    final draft = gym.draftFor('bench');
    expect(draft.kgTenths, 600);
    expect(draft.reps, 8);
    expect(draft.fromHistory, isTrue);
    expect(gym.previousSet('Barbell Bench Press', 1)?.kgTenths, 600);
  });

  test('last set finishes the workout and the free cap holds', () async {
    final shop = ShopProvider();
    await shop.init(remote: false);
    final gym = GymProvider(shop);
    await gym.init();
    for (var i = 0; i < IapConstants.freeArchiveLimit; i++) {
      expect(await gym.createRoutine(name: 'Day $i', lifts: [Lift(id: 'lift-$i', name: 'Row', sets: 1)]), isNotNull);
    }
    expect(await gym.createRoutine(name: 'Extra', lifts: [Lift(id: 'x', name: 'Row', sets: 1)]), isNull);

    final routine = gym.routines.first;
    for (var i = 0; i < IapConstants.maxDayRewards + 1; i++) {
      expect(await gym.start(routineId: routine.id), isTrue);
      await gym.completeSet(routine.lifts.first.id);
      expect(gym.resting, isTrue);
      await gym.endRest();
      expect(gym.active, isNull);
    }
    expect(shop.coins, IapConstants.testCompleteReward * IapConstants.maxDayRewards);
    expect(gym.history, hasLength(IapConstants.maxDayRewards + 1));
  });

  test('swap uses the substitute and copy keeps the program', () async {
    final shop = ShopProvider();
    await shop.init(remote: false);
    final gym = GymProvider(shop);
    await gym.init();
    final routine = await gym.createRoutine(
      name: 'Upper A',
      lifts: [Lift(id: 'bench', name: 'Barbell Bench Press', sets: 1, swaps: ['Dumbbell Bench Press'])],
    );
    await gym.start();
    await gym.swapLift('bench', 'Dumbbell Bench Press');
    final logged = await gym.completeSet('bench');
    expect(logged?.name, 'Dumbbell Bench Press');
    final copy = await gym.copyRoutine(routine!.id);
    expect(copy?.name, 'Upper A copy');
    expect(copy!.lifts.single.name, 'Barbell Bench Press');
    expect(copy.lifts.single.swaps, ['Dumbbell Bench Press']);
    expect(gym.exportCsv(), contains('Dumbbell Bench Press'));
  });
}