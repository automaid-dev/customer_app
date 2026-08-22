import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/auth/auth_providers.dart';
import '../../../core/models/assign_job_model.dart';
import '../data/merchant_repository.dart';

final merchantRepositoryProvider = Provider<MerchantRepository>((ref) {
  return MerchantRepository(ref.read(apiClientProvider));
});

class MerchantHomeState {
  final bool isDuty;
  final List<AssignJob> today;
  final List<AssignJob> incoming;
  final List<AssignJob> active;

  const MerchantHomeState({
    required this.isDuty,
    required this.today,
    required this.incoming,
    required this.active,
  });
}

final merchantHomeProvider =
    AsyncNotifierProvider.autoDispose<MerchantHomeNotifier, MerchantHomeState>(MerchantHomeNotifier.new);

class MerchantHomeNotifier extends AutoDisposeAsyncNotifier<MerchantHomeState> {
  @override
  Future<MerchantHomeState> build() async {
    final result = await ref.read(merchantRepositoryProvider).home();
    return MerchantHomeState(
      isDuty: result.isDuty,
      today: result.today,
      incoming: result.incoming,
      active: result.active,
    );
  }

  Future<void> toggleDuty(bool isDuty) async {
    await ref.read(merchantRepositoryProvider).updateDuty(isDuty);
    ref.invalidateSelf();
    await future;
  }

  Future<void> acceptJob(int assignId) async {
    await ref.read(merchantRepositoryProvider).acceptOrder(assignId);
    ref.invalidateSelf();
    await future;
  }

  Future<void> receiveBag(int assignId, {String? photoPath, String? remark}) async {
    await ref.read(merchantRepositoryProvider).bagReceive(assignId, photoPath: photoPath, remark: remark);
    ref.invalidateSelf();
    await future;
  }

  Future<void> completeWash(int assignId, {String? photoPath, String? remark}) async {
    await ref.read(merchantRepositoryProvider).washComplete(assignId, photoPath: photoPath, remark: remark);
    ref.invalidateSelf();
    await future;
  }
}

/// Activity/job history — same reasoning as the matching rider provider.
final merchantActivityHistoryProvider = FutureProvider.autoDispose((ref) {
  return ref.read(merchantRepositoryProvider).activityHistory();
});
