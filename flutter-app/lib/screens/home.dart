import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:plangenie/src/features/auth/providers/auth_providers.dart';
import 'package:plangenie/src/features/home/data/planner_api.dart';
import 'package:plangenie/src/features/home/providers/plan_controller.dart';

class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  final TextEditingController _sourceController =
      TextEditingController(text: 'Bengaluru, IN');
  final TextEditingController _destinationController = TextEditingController();
  final TextEditingController _fromDateController = TextEditingController();
  final TextEditingController _toDateController = TextEditingController();
  final TextEditingController _budgetController = TextEditingController();

  int _travellerCount = 2;

  String _selectedMood = 'Balanced';
  static const List<String> _monthLabels = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _fromDateController.text = _formatDate(now);
    _toDateController.text = _formatDate(now.add(const Duration(days: 4)));
    _budgetController.addListener(_onBudgetChanged);
  }

  @override
  void dispose() {
    _sourceController.dispose();
    _destinationController.dispose();
    _fromDateController.dispose();
    _toDateController.dispose();
    _budgetController
      ..removeListener(_onBudgetChanged)
      ..dispose();
    super.dispose();
  }

  void _onBudgetChanged() => setState(() {});

  String _formatDate(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    return '$day ${_monthLabels[date.month - 1]}, ${date.year}';
  }

  DateTime? _parseDate(String value) {
    final normalized = value.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (normalized.isEmpty) return null;
    final parts = normalized.split(' ');
    if (parts.length != 3) return null;
    final day = int.tryParse(parts[0]);
    final monthToken = parts[1].replaceAll(',', '');
    final monthIndex = _monthLabels.indexWhere(
      (label) => label.toLowerCase() == monthToken.toLowerCase(),
    );
    final year = int.tryParse(parts[2].replaceAll(',', ''));
    if (day == null || monthIndex == -1 || year == null) return null;
    return DateTime(year, monthIndex + 1, day);
  }

  double? get _enteredBudget {
    final raw = _budgetController.text.replaceAll(RegExp(r'[^0-9.]'), '');
    if (raw.isEmpty) return null;
    return double.tryParse(raw);
  }

  Future<void> _pickDate({required bool isStart}) async {
    final now = DateTime.now();
    final currentFrom = _parseDate(_fromDateController.text) ?? now;
    final currentTo = _parseDate(_toDateController.text) ??
        currentFrom.add(const Duration(days: 4));
    final initialDate = isStart
        ? currentFrom
        : (currentTo.isAfter(currentFrom) ? currentTo : currentFrom);
    final firstDate = isStart ? now : currentFrom;
    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: firstDate,
      lastDate: DateTime(now.year + 2),
      builder: (context, child) {
        final colorScheme = Theme.of(context).colorScheme;
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: colorScheme.copyWith(primary: const Color(0xFF2563EB)),
          ),
          child: child ?? const SizedBox.shrink(),
        );
      },
    );

    if (picked == null) {
      return;
    }

    setState(() {
      if (isStart) {
        _fromDateController.text = _formatDate(picked);
        final parsedTo = _parseDate(_toDateController.text) ??
            picked.add(const Duration(days: 2));
        if (parsedTo.isBefore(picked)) {
          final adjusted = picked.add(const Duration(days: 2));
          _toDateController.text = _formatDate(adjusted);
        }
      } else {
        final parsedFrom = _parseDate(_fromDateController.text) ?? now;
        final enforced = picked.isBefore(parsedFrom)
            ? parsedFrom.add(const Duration(days: 2))
            : picked;
        _toDateController.text = _formatDate(enforced);
      }
    });
  }

  void _showInlineFeedback(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(message)),
      );
  }

  int _moodCodeFor(String mood) {
    switch (mood.toLowerCase()) {
      case 'chill':
        return 1;
      case 'adventurous':
        return 3;
      case 'celebratory':
      case 'party':
        return 4;
      case 'balanced':
      default:
        return 2;
    }
  }

  String _formatForApi(DateTime date) {
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '${date.year}-$month-$day';
  }

  void _submitPlan() {
    FocusScope.of(context).unfocus();

    final start = _parseDate(_fromDateController.text);
    final end = _parseDate(_toDateController.text);

    if (start == null || end == null) {
      _showInlineFeedback('Please select a valid travel window.');
      return;
    }

    if (end.isBefore(start)) {
      _showInlineFeedback('End date cannot be before the start date.');
      return;
    }

    final origin = _sourceController.text.trim();
    final destination = _destinationController.text.trim();

    if (origin.isEmpty || destination.isEmpty) {
      _showInlineFeedback('Add both origin and destination.');
      return;
    }

    final planRequest = PlanRequest(
      origin: origin,
      destination: destination,
      startDate: _formatForApi(start),
      endDate: _formatForApi(end),
      pax: _travellerCount,
      budget: (_enteredBudget ?? 25000).round(),
      mood: _moodCodeFor(_selectedMood),
    );

    ref.read(planControllerProvider.notifier).createPlan(planRequest);
  }

  void _handleConciergePrompt(String prompt) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Coming soon: $prompt'),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final parentTheme = Theme.of(context);
    final planState = ref.watch(planControllerProvider);
    final isSubmitting = planState.isLoading;
    final seed = parentTheme.colorScheme.primary;
    final lightScheme = ColorScheme.fromSeed(
      seedColor: seed,
      brightness: Brightness.light,
    );

    return Theme(
      data: ThemeData.light().copyWith(
        colorScheme: lightScheme,
        scaffoldBackgroundColor: const Color(0xFFF8FAFF),
        textTheme: GoogleFonts.poppinsTextTheme(parentTheme.textTheme),
        appBarTheme: parentTheme.appBarTheme.copyWith(
          backgroundColor: Colors.transparent,
          foregroundColor: const Color(0xFF0F172A),
          elevation: 0,
          centerTitle: false,
          surfaceTintColor: Colors.transparent,
        ),
      ),
      child: Scaffold(
        backgroundColor: const Color(0xFFF8FAFF),
        appBar: AppBar(
          titleSpacing: 24,
          title: const _BrandTitle(),
          actions: [
            const _CartAction(),
            const SizedBox(width: 12),
            const _LogoutAction(),
            const SizedBox(width: 12),
            const Padding(
              padding: EdgeInsets.only(right: 24),
              child: _ProfileAction(),
            ),
          ],
        ),
        body: Stack(
          children: [
            const _GradientBackdrop(),
            SafeArea(
              bottom: false,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 36),
                physics: const BouncingScrollPhysics(),
                children: [
                  _FadeSlideIn(
                    child: HeroSection(
                      selectedMood: _selectedMood,
                      onMoodSelected: (mood) =>
                          setState(() => _selectedMood = mood),
                      sourceController: _sourceController,
                      destinationController: _destinationController,
                      fromDateController: _fromDateController,
                      toDateController: _toDateController,
                      travellerCount: _travellerCount,
                      onTravellerCountChanged: (value) =>
                          setState(() => _travellerCount = value),
                      budgetController: _budgetController,
                      onFromDateTap: () => _pickDate(isStart: true),
                      onToDateTap: () => _pickDate(isStart: false),
                      onSubmit: _submitPlan,
                      isSubmitting: isSubmitting,
                    ),
                  ),
                  const SizedBox(height: 28),
                  _FadeSlideIn(child: _ItineraryPreview(state: planState)),
                  const SizedBox(height: 28),
                  const _FadeSlideIn(child: _PopularNowSection()),
                  const SizedBox(height: 28),
                  _FadeSlideIn(
                    child: _AIConciergeSection(
                      onPromptSelected: _handleConciergePrompt,
                    ),
                  ),
                  const SizedBox(height: 28),
                  _FadeSlideIn(
                    child: BudgetSection(budgetValue: _enteredBudget),
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

class _BrandTitle extends StatelessWidget {
  const _BrandTitle();

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Row(
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const LinearGradient(
              colors: [Color(0xFF2563EB), Color(0xFF60A5FA)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          alignment: Alignment.center,
          child: Text(
            '',
            style: textTheme.headlineSmall?.copyWith(fontSize: 24),
          ),
        ),
        const SizedBox(width: 12),
        Text(
          'PlanGenie',
          style: textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w700,
            letterSpacing: -0.3,
          ),
        ),
      ],
    );
  }
}

class _CartAction extends StatelessWidget {
  const _CartAction();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          color: Colors.white,
          border: Border.all(
            color: const Color(0xFF1E3A8A).withValues(alpha: 0.08),
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF1E3A8A).withValues(alpha: 0.08),
              blurRadius: 16,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: IconButton(
          tooltip: 'View travel cart',
          icon: const Icon(Icons.shopping_bag_outlined),
          color: const Color(0xFF1E3A8A),
          onPressed: () {},
        ),
      ),
    );
  }
}

class _LogoutAction extends ConsumerWidget {
  const _LogoutAction();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return IconButton(
      tooltip: 'Log out',
      icon: const Icon(Icons.logout),
      onPressed: () async {
        await ref.read(firebaseAuthProvider).signOut();
      },
    );
  }
}

class _ProfileAction extends StatelessWidget {
  const _ProfileAction();

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(24),
      onTap: () {},
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          gradient: const LinearGradient(
            colors: [Color(0xFFDBEAFE), Color(0xFFEFF6FF)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF2563EB).withValues(alpha: 0.12),
              offset: const Offset(0, 6),
              blurRadius: 18,
            ),
          ],
        ),
        child: const Icon(
          Icons.person_outline,
          color: Color(0xFF1E3A8A),
        ),
      ),
    );
  }
}

class _GradientBackdrop extends StatelessWidget {
  const _GradientBackdrop();

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              const Color(0xFFDBEAFE).withValues(alpha: 0.55),
              Colors.white,
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: CustomPaint(
          painter: _BackdropPainter(),
        ),
      ),
    );
  }
}

class _BackdropPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final gradient = const LinearGradient(
      colors: [Color(0xFF2563EB), Color(0xFF38BDF8)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );

    final paint = Paint()
      ..shader = gradient.createShader(
        Rect.fromLTWH(0, 0, size.width, size.height * 0.6),
      )
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 60)
      ..style = PaintingStyle.fill
      ..color = const Color(0xFF2563EB).withValues(alpha: 0.16);

    final path = Path()
      ..moveTo(-60, size.height * 0.12)
      ..quadraticBezierTo(
        size.width * 0.25,
        size.height * 0.02,
        size.width * 0.52,
        size.height * 0.18,
      )
      ..quadraticBezierTo(
        size.width * 0.8,
        size.height * 0.32,
        size.width + 60,
        size.height * 0.14,
      )
      ..lineTo(size.width + 120, -60)
      ..lineTo(-120, -60)
      ..close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class HeroSection extends StatelessWidget {
  const HeroSection({
    super.key,
    required this.selectedMood,
    required this.onMoodSelected,
    required this.sourceController,
    required this.destinationController,
    required this.fromDateController,
    required this.toDateController,
    required this.travellerCount,
    required this.onTravellerCountChanged,
    required this.budgetController,
    required this.onFromDateTap,
    required this.onToDateTap,
    required this.onSubmit,
    required this.isSubmitting,
  });

  final String selectedMood;
  final ValueChanged<String> onMoodSelected;
  final TextEditingController sourceController;
  final TextEditingController destinationController;
  final TextEditingController fromDateController;
  final TextEditingController toDateController;
  final int travellerCount;
  final ValueChanged<int> onTravellerCountChanged;
  final TextEditingController budgetController;
  final VoidCallback onFromDateTap;
  final VoidCallback onToDateTap;
  final VoidCallback onSubmit;
  final bool isSubmitting;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(32),
        border: Border.all(
          color: const Color(0xFF1E3A8A).withValues(alpha: 0.06),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 38,
            offset: const Offset(0, 28),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Your next adventure, tailored for you',
            style: textTheme.headlineMedium?.copyWith(
              color: const Color(0xFF0F172A),
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Tell us how you feel, pick your vibe, and PlanGenie will craft a seamless escape.',
            style: textTheme.bodyMedium?.copyWith(
              color: const Color(0xFF475569),
              height: 1.5,
            ),
          ),
          const SizedBox(height: 24),
          PlanForm(
            sourceController: sourceController,
            destinationController: destinationController,
            fromDateController: fromDateController,
            toDateController: toDateController,
            travellerCount: travellerCount,
            onTravellerCountChanged: onTravellerCountChanged,
            budgetController: budgetController,
            onFromDateTap: onFromDateTap,
            onToDateTap: onToDateTap,
          ),
          const SizedBox(height: 24),
          LayoutBuilder(
            builder: (context, constraints) {
              final isCompact = constraints.maxWidth < 560;
              final moodColumn = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Popular moods',
                    style: textTheme.labelMedium?.copyWith(
                      color: const Color(0xFF1E3A8A),
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.4,
                    ),
                  ),
                  const SizedBox(height: 10),
                  MoodChips(
                    selected: selectedMood,
                    onSelected: onMoodSelected,
                  ),
                ],
              );

              final ctaButton = SizedBox(
                width: isCompact ? double.infinity : null,
                child: FilledButton(
                  onPressed: isSubmitting ? null : onSubmit,
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 28, vertical: 18),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                    backgroundColor: const Color(0xFF2563EB),
                    foregroundColor: Colors.white,
                    elevation: 4,
                    shadowColor:
                        const Color(0xFF2563EB).withValues(alpha: 0.32),
                    textStyle: textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.2,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (isSubmitting)
                        SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.4,
                            valueColor: const AlwaysStoppedAnimation<Color>(
                              Colors.white,
                            ),
                          ),
                        )
                      else
                        const Icon(Icons.auto_awesome, size: 18),
                      const SizedBox(width: 12),
                      Text(isSubmitting ? 'Planning...' : 'Plan My Trip'),
                    ],
                  ),
                ),
              );

              if (isCompact) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    moodColumn,
                    const SizedBox(height: 18),
                    ctaButton,
                  ],
                );
              }

              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: moodColumn),
                  const SizedBox(width: 24),
                  ctaButton,
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class PlanForm extends StatelessWidget {
  const PlanForm({
    super.key,
    required this.sourceController,
    required this.destinationController,
    required this.fromDateController,
    required this.toDateController,
    required this.travellerCount,
    required this.onTravellerCountChanged,
    required this.budgetController,
    required this.onFromDateTap,
    required this.onToDateTap,
  });

  final TextEditingController sourceController;
  final TextEditingController destinationController;
  final TextEditingController fromDateController;
  final TextEditingController toDateController;
  final int travellerCount;
  final ValueChanged<int> onTravellerCountChanged;
  final TextEditingController budgetController;
  final VoidCallback onFromDateTap;
  final VoidCallback onToDateTap;

  InputDecoration _decor(String label, String hint, IconData icon) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      prefixIcon: Icon(icon, color: const Color(0xFF1D4ED8)),
      filled: true,
      fillColor: const Color(0xFFF1F5F9),
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide.none,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isStacked = constraints.maxWidth < 720;

        Widget buildDateField(TextEditingController controller, String label,
            VoidCallback onTap) {
          return GestureDetector(
            onTap: onTap,
            child: AbsorbPointer(
              child: TextField(
                controller: controller,
                readOnly: true,
                decoration: _decor(
                  label,
                  'Pick $label date',
                  Icons.calendar_today_rounded,
                ),
              ),
            ),
          );
        }

        final dateInputs = isStacked
            ? Column(
                children: [
                  buildDateField(fromDateController, 'From', onFromDateTap),
                  const SizedBox(height: 16),
                  buildDateField(toDateController, 'To', onToDateTap),
                ],
              )
            : Row(
                children: [
                  Expanded(
                    child: buildDateField(
                        fromDateController, 'From', onFromDateTap),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: buildDateField(toDateController, 'To', onToDateTap),
                  ),
                ],
              );

        final travellerBudgetInputs = isStacked
            ? Column(
                children: [
                  _TravellerCounterField(
                    count: travellerCount,
                    onChanged: onTravellerCountChanged,
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: budgetController,
                    decoration: _decor(
                      'Budget',
                      'ÃƒÂ¢Ã¢Â€ÂšÃ‚Â¹ 1,50,000',
                      Icons.account_balance_wallet_outlined,
                    ),
                    keyboardType: TextInputType.number,
                  ),
                ],
              )
            : Row(
                children: [
                  Expanded(
                    child: _TravellerCounterField(
                      count: travellerCount,
                      onChanged: onTravellerCountChanged,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextField(
                      controller: budgetController,
                      decoration: _decor(
                        'Budget',
                        '50,000',
                        Icons.account_balance_wallet_outlined,
                      ),
                      keyboardType: TextInputType.number,
                    ),
                  ),
                ],
              );

        return Column(
          children: [
            TextField(
              controller: sourceController,
              decoration: _decor(
                'Source',
                'Where are you flying from?',
                Icons.flight_takeoff,
              ),
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: destinationController,
              decoration: _decor(
                'Destination',
                'Where to next?',
                Icons.explore,
              ),
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 16),
            dateInputs,
            const SizedBox(height: 16),
            travellerBudgetInputs,
          ],
        );
      },
    );
  }
}

class _TravellerCounterField extends StatelessWidget {
  const _TravellerCounterField({
    required this.count,
    required this.onChanged,
  });

  final int count;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final label = count == 1 ? 'traveller' : 'travellers';

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(18),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      child: Row(
        children: [
          const Icon(Icons.groups_rounded, color: Color(0xFF1D4ED8)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Travellers',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: const Color(0xFF475569),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '$count $label',
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: const Color(0xFF0F172A),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          _TravellerCounterButton(
            icon: Icons.remove_rounded,
            onPressed: count > 1 ? () => onChanged(count - 1) : null,
            semanticLabel: 'Decrease travellers',
          ),
          const SizedBox(width: 8),
          _TravellerCounterButton(
            icon: Icons.add_rounded,
            onPressed: () => onChanged(count + 1),
            semanticLabel: 'Increase travellers',
          ),
        ],
      ),
    );
  }
}

class _TravellerCounterButton extends StatelessWidget {
  const _TravellerCounterButton({
    required this.icon,
    required this.onPressed,
    required this.semanticLabel,
  });

  final IconData icon;
  final VoidCallback? onPressed;
  final String semanticLabel;

  @override
  Widget build(BuildContext context) {
    final isDisabled = onPressed == null;
    final backgroundColor =
        isDisabled ? const Color(0xFFE2E8F0) : const Color(0xFF2563EB);
    final foregroundColor = isDisabled ? const Color(0xFF94A3B8) : Colors.white;

    return Semantics(
      button: true,
      enabled: !isDisabled,
      label: semanticLabel,
      child: Material(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(12),
          child: SizedBox(
            width: 36,
            height: 36,
            child: Center(
              child: Icon(icon, size: 18, color: foregroundColor),
            ),
          ),
        ),
      ),
    );
  }
}

class MoodChips extends StatelessWidget {
  const MoodChips(
      {super.key, required this.selected, required this.onSelected});

  final String selected;
  final ValueChanged<String> onSelected;

  static const _moods = <_MoodOption>[
    _MoodOption('Chill', ''),
    _MoodOption('Balanced', ''),
    _MoodOption('Adventurous', ''),
    _MoodOption('Celebratory', ''),
  ];

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: _moods.map((mood) {
        final isSelected = mood.label == selected;
        return FilterChip(
          selected: isSelected,
          onSelected: (_) => onSelected(mood.label),
          label: Text('${mood.emoji} ${mood.label}'),
          backgroundColor: const Color(0xFFEFF6FF),
          selectedColor: const Color(0xFF2563EB),
          labelStyle: TextStyle(
            color: isSelected ? Colors.white : const Color(0xFF1E3A8A),
            fontWeight: FontWeight.w600,
          ),
          showCheckmark: false,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
        );
      }).toList(),
    );
  }
}

class _ItineraryPreview extends StatelessWidget {
  const _ItineraryPreview({required this.state});

  final AsyncValue<PlanResponse?> state;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Curated itineraries',
          style: textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w700,
            color: const Color(0xFF0F172A),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Swipe through immersive story cards. Detailed itineraries will appear once plans are generated.',
          style: textTheme.bodyMedium?.copyWith(
            color: const Color(0xFF475569),
          ),
        ),
        const SizedBox(height: 22),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 320),
          child: state.when(
            data: (plan) {
              if (plan == null) {
                return const _ItineraryCarousel(
                  key: ValueKey('itinerary-placeholder'),
                );
              }
              return _PlanItineraryCard(
                key: ValueKey('plan-${plan.tripId}'),
                plan: plan,
              );
            },
            loading: () => const _PlanLoadingCard(
              key: ValueKey('plan-loading'),
            ),
            error: (error, _) => _PlanErrorCallout(
              key: const ValueKey('plan-error'),
              error: error,
            ),
          ),
        ),
      ],
    );
  }
}

class _ItineraryCarousel extends StatelessWidget {
  const _ItineraryCarousel({super.key});

  static const _cardCount = 3;

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final viewportHeight = math.min(420.0, math.max(size.height * 0.40, 320.0));
    final cardWidth = math.min(360.0, size.width * 0.78);

    return SizedBox(
      height: viewportHeight,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 4),
        itemCount: _cardCount,
        separatorBuilder: (_, __) => const SizedBox(width: 18),
        itemBuilder: (context, index) {
          return AnimatedContainer(
            duration: const Duration(milliseconds: 320),
            curve: Curves.easeOut,
            child: SizedBox(
              width: cardWidth,
              child: _ItineraryCard(index: index),
            ),
          );
        },
      ),
    );
  }
}

class _ItineraryCard extends StatelessWidget {
  const _ItineraryCard({required this.index});

  final int index;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: const LinearGradient(
          colors: [Color(0xFFFFFFFF), Color(0xFFF5F8FF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 32,
            offset: const Offset(0, 18),
          ),
        ],
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              color: colorScheme.primary.withValues(alpha: 0.08),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _PlaceholderLine(widthFactor: 0.55),
                SizedBox(height: 12),
                _PlaceholderLine(widthFactor: 0.8),
                SizedBox(height: 8),
                _PlaceholderLine(widthFactor: 0.4),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Itinerary ${index + 1}',
            style: textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: const Color(0xFF1E3A8A),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Your personalised trip story will appear here once a plan is generated.',
            style: textTheme.bodyMedium?.copyWith(
              color: const Color(0xFF475569),
              height: 1.4,
            ),
          ),
          const Spacer(),
          OutlinedButton(
            onPressed: () {},
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFF1E3A8A),
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            child: const Text('Stay tuned'),
          ),
        ],
      ),
    );
  }
}

class _PlanLoadingCard extends StatelessWidget {
  const _PlanLoadingCard({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        color: Colors.white,
        border: Border.all(
          color: colorScheme.primary.withValues(alpha: 0.1),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 32,
            offset: const Offset(0, 18),
          ),
        ],
      ),
      child: Row(
        children: [
          SizedBox(
            width: 28,
            height: 28,
            child: CircularProgressIndicator(
              strokeWidth: 3,
              valueColor: AlwaysStoppedAnimation<Color>(
                colorScheme.primary,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              'Drafting your itinerary...',
              style: textTheme.titleMedium?.copyWith(
                color: const Color(0xFF0F172A),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PlanErrorCallout extends StatelessWidget {
  const _PlanErrorCallout({super.key, required this.error});

  final Object error;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        color: const Color(0xFFFFF1F2),
        border: Border.all(
          color: colorScheme.error.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.error_outline, color: colorScheme.error),
              const SizedBox(width: 12),
              Text(
                'We couldn\u2019t draft a plan',
                style: textTheme.titleMedium?.copyWith(
                  color: colorScheme.error,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            error.toString(),
            style: textTheme.bodySmall?.copyWith(
              color: colorScheme.error.withValues(alpha: 0.8),
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

class _PlanItineraryCard extends StatelessWidget {
  const _PlanItineraryCard({super.key, required this.plan});

  final PlanResponse plan;

  @override
  Widget build(BuildContext context) {
    final draft = plan.draft;
    final days = draft.days;
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: const LinearGradient(
          colors: [Color(0xFFFFFFFF), Color(0xFFF5F8FF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 32,
            offset: const Offset(0, 18),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            draft.city.isEmpty ? 'Your itinerary' : draft.city,
            style: textTheme.headlineSmall?.copyWith(
              color: const Color(0xFF1E3A8A),
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Trip ID: ${plan.tripId}',
            style: textTheme.bodySmall?.copyWith(
              color: const Color(0xFF475569),
            ),
          ),
          const SizedBox(height: 18),
          if (days.isEmpty)
            Text(
              'No day-level details were returned yet.',
              style: textTheme.bodyMedium?.copyWith(
                color: const Color(0xFF475569),
              ),
            )
          else
            ...List.generate(
              math.min(3, days.length),
              (index) => _PlanItineraryDay(
                day: days[index],
                index: index,
              ),
            ),
          if (days.length > 3)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                '+ ${days.length - 3} more day(s) in the draft.',
                style: textTheme.bodySmall?.copyWith(
                  color: colorScheme.primary.withValues(alpha: 0.8),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          const SizedBox(height: 24),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton.tonal(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => ItineraryPage(plan: plan),
                  ),
                );
              },
              child: const Text('View Itinerary'),
            ),
          ),
        ],
      ),
    );
  }
}

class _PlanItineraryDay extends StatelessWidget {
  const _PlanItineraryDay({
    required this.day,
    required this.index,
    this.showAllBlocks = false,
  });

  final PlanDay day;
  final int index;
  final bool showAllBlocks;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    final blocks = day.blocks;
    final visibleBlocks =
        showAllBlocks ? blocks : blocks.take(3).toList(growable: false);
    final hasMore = !showAllBlocks && blocks.length > visibleBlocks.length;

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Day ${index + 1} • ${day.date}',
            style: textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
              color: const Color(0xFF1E3A8A),
            ),
          ),
          const SizedBox(height: 10),
          if (blocks.isEmpty)
            Text(
              'No blocks suggested for this day.',
              style: textTheme.bodySmall?.copyWith(
                color: const Color(0xFF475569),
              ),
            )
          else
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ...visibleBlocks.map(
                  (block) => _PlanItineraryBlock(block: block),
                ),
                if (hasMore)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      '+ ${blocks.length - visibleBlocks.length} more suggestion(s).',
                      style: textTheme.bodySmall?.copyWith(
                        color: colorScheme.primary.withValues(alpha: 0.7),
                      ),
                    ),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}

class _PlanItineraryBlock extends StatelessWidget {
  const _PlanItineraryBlock({required this.block});

  final PlanBlock block;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    final time = block.time.isEmpty ? 'Anytime' : block.time;
    final tag = block.tag;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 64,
            child: Text(
              time,
              style: textTheme.labelMedium?.copyWith(
                color: colorScheme.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  block.title,
                  style: textTheme.bodyMedium?.copyWith(
                    color: const Color(0xFF0F172A),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (tag != null && tag.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      '#$tag',
                      style: textTheme.bodySmall?.copyWith(
                        color: const Color(0xFF475569),
                      ),
                    ),
                  ),
                if (block.placeId != null &&
                    block.lat != null &&
                    block.lng != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      'Lat: ${block.lat!.toStringAsFixed(3)}, Lng: ${block.lng!.toStringAsFixed(3)}',
                      style: textTheme.bodySmall?.copyWith(
                        color: const Color(0xFF64748B),
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

class ItineraryPage extends StatelessWidget {
  const ItineraryPage({super.key, required this.plan});

  final PlanResponse plan;

  @override
  Widget build(BuildContext context) {
    final draft = plan.draft;
    final days = draft.days;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Itinerary'),
      ),
      body: SafeArea(
        child: days.isEmpty
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    'We don\'t have day-level details for this plan yet.',
                    textAlign: TextAlign.center,
                    style: textTheme.bodyMedium?.copyWith(
                      color: const Color(0xFF475569),
                    ),
                  ),
                ),
              )
            : ListView(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 36),
                children: [
                  Text(
                    draft.city.isEmpty ? 'Your itinerary' : draft.city,
                    style: textTheme.headlineSmall?.copyWith(
                      color: const Color(0xFF1E3A8A),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Trip ID: ${plan.tripId}',
                    style: textTheme.bodySmall?.copyWith(
                      color: const Color(0xFF475569),
                    ),
                  ),
                  const SizedBox(height: 24),
                  ...List.generate(
                    days.length,
                    (index) => _PlanItineraryDay(
                      day: days[index],
                      index: index,
                      showAllBlocks: true,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

class _PlaceholderLine extends StatelessWidget {
  const _PlaceholderLine({required this.widthFactor});

  final double widthFactor;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.primary.withValues(alpha: 0.12);
    return FractionallySizedBox(
      widthFactor: widthFactor,
      child: Container(
        height: 12,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          color: color,
        ),
      ),
    );
  }
}

class _PopularNowSection extends StatelessWidget {
  const _PopularNowSection();

  static final _packages = [
    const _TourPackage(
      title: 'Cappadocia Sky Trails',
      subtitle: 'Hot-air dawn flights + cave suites',
      price: 'INR 1.9L',
      days: '4N / 5D',
    ),
    const _TourPackage(
      title: 'Kenyan Savannah Magic',
      subtitle: 'Game drives + eco-luxe camps',
      price: 'INR 3.1L',
      days: '6N / 7D',
    ),
    const _TourPackage(
      title: 'Norway Aurora Quest',
      subtitle: 'Glass igloos + fjord cruises',
      price: 'INR 2.5L',
      days: '5N / 6D',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Popular now',
              style: textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
                color: const Color(0xFF0F172A),
              ),
            ),
            TextButton(
              onPressed: () {},
              child: const Text('See all'),
            ),
          ],
        ),
        const SizedBox(height: 18),
        SizedBox(
          height: 210,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 4),
            itemBuilder: (context, index) =>
                _PopularCard(data: _packages[index]),
            separatorBuilder: (_, __) => const SizedBox(width: 16),
            itemCount: _packages.length,
          ),
        ),
      ],
    );
  }
}

class _PopularCard extends StatelessWidget {
  const _PopularCard({required this.data});

  final _TourPackage data;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Container(
      width: 240,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 30,
            offset: const Offset(0, 16),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF93C5FD), Color(0xFF2563EB)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              alignment: Alignment.center,
              child: Text(
                data.title.split(' ').first,
                style: textTheme.titleMedium?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  data.title,
                  style: textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF111827),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  data.subtitle,
                  style: textTheme.bodySmall?.copyWith(
                    color: const Color(0xFF4B5563),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      data.days,
                      style: textTheme.labelMedium?.copyWith(
                        color: const Color(0xFF1E3A8A),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      data.price,
                      style: textTheme.titleSmall?.copyWith(
                        color: const Color(0xFF2563EB),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AIConciergeSection extends StatelessWidget {
  const _AIConciergeSection({required this.onPromptSelected});

  final ValueChanged<String> onPromptSelected;

  static const _prompts = [
    'Draft a 5-day Goa plan',
    'Suggest boutique stays in Kyoto',
    'Where should I go in monsoon?',
  ];

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.all(26),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(30),
        gradient: const LinearGradient(
          colors: [Color(0xFFEEF2FF), Color(0xFFD6E4FF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1D4ED8).withValues(alpha: 0.12),
            blurRadius: 36,
            offset: const Offset(0, 20),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                alignment: Alignment.center,
                child: const Text('', style: TextStyle(fontSize: 24)),
              ),
              const SizedBox(width: 18),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'AI Concierge',
                      style: textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF1E3A8A),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Ask anything routes, stays, hidden gems. Our AI co-traveller answers in seconds.',
                      style: textTheme.bodyMedium?.copyWith(
                        color: const Color(0xFF3F4C6B),
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: _prompts
                .map(
                  (prompt) => _ConciergeQuickChip(
                    label: prompt,
                    onTap: () => onPromptSelected(prompt),
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 20),
          Align(
            alignment: Alignment.centerLeft,
            child: FilledButton(
              onPressed: () => onPromptSelected('Launch concierge chat'),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF1D4ED8),
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: const Text('Launch concierge chat'),
            ),
          ),
        ],
      ),
    );
  }
}

class _ConciergeQuickChip extends StatelessWidget {
  const _ConciergeQuickChip({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return ActionChip(
      onPressed: onTap,
      backgroundColor: Colors.white,
      labelPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(
          color: const Color(0xFF1D4ED8).withValues(alpha: 0.18),
        ),
      ),
      label: Text(
        label,
        style: textTheme.labelLarge?.copyWith(
          color: const Color(0xFF1E3A8A),
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class BudgetSection extends StatelessWidget {
  const BudgetSection({super.key, required this.budgetValue});

  final double? budgetValue;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final hasBudget = budgetValue != null && budgetValue! > 0;
    final total = hasBudget ? budgetValue! : 240000.0;
    final used = hasBudget ? (total * 0.62) : 135000.0;
    final left = (total - used).clamp(0.0, total).toDouble();
    final progress = hasBudget ? (used / total).clamp(0.0, 1.0) : 0.0;

    return Container(
      padding: const EdgeInsets.all(26),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(32),
        color: Colors.white,
        border: Border.all(
          color: const Color(0xFF1E3A8A).withValues(alpha: 0.05),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 32,
            offset: const Offset(0, 18),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  color: const Color(0xFFE2E8FF),
                ),
                alignment: Alignment.center,
                child:
                    const Icon(Icons.wallet_rounded, color: Color(0xFF1D4ED8)),
              ),
              const SizedBox(width: 12),
              Text(
                'Budget pulse',
                style: textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF0F172A),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            hasBudget
                ? 'Track how your spend is pacing against the goal. We\'ll rebalance suggestions if needed.'
                : 'Add your budget to unlock live spend tracking and smart plan adjustments.',
            style: textTheme.bodyMedium?.copyWith(
              color: const Color(0xFF475569),
              height: 1.5,
            ),
          ),
          const SizedBox(height: 22),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 350),
            child: hasBudget
                ? KeyedSubtree(
                    key: const ValueKey('bar'),
                    child: _BudgetProgressBar(value: progress),
                  )
                : Container(
                    key: const ValueKey('placeholder'),
                    height: 16,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      color: const Color(0xFFE2E8F0),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      'Set a budget to activate insights',
                      style: textTheme.labelSmall?.copyWith(
                        color: const Color(0xFF64748B),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
          ),
          const SizedBox(height: 22),
          Row(
            children: [
              Expanded(
                child: _BudgetChip(
                  label: hasBudget ? 'Used so far' : 'Sample used',
                  amount: used,
                  tone: const Color(0xFF2563EB),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _BudgetChip(
                  label: hasBudget ? 'Left to play' : 'Sample left',
                  amount: left,
                  tone: const Color(0xFF22C55E),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _BudgetProgressBar extends StatelessWidget {
  const _BudgetProgressBar({required this.value});

  final double value;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth * value;
        return ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: SizedBox(
            height: 16,
            child: Stack(
              children: [
                Container(color: const Color(0xFFE2E8F0)),
                Align(
                  alignment: Alignment.centerLeft,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 600),
                    curve: Curves.easeOut,
                    width: width,
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Color(0xFF22C55E),
                          Color(0xFFFACC15),
                          Color(0xFFEF4444),
                        ],
                        stops: [0.0, 0.6, 1.0],
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _BudgetChip extends StatelessWidget {
  const _BudgetChip({
    required this.label,
    required this.amount,
    required this.tone,
  });

  final String label;
  final double amount;
  final Color tone;

  String _formatInr(double value) {
    if (value >= 10000000) {
      return 'INR ${(value / 10000000).toStringAsFixed(2)}Cr';
    }
    if (value >= 100000) {
      return 'INR ${(value / 100000).toStringAsFixed(2)}L';
    }
    if (value >= 1000) {
      return 'INR ${(value / 1000).toStringAsFixed(1)}K';
    }
    return 'INR ${value.toStringAsFixed(0)}';
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        color: tone.withValues(alpha: 0.08),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: textTheme.labelLarge?.copyWith(
              color: tone.withValues(alpha: 0.7),
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            _formatInr(amount),
            style: textTheme.headlineSmall?.copyWith(
              color: tone,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _FadeSlideIn extends StatelessWidget {
  const _FadeSlideIn({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 640),
      curve: Curves.easeOutQuint,
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, 22 * (1 - value)),
            child: child,
          ),
        );
      },
      child: child,
    );
  }
}

class _MoodOption {
  const _MoodOption(this.label, this.emoji);

  final String label;
  final String emoji;
}

class _TourPackage {
  const _TourPackage({
    required this.title,
    required this.subtitle,
    required this.price,
    required this.days,
  });

  final String title;
  final String subtitle;
  final String price;
  final String days;
}
