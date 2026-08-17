import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fzu_assistant/router/app_routes.dart';

void main() {
  testWidgets('pushNamed forwards arguments and returns the route result', (
    tester,
  ) async {
    Object? receivedArguments;
    String? result;

    await tester.pumpWidget(
      MaterialApp(
        onGenerateRoute: (settings) {
          receivedArguments = settings.arguments;
          return MaterialPageRoute<String>(
            settings: settings,
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => Navigator.pop(context, 'done'),
                child: const Text('Close'),
              ),
            ),
          );
        },
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async {
                result = await context.pushNamed<String>(
                  '/target',
                  arguments: 42,
                );
              },
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    expect(receivedArguments, 42);

    await tester.tap(find.text('Close'));
    await tester.pumpAndSettle();
    expect(result, 'done');
  });

  testWidgets('pushReplacementNamed replaces the current route', (
    tester,
  ) async {
    late BuildContext replacementContext;

    await tester.pumpWidget(
      MaterialApp(
        routes: {
          '/replacement': (context) {
            replacementContext = context;
            return const Scaffold(body: Text('Replacement'));
          },
        },
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => context.pushReplacementNamed('/replacement'),
              child: const Text('Replace'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Replace'));
    await tester.pumpAndSettle();

    expect(find.text('Replace'), findsNothing);
    expect(find.text('Replacement'), findsOneWidget);
    expect(Navigator.of(replacementContext).canPop(), isFalse);
  });
}
