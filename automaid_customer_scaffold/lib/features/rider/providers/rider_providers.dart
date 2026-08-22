import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/auth/auth_providers.dart';
import '../../../core/models/assign_job_model.dart';
import '../data/rider_repository.dart';

final riderRepositoryProvider = Provider<RiderRepository>((ref) {
  return RiderRepository(ref.read(apiClientProvider));
});

class RiderHomeState {
  final bool isDuty;
  final List<AssignJob> today;
  final List<AssignJob> incoming;
  final List<AssignJob> active;

  const RiderHomeState({
    required this.isDuty,
    required this.today,
    required this.incoming,
    required this.active,
  });
}

final riderHomeProvider =
    AsyncNotifierProvider.autoDispose<RiderHomeNotifier, RiderHomeState>(RiderHomeNotifier.new);

class RiderHomeNotifier extends AutoDisposeAsyncNotifier<RiderHomeState> {
  @override
  Future<RiderHomeState> build() async {
    final result = await ref.read(riderRepositoryProvider).home();
    return RiderHomeState(
      isDuty: result.isDuty,
      today: result.today,
      incoming: result.incoming,
      active: result.active,
    );
  }

  Future<void> toggleDuty(bool isDuty) async {
    await ref.read(riderRepositoryProvider).updateDuty(isDuty);
    ref.invalidateSelf();
    await future;
  }

  Future<void> acceptJob(int assignId) async {
    await ref.read(riderRepositoryProvider).acceptOrder(assignId);
    ref.invalidateSelf();
    await future;
  }

  Future<void> confirmPickup(int assignId, {String? photoPath, String? remark}) async {
    await ref.read(riderRepositoryProvider).pickupOrder(assignId, photoPath: photoPath, remark: remark);
    ref.invalidateSelf();
    await future;
  }

  Future<void> confirmPickupFromOutlet(int assignId, {String? photoPath, String? remark}) async {
    await ref.read(riderRepositoryProvider).pickupWashOutletConfirm(assignId, photoPath: photoPath, remark: remark);
    ref.invalidateSelf();
    await future;
  }

  Future<void> confirmDelivery(int assignId, {required String photoPath, String? remark}) async {
    await ref.read(riderRepositoryProvider).deliveryConfirm(assignId, photoPath: photoPath, remark: remark);
    ref.invalidateSelf();
    await future;
  }
}

/// Activity/job history — separate from riderHomeProvider (today/incoming
/// active jobs only) since this covers everything including cancelled
/// and completed jobs, which the home dashboard was never meant to show.
final riderActivityHistoryProvider = FutureProvider.autoDispose((ref) {
  return ref.read(riderRepositoryProvider).activityHistory();
});
