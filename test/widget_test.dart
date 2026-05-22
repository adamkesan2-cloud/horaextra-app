import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:horaextra_app/main.dart';
import 'package:horaextra_app/presentation/app/app_routes.dart';
import 'package:provider/provider.dart';
import 'package:horaextra_app/core/providers/auth_provider.dart';

void main() {
  testWidgets('App inicializa sem erros', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const HoraExtraApp());
    await tester.pumpAndSettle(); // Espera animações e carregamentos

    // Verifica se a tela de login é mostrada (rota inicial)
    expect(find.text('Bem-vindo'), findsOneWidget);
    expect(find.text('Faça login para continuar'), findsOneWidget);

    // Verifica se os campos de email e password existem
    expect(find.byType(TextFormField), findsNWidgets(2));

    // Verifica se o botão de login existe
    expect(find.widgetWithText(ElevatedButton, 'Entrar'), findsOneWidget);
  });

  testWidgets('Validação de campos funciona', (WidgetTester tester) async {
    await tester.pumpWidget(const HoraExtraApp());
    await tester.pumpAndSettle();

    // Tenta fazer login sem preencher campos
    await tester.tap(find.widgetWithText(ElevatedButton, 'Entrar'));
    await tester.pump();

    // Verifica se as mensagens de erro aparecem
    expect(find.text('Email obrigatório'), findsOneWidget);
    expect(find.text('Password obrigatória'), findsOneWidget);
  });
}
