import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:buildwise_mobile/features/auth/screens/login_screen.dart';
import 'package:buildwise_mobile/features/auth/services/auth_service.dart';
import 'package:buildwise_mobile/core/api/api_client.dart';
import 'package:buildwise_mobile/core/widgets/app_button.dart';
import 'package:buildwise_mobile/features/operations/services/operations_service.dart';
import 'package:buildwise_mobile/main.dart';

class MockApiClient extends ApiClient {
  bool failNextLogin = false;
  Map<String, dynamic> nextLoginUser = {
    'id': 1,
    'email': 'site.engineer@buildwise.demo',
    'fullName': 'Gamini Engineer',
    'roles': ['SiteEngineer'],
  };

  @override
  Future<void> saveSession(String token, Map<String, dynamic> user) async {}

  @override
  Future<String?> readToken() async => 'fake-jwt-token';

  @override
  Future<Map<String, dynamic>?> readUser() async => nextLoginUser;
}

class FakeAuthService extends AuthService {
  FakeAuthService(this.mockApi) : super(apiClient: mockApi);
  final MockApiClient mockApi;

  /// Lets a test choose whether AuthGate should start signed in or signed out.
  bool isSignedInResult = true;

  @override
  Future<Map<String, dynamic>> login(String email, String password) async {
    if (mockApi.failNextLogin || password == 'wrong' || email.isEmpty) {
      throw Exception('Invalid email or password.');
    }
    return {
      'token': 'jwt-token-xyz',
      'user': mockApi.nextLoginUser,
    };
  }

  @override
  Future<Map<String, dynamic>?> currentUser() async => mockApi.nextLoginUser;
  @override
  Future<bool> isSignedIn() async => isSignedInResult;
  @override
  Future<void> logout() async {}
}

/// Returns data immediately so the shell's session load and notification poll
/// complete inside the test's bounded pumps instead of awaiting a real socket.
class StubOperationsService extends OperationsService {
  @override
  Future<List<Map<String, dynamic>>> listNotifications({bool unreadOnly = false}) async =>
      const [];
}

void main() {
  group('Authentication Flow Tests', () {
    testWidgets('LoginScreen renders fields, labels and role shortcuts', (tester) async {
      final mockApi = MockApiClient();
      final authService = FakeAuthService(mockApi);

      await tester.pumpWidget(
        MaterialApp(
          home: LoginScreen(
            onSignedIn: () {},
            authService: authService,
          ),
        ),
      );

      expect(find.text('BuildWise'), findsOneWidget);
      expect(find.text('Sign in'), findsNWidgets(2)); // Card title and button label
      expect(find.text('Email'), findsOneWidget);
      expect(find.text('Password'), findsOneWidget);
      expect(find.text('Quick demo login'), findsOneWidget);
    });

    // The mobile quick-login list must match the web app's exactly. All seven
    // internal roles work on the phone now, so a three-account list would hide
    // four roles from anyone evaluating the mobile build.
    testWidgets('quick demo login offers all seven roles, matching the web app',
        (tester) async {
      final mockApi = MockApiClient();
      final authService = FakeAuthService(mockApi);

      await tester.pumpWidget(
        MaterialApp(
          home: LoginScreen(onSignedIn: () {}, authService: authService),
        ),
      );

      const expected = [
        'Procurement Officer — procurement.officer@buildwise.demo',
        'Procurement Manager — procurement.manager@buildwise.demo',
        'Site Engineer — site.engineer@buildwise.demo',
        'Site Officer — site.officer@buildwise.demo',
        'Site Manager — site.manager@buildwise.demo',
        'Quality Inspector — quality.inspector@buildwise.demo',
        'Administrator — admin@buildwise.demo',
      ];
      for (final account in expected) {
        expect(find.text(account), findsOneWidget, reason: account);
      }

      // The web app's wording, so the two login screens read the same.
      expect(
        find.text('Seeded accounts for evaluation — one per role.'),
        findsOneWidget,
      );
    });

    testWidgets('a demo quick-login fills in the seeded credentials',
        (tester) async {
      final mockApi = MockApiClient()..failNextLogin = false;
      final authService = FakeAuthService(mockApi);
      final emails = <String>[];

      // The default 800x600 test viewport is shorter than the seven-account
      // list, and the page cannot scroll further, so the Administrator row stays
      // off-screen. Use a phone-shaped surface tall enough to hold it.
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        MaterialApp(
          home: LoginScreen(
            onSignedIn: () => emails.add('signed-in'),
            authService: authService,
          ),
        ),
      );

      await tester.tap(
        find.text('Administrator — admin@buildwise.demo'),
      );
      await tester.pumpAndSettle();

      // Tapping a demo account must actually authenticate, not just fill the
      // form — every role has to reach the shell.
      expect(emails, ['signed-in']);
    });

    testWidgets('LoginScreen displays error on invalid credentials', (tester) async {
      final mockApi = MockApiClient()..failNextLogin = true;
      final authService = FakeAuthService(mockApi);

      await tester.pumpWidget(
        MaterialApp(
          home: LoginScreen(
            onSignedIn: () {},
            authService: authService,
          ),
        ),
      );

      final emailField = find.byType(TextField).at(0);
      final passwordField = find.byType(TextField).at(1);
      await tester.enterText(emailField, 'test@example.com');
      await tester.enterText(passwordField, 'wrong');

      await tester.tap(find.byType(AppButton));
      await tester.pumpAndSettle();

      expect(find.text('Invalid email or password.'), findsOneWidget);
    });

    testWidgets('LoginScreen calls onSignedIn on valid login', (tester) async {
      final mockApi = MockApiClient()..failNextLogin = false;
      final authService = FakeAuthService(mockApi);
      bool signedInCalled = false;

      await tester.pumpWidget(
        MaterialApp(
          home: LoginScreen(
            onSignedIn: () => signedInCalled = true,
            authService: authService,
          ),
        ),
      );

      final emailField = find.byType(TextField).at(0);
      final passwordField = find.byType(TextField).at(1);
      await tester.enterText(emailField, 'site.engineer@buildwise.demo');
      await tester.enterText(passwordField, 'Passw0rd!');

      await tester.tap(find.byType(AppButton));
      await tester.pumpAndSettle();

      expect(signedInCalled, isTrue);
    });

    // Regression: AuthGate originally used
    //   void _handleSignedIn() => setState(() => _signedInFuture = Future.value(true));
    // The arrow body is an assignment expression, so it evaluates to a Future.
    // setState then throws "setState() callback argument returned a Future" and
    // sign-in is impossible on a real device. Testing LoginScreen alone could
    // never catch this because the bug lives in AuthGate, not LoginScreen.
    testWidgets('AuthGate transitions to the app shell without throwing on sign in', (tester) async {
      final mockApi = MockApiClient()..failNextLogin = false;
      final authService = FakeAuthService(mockApi)..isSignedInResult = false;

      await tester.pumpWidget(
        MaterialApp(home: AuthGate(authService: authService)),
      );
      await tester.pumpAndSettle();

      // Starts signed out, on the login screen.
      expect(find.text('Quick demo login'), findsOneWidget);

      await tester.enterText(find.byType(TextField).at(0), 'site.engineer@buildwise.demo');
      await tester.enterText(find.byType(TextField).at(1), 'Passw0rd!');
      await tester.tap(find.byType(AppButton));
      // Bounded pumps, not pumpAndSettle: the app shell shows a loading
      // indicator while it fetches from the live API, which never settles here.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // The old code surfaced the setState assertion here; reaching the shell
      // proves the transition completed cleanly.
      expect(tester.takeException(), isNull);
      expect(find.text('Quick demo login'), findsNothing);
      expect(find.byType(MainAppShell), findsOneWidget);
    });

    testWidgets('AuthGate returns to the login screen on sign out', (tester) async {
      final mockApi = MockApiClient();
      final authService = FakeAuthService(mockApi)..isSignedInResult = true;

      await tester.pumpWidget(
        MaterialApp(
          home: AuthGate(
            authService: authService,
            operationsService: StubOperationsService(),
          ),
        ),
      );
      // Bounded pumps: the shell's loading indicator never settles without a
      // live API behind it.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Quick demo login'), findsNothing);

      // "Sign out" is an IconButton tooltip, not a Text widget, so the
      // finder must match the tooltip.
      expect(find.byTooltip('Sign out'), findsOneWidget);
      await tester.tap(find.byTooltip('Sign out'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(tester.takeException(), isNull);
      expect(find.text('Quick demo login'), findsOneWidget);
    });
  });
}
