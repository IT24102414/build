import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:buildwise_mobile/features/auth/screens/login_screen.dart';
import 'package:buildwise_mobile/features/auth/services/auth_service.dart';
import 'package:buildwise_mobile/core/api/api_client.dart';
import 'package:buildwise_mobile/core/widgets/app_button.dart';

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
  Future<bool> isSignedIn() async => true;
  @override
  Future<void> logout() async {}
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
  });
}
