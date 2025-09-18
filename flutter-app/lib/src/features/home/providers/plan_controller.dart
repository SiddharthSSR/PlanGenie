import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/planner_api.dart';

final planControllerProvider = StateNotifierProvider<PlanController, AsyncValue<PlanResponse?>>(
  (ref) {
    final apiClient = ref.watch(plannerApiClientProvider);
    return PlanController(apiClient);
  },
);

class PlanController extends StateNotifier<AsyncValue<PlanResponse?>> {
  PlanController(this._api) : super(const AsyncValue.data(null));

  final PlannerApiClient _api;

  Future<void> createPlan(PlanRequest request) async {
    state = const AsyncValue.loading();
    try {
      final response = await _api.createPlan(request);
      state = AsyncValue.data(response);
    } catch (error, stackTrace) {
      state = AsyncValue.error(error, stackTrace);
    }
  }

  void reset() {
    state = const AsyncValue.data(null);
  }
}
