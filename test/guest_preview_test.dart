import 'package:Trek/models/guest/guest_sample_trip.dart';
import 'package:Trek/models/services/i_auth_service.dart';
import 'package:Trek/theme/app_theme.dart';
import 'package:Trek/views/guest_preview_screen.dart';
import 'package:Trek/views/login_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

class _FakeAuth extends ChangeNotifier implements IAuthService {
  @override
  int emailCooldownSeconds(EmailActionType action) => 0;

  @override
  bool get isOffline => false;

  @override
  String? consumeSessionMessage() => null;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Widget _app(Widget home, {Map<String, WidgetBuilder>? routes}) =>
    MaterialApp(theme: theme, home: home, routes: routes ?? const {});

void main() {
  group('sample trip data', () {
    test('is self-consistent', () {
      expect(GuestSampleTrip.plannedTotal, lessThanOrEqualTo(GuestSampleTrip.totalBudget));
      expect(
        GuestSampleTrip.spentByCategory.values.fold<double>(0, (a, b) => a + b),
        closeTo(GuestSampleTrip.spentTotal, 0.001),
      );
      expect(
        GuestSampleTrip.remaining,
        closeTo(GuestSampleTrip.totalBudget - GuestSampleTrip.spentTotal, 0.001),
      );
    });

    test('demonstrates an overspent activity', () {
      final overspent = [
        for (final d in GuestSampleTrip.days)
          for (final a in d.activities)
            if (a.isOverspent) a,
      ];
      expect(overspent, isNotEmpty);
    });
  });

  group('GuestPreviewScreen', () {
    testWidgets('shows the sample trip and needs no providers', (tester) async {
      await tester.pumpWidget(_app(const GuestPreviewScreen()));

      expect(find.text('Guest preview'), findsOneWidget);
      expect(find.text('SAMPLE TRIP'), findsOneWidget);
      expect(find.text(GuestSampleTrip.destination), findsOneWidget);

      // The itinerary is further down the scrolling page.
      await tester.scrollUntilVisible(find.text('Nasi kandar breakfast'), 300);
      expect(find.text('DAY 1'), findsOneWidget);
      expect(find.text('Nasi kandar breakfast'), findsOneWidget);
    });

    testWidgets('lays out without overflow on a narrow phone', (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(_app(const GuestPreviewScreen()));
      for (var i = 0; i < 14; i++) {
        await tester.drag(find.byType(ListView), const Offset(0, -450));
        await tester.pump();
        expect(tester.takeException(), isNull, reason: 'scroll step $i');
      }
    });

    testWidgets('sign-up sheet fits on a short screen', (tester) async {
      tester.view.physicalSize = const Size(360, 520);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(_app(const GuestPreviewScreen()));
      final planButton = find.text('Plan my own trip');
      await tester.scrollUntilVisible(planButton, 300);
      await tester.tap(planButton);
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull, reason: 'no overflow');
      expect(find.text('Create a free account to plan your own trip'), findsOneWidget);
    });

    testWidgets('bottom buttons call the sign-up and login callbacks', (tester) async {
      var created = 0;
      var loggedIn = 0;
      await tester.pumpWidget(
        _app(
          GuestPreviewScreen(
            onCreateAccount: () => created++,
            onLogin: () => loggedIn++,
          ),
        ),
      );

      await tester.tap(find.widgetWithText(FilledButton, 'Create free account'));
      await tester.tap(find.widgetWithText(TextButton, 'Log in'));
      expect(created, 1);
      expect(loggedIn, 1);
    });

    testWidgets('"Plan my own trip" asks the guest to sign up instead of planning', (
      tester,
    ) async {
      var created = 0;
      await tester.pumpWidget(
        _app(GuestPreviewScreen(onCreateAccount: () => created++)),
      );

      final planButton = find.text('Plan my own trip');
      await tester.scrollUntilVisible(planButton, 300);
      await tester.tap(planButton);
      await tester.pumpAndSettle();

      expect(find.text('Create a free account to plan your own trip'), findsOneWidget);

      await tester.tap(find.widgetWithText(FilledButton, 'Create free account').last);
      await tester.pumpAndSettle();
      expect(created, 1);
    });
  });

  group('Login screen entry point', () {
    testWidgets('"Explore as a guest" opens the guest preview', (tester) async {
      await tester.pumpWidget(
        ListenableProvider<IAuthService>.value(
          value: _FakeAuth(),
          child: MaterialApp(
            theme: theme,
            routes: {
              '/': (context) => LoginScreen.builder(context),
              '/guest': (context) => GuestPreviewScreen.builder(context),
            },
          ),
        ),
      );
      await tester.pump();

      final guestButton = find.text('Explore as a guest');
      await tester.ensureVisible(guestButton);
      await tester.pump();
      await tester.tap(guestButton);
      await tester.pumpAndSettle();

      expect(find.text('Guest preview'), findsOneWidget);
      expect(find.text('SAMPLE TRIP'), findsOneWidget);
    });
  });
}
