import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/providers/auth_providers.dart';
import 'data/planner_api.dart';
import 'providers/plan_controller.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('PlanGenie'),
        actions: [
          IconButton(
            tooltip: 'Sign out',
            onPressed: () => ref.read(firebaseAuthProvider).signOut(),
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: const _HomeBody(),
    );
  }
}

class _HomeBody extends ConsumerStatefulWidget {
  const _HomeBody();

  @override
  ConsumerState<_HomeBody> createState() => _HomeBodyState();
}

class _HomeBodyState extends ConsumerState<_HomeBody> {
  late final TextEditingController _originController;
  late final TextEditingController _destinationController;
  late DateTime _startDate;
  late DateTime _endDate;
  int _mood = 2;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _startDate = DateTime(now.year, now.month, now.day);
    _endDate = _startDate.add(const Duration(days: 2));
    _originController = TextEditingController(text: 'DEL');
    _destinationController = TextEditingController(text: 'JAI');
  }

  @override
  void dispose() {
    _originController.dispose();
    _destinationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final mediaQuery = MediaQuery.of(context);
    final planState = ref.watch(planControllerProvider);
    final backendUri = ref.watch(backendBaseUriProvider);

    final isWide = mediaQuery.size.width >= 720;
    final horizontalPadding = isWide ? mediaQuery.size.width * 0.12 : 24.0;
    final verticalSpacing = mediaQuery.size.height >= 720 ? 32.0 : 20.0;

    return Align(
      alignment: Alignment.topCenter,
      child: SingleChildScrollView(
        padding: EdgeInsets.symmetric(
          horizontal: horizontalPadding,
          vertical: verticalSpacing,
        ),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: isWide ? 720 : double.infinity),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Icon(
                  Icons.map_outlined,
                  size: isWide ? 120 : 80,
                  color: colorScheme.primary,
                ),
              ),
              SizedBox(height: verticalSpacing),
              Text(
                'Plan an AI-assisted itinerary',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 12),
              Text(
                'Enter an origin and destination, then send a request to the backend. Dates default to the next three days and can be adjusted.',
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              const SizedBox(height: 24),
              Card(
                clipBehavior: Clip.antiAlias,
                elevation: 2,
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildBackendInfo(backendUri.toString(), context),
                      const SizedBox(height: 24),
                      TextField(
                        controller: _originController,
                        textInputAction: TextInputAction.next,
                        decoration: const InputDecoration(
                          labelText: 'Origin airport/city code',
                          hintText: 'e.g. DEL',
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _destinationController,
                        textInputAction: TextInputAction.done,
                        decoration: const InputDecoration(
                          labelText: 'Destination airport/city code',
                          hintText: 'e.g. JAI',
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () => _pickDate(isStart: true),
                              icon: const Icon(Icons.calendar_today),
                              label: Text('Start: ${_formatDate(_startDate)}'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () => _pickDate(isStart: false),
                              icon: const Icon(Icons.calendar_today_outlined),
                              label: Text('End: ${_formatDate(_endDate)}'),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<int>(
                        value: _mood,
                        decoration: const InputDecoration(
                          labelText: 'Travel mood',
                        ),
                        items: const [
                          DropdownMenuItem(value: 1, child: Text('1 – Chill')),
                          DropdownMenuItem(value: 2, child: Text('2 – Balanced')),
                          DropdownMenuItem(value: 3, child: Text('3 – Adventurous')),
                          DropdownMenuItem(value: 4, child: Text('4 – Party')),
                        ],
                        onChanged: planState.isLoading
                            ? null
                            : (value) {
                                if (value == null) return;
                                setState(() {
                                  _mood = value;
                                });
                              },
                      ),
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          icon: const Icon(Icons.send),
                          label: const Text('Request plan from backend'),
                          onPressed: planState.isLoading ? null : _submit,
                        ),
                      ),
                      const SizedBox(height: 24),
                      _PlanStateView(state: planState),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _submit() {
    FocusScope.of(context).unfocus();
    final origin = _originController.text.trim();
    final destination = _destinationController.text.trim();

    if (origin.isEmpty || destination.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Origin and destination are required.')),
      );
      return;
    }

    if (!_startDate.isBefore(_endDate) && _startDate != _endDate) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('End date must be on or after the start date.')),
      );
      return;
    }

    final planRequest = PlanRequest(
      origin: origin,
      destination: destination,
      startDate: _formatDate(_startDate),
      endDate: _formatDate(_endDate),
      pax: 2,
      budget: 25000,
      mood: _mood,
    );

    ref.read(planControllerProvider.notifier).createPlan(planRequest);
  }

  Future<void> _pickDate({required bool isStart}) async {
    final initialDate = isStart ? _startDate : _endDate;
    final firstDate = isStart ? DateTime.now().subtract(const Duration(days: 1)) : _startDate;
    final lastDate = DateTime.now().add(const Duration(days: 365));

    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: firstDate,
      lastDate: lastDate,
    );

    if (picked == null) {
      return;
    }

    setState(() {
      if (isStart) {
        _startDate = DateTime(picked.year, picked.month, picked.day);
        if (_endDate.isBefore(_startDate)) {
          _endDate = _startDate;
        }
      } else {
        _endDate = DateTime(picked.year, picked.month, picked.day);
        if (_endDate.isBefore(_startDate)) {
          _startDate = _endDate;
        }
      }
    });
  }

  String _formatDate(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

  Widget _buildBackendInfo(String baseUrl, BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Backend connection',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 4),
        Text(
          baseUrl,
          style: Theme.of(context)
              .textTheme
              .bodyMedium
              ?.copyWith(color: Theme.of(context).colorScheme.primary),
        ),
        const SizedBox(height: 8),
        Text(
          'Override by running the app with --dart-define=PLANGENIE_API_BASE_URL=...',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }
}

class _PlanStateView extends StatelessWidget {
  const _PlanStateView({required this.state});

  final AsyncValue<PlanResponse?> state;

  @override
  Widget build(BuildContext context) {
    return state.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => _PlanErrorMessage(error: error),
      data: (PlanResponse? response) {
        if (response == null) {
          return Text(
            'Press the button above to draft a plan.',
            style: Theme.of(context).textTheme.bodyMedium,
          );
        }
        return _PlanResultView(response: response);
      },
    );
  }
}

class _PlanErrorMessage extends StatelessWidget {
  const _PlanErrorMessage({required this.error});

  final Object error;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Something went wrong',
          style: Theme.of(context)
              .textTheme
              .titleMedium
              ?.copyWith(color: Theme.of(context).colorScheme.error),
        ),
        const SizedBox(height: 8),
        Text(
          error.toString(),
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }
}

class _PlanResultView extends StatelessWidget {
  const _PlanResultView({required this.response});

  final PlanResponse response;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final days = response.draft.days;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Trip ID: ${response.tripId}', style: textTheme.titleMedium),
        const SizedBox(height: 8),
        Text('City: ${response.draft.city}', style: textTheme.bodyLarge),
        const SizedBox(height: 16),
        if (days.isEmpty)
          Text(
            'No day-level details were returned.',
            style: textTheme.bodyMedium,
          )
        else
          ...days.map((day) => _PlanDayTile(day: day)).take(3),
      ],
    );
  }
}

class _PlanDayTile extends StatelessWidget {
  const _PlanDayTile({required this.day});

  final PlanDay day;

  @override
  Widget build(BuildContext context) {
    final blocks = day.blocks;
    final textTheme = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('• ${day.date}', style: textTheme.titleSmall),
          if (blocks.isEmpty)
            Padding(
              padding: const EdgeInsets.only(left: 16.0, top: 4.0),
              child: Text('No blocks suggested for this day.', style: textTheme.bodySmall),
            )
          else
            Padding(
              padding: const EdgeInsets.only(left: 16.0, top: 4.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: blocks.take(3).map((block) {
                  final time = block.time.isEmpty ? 'Anytime' : block.time;
                  final tag = block.tag == null ? '' : ' • ${block.tag}';
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 4.0),
                    child: Text('$time – ${block.title}$tag', style: textTheme.bodySmall),
                  );
                }).toList(),
              ),
            ),
        ],
      ),
    );
  }
}
