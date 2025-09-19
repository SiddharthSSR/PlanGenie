import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

class OnboardingRepository {
  OnboardingRepository();

  static const _hasCompletedKey = 'hasCompletedOnboarding';

  Future<bool> hasCompletedOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_hasCompletedKey) ?? false;
  }

  Future<void> setCompleted() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_hasCompletedKey, true);
  }
}

final onboardingRepositoryProvider = Provider<OnboardingRepository>((ref) {
  return OnboardingRepository();
});

final hasCompletedOnboardingProvider =
    FutureProvider<bool>((ref) async {
  final repository = ref.watch(onboardingRepositoryProvider);
  return repository.hasCompletedOnboarding();
});
