import 'package:flutter/material.dart';

import '../models/guest/guest_sample_trip.dart';
import '../theme/app_theme.dart';

/// Read-only tour of TREK for someone who has not signed up yet.
///
/// It shows a built-in sample trip (itinerary, spending, features) and never
/// talks to Supabase, Gemini or the device, so it works with no account.
/// Anything that would create or save data sends the visitor to sign up.
class GuestPreviewScreen extends StatelessWidget {
  /// Called by "Create free account". Defaults to opening the register screen.
  final VoidCallback? onCreateAccount;

  /// Called by "Log in". Defaults to going back to the login screen.
  final VoidCallback? onLogin;

  const GuestPreviewScreen({super.key, this.onCreateAccount, this.onLogin});

  static Widget builder(BuildContext context) => const GuestPreviewScreen();

  void _createAccount(BuildContext context) {
    if (onCreateAccount != null) {
      onCreateAccount!();
    } else {
      Navigator.pushNamed(context, '/register');
    }
  }

  void _login(BuildContext context) {
    if (onLogin != null) {
      onLogin!();
    } else {
      Navigator.maybePop(context);
    }
  }

  void _promptSignUp(BuildContext context, String action) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      builder: (sheetContext) => SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 4, 24, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Icon(Icons.lock_outline_rounded, size: 34, color: appTheme.teal_A700),
            const SizedBox(height: 12),
            Text(
              'Create a free account to $action',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: appTheme.gray_900,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Guests can explore the sample trip. An account lets you save '
              'your own plans and track your spending.',
              textAlign: TextAlign.center,
              style: TextStyle(color: appTheme.blue_gray_700, height: 1.4),
            ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: () {
                Navigator.pop(sheetContext);
                _createAccount(context);
              },
              child: const Text('Create free account'),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(sheetContext);
                _login(context);
              },
              child: const Text('I already have an account'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: appTheme.gray_50_02,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: appTheme.gray_900,
        elevation: 0,
        title: Row(
          children: [
            Image.asset('assets/logo.png', height: 28),
            const SizedBox(width: 10),
            const Text(
              'Guest preview',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
          const _GuestBanner(),
          const SizedBox(height: 16),
          const _TripSummaryCard(),
          const SizedBox(height: 20),
          const _SectionTitle('Spending so far'),
          const SizedBox(height: 8),
          const _SpendingBreakdown(),
          const SizedBox(height: 20),
          const _SectionTitle('Day-by-day itinerary'),
          const SizedBox(height: 8),
          for (final day in GuestSampleTrip.days) _DayCard(day: day),
          const SizedBox(height: 12),
          const _SectionTitle('What you can do with TREK'),
          const SizedBox(height: 8),
          for (final feature in GuestSampleTrip.features)
            _FeatureCard(feature: feature),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: () => _promptSignUp(context, 'plan your own trip'),
            icon: const Icon(Icons.add_location_alt_outlined),
            label: const Text('Plan my own trip'),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(48),
              foregroundColor: appTheme.teal_700,
              side: BorderSide(color: appTheme.teal_A700),
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border(top: BorderSide(color: appTheme.gray_200)),
          ),
          child: Row(
            children: [
              Expanded(
                child: FilledButton(
                  onPressed: () => _createAccount(context),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(48),
                    backgroundColor: appTheme.teal_A700,
                  ),
                  child: const Text('Create free account'),
                ),
              ),
              const SizedBox(width: 8),
              TextButton(
                onPressed: () => _login(context),
                child: const Text('Log in'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) => Text(
    text,
    style: TextStyle(
      fontSize: 16,
      fontWeight: FontWeight.w700,
      color: appTheme.gray_900,
    ),
  );
}

class _GuestBanner extends StatelessWidget {
  const _GuestBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: appTheme.teal_50.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: appTheme.teal_A700.withValues(alpha: 0.4)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.explore_outlined, color: appTheme.teal_700),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              "You're exploring TREK as a guest. This is a sample trip, so "
              'nothing here is saved. Create a free account to plan your own.',
              style: TextStyle(
                color: appTheme.gray_800,
                height: 1.4,
                fontSize: 13.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

String _money(double value) =>
    '${GuestSampleTrip.currency} ${value.toStringAsFixed(value % 1 == 0 ? 0 : 2)}';

class _TripSummaryCard extends StatelessWidget {
  const _TripSummaryCard();

  @override
  Widget build(BuildContext context) {
    final spent = GuestSampleTrip.spentTotal;
    final total = GuestSampleTrip.totalBudget;
    final ratio = (spent / total).clamp(0.0, 1.0);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: appTheme.gray_200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'SAMPLE TRIP',
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
              color: appTheme.blue_gray_300,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            GuestSampleTrip.destination,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: appTheme.gray_900,
            ),
          ),
          Text(
            '${GuestSampleTrip.dates} · budget ${_money(total)}',
            style: TextStyle(color: appTheme.blue_gray_700),
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: ratio,
              minHeight: 10,
              backgroundColor: appTheme.gray_100,
              color: appTheme.wholeGoodBudgetProgress,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Text(
                  'Spent ${_money(spent)}',
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: appTheme.gray_800,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Flexible(
                child: Text(
                  'Left ${_money(GuestSampleTrip.remaining)}',
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: appTheme.wholeGoodBudgetText,
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

IconData _categoryIcon(String category) {
  switch (category.toLowerCase()) {
    case 'restaurant':
      return Icons.restaurant_rounded;
    case 'transportation':
      return Icons.directions_car_rounded;
    default:
      return Icons.place_rounded;
  }
}

class _SpendingBreakdown extends StatelessWidget {
  const _SpendingBreakdown();

  @override
  Widget build(BuildContext context) {
    final entries = GuestSampleTrip.spentByCategory.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final total = GuestSampleTrip.spentTotal;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: appTheme.gray_200),
      ),
      child: Column(
        children: [
          for (final e in entries)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                children: [
                  Icon(_categoryIcon(e.key), size: 18, color: appTheme.teal_700),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 100,
                    child: Text(e.key, style: TextStyle(color: appTheme.gray_800)),
                  ),
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: total == 0 ? 0 : e.value / total,
                        minHeight: 8,
                        backgroundColor: appTheme.gray_100,
                        color: appTheme.teal_A700,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    _money(e.value),
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _DayCard extends StatelessWidget {
  final GuestSampleDay day;
  const _DayCard({required this.day});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: appTheme.gray_200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'DAY ${day.dayNumber}',
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.5,
                          color: appTheme.teal_700,
                        ),
                      ),
                      Text(
                        day.heading,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: appTheme.gray_900,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: appTheme.amber_200,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'Budget ${_money(day.allocated)}',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: appTheme.lime_900,
                    ),
                  ),
                ),
              ],
            ),
          ),
          for (final a in day.activities) _ActivityTile(activity: a),
          const SizedBox(height: 6),
        ],
      ),
    );
  }
}

class _ActivityTile extends StatelessWidget {
  final GuestSampleActivity activity;
  const _ActivityTile({required this.activity});

  @override
  Widget build(BuildContext context) {
    final spent = activity.spent;
    final overspent = activity.isOverspent;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: appTheme.gray_50_01,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              _categoryIcon(activity.category),
              size: 20,
              color: appTheme.teal_700,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  activity.time,
                  style: TextStyle(fontSize: 12, color: appTheme.blue_gray_300),
                ),
                Text(
                  activity.title,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: appTheme.gray_900,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  activity.note,
                  style: TextStyle(
                    fontSize: 12.5,
                    height: 1.35,
                    color: appTheme.blue_gray_700,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                activity.allocated == 0 ? 'Free' : _money(activity.allocated),
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: appTheme.gray_800,
                ),
              ),
              if (spent != null && activity.allocated > 0)
                Container(
                  margin: const EdgeInsets.only(top: 4),
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: overspent ? appTheme.expenseOverspendBg : appTheme.expenseBg,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    overspent
                        ? 'Over ${_money(spent - activity.allocated)}'
                        : 'Spent ${_money(spent)}',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: overspent
                          ? appTheme.expenseOverspendText
                          : appTheme.expenseText,
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

IconData _featureIcon(String name) {
  switch (name) {
    case 'auto_awesome':
      return Icons.auto_awesome_rounded;
    case 'train':
      return Icons.train_rounded;
    case 'receipt_long':
      return Icons.receipt_long_rounded;
    case 'savings':
      return Icons.savings_rounded;
    default:
      return Icons.star_rounded;
  }
}

class _FeatureCard extends StatelessWidget {
  final GuestFeature feature;
  const _FeatureCard({required this.feature});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: appTheme.gray_200),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: appTheme.teal_50.withValues(alpha: 0.7),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(_featureIcon(feature.icon), color: appTheme.teal_700),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  feature.title,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: appTheme.gray_900,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  feature.description,
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.4,
                    color: appTheme.blue_gray_700,
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
