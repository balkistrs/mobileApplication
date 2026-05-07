import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:resto_app/main.dart';
import 'package:resto_app/providers/auth_provider.dart';
import 'package:resto_app/screens/login_screen.dart';

void main() {
  testWidgets('Test de l\'écran de connexion', (WidgetTester tester) async {
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => AuthProvider()),
        ],
        child: const MaterialApp(home: LoginScreen()),
      ),
    );

    expect(find.text('Smart Resto Pro'), findsOneWidget);
    expect(find.byType(TextFormField), findsNWidgets(2));
    expect(find.byType(ElevatedButton), findsOneWidget);
  });

  testWidgets('Test du formulaire vide', (WidgetTester tester) async {
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => AuthProvider()),
        ],
        child: const MaterialApp(home: LoginScreen()),
      ),
    );

    await tester.tap(find.byType(ElevatedButton));
    await tester.pump();

    expect(find.text('Email requis'), findsOneWidget);
    expect(find.text('Mot de passe requis'), findsOneWidget);
  });
}