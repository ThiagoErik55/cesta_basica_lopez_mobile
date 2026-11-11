import 'dart:async';

import 'package:cesta_basica_lopez_mobile/core/navigation/app_routes.dart';
import 'package:cesta_basica_lopez_mobile/features/estoque/domain/controle_estoque.dart';
import 'package:cesta_basica_lopez_mobile/features/estoque/presentation/estoque_providers.dart';
import 'package:cesta_basica_lopez_mobile/features/estoque/presentation/estoque_screen.dart';
import 'package:cesta_basica_lopez_mobile/features/produto/data/produto_model.dart';
import 'package:cesta_basica_lopez_mobile/features/produto/presentation/produto_providers.dart';
import 'package:cesta_basica_lopez_mobile/features/produto/presentation/produtos_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

final _t = DateTime(2026, 11, 11);

ProdutoModel _p(String nome, int estoque, {int minimo = 10}) => ProdutoModel(
  id: nome.toLowerCase(),
  codigo: 'P-$nome',
  nome: nome,
  marca: 'Marca',
  categoria: 'Grãos',
  preco: 10,
  custoAtual: 5,
  estoqueAtual: estoque,
  estoqueMinimo: minimo,
  updatedAt: _t,
);

List<ItemEstoque> _itens(List<ProdutoModel> produtos) =>
    montarItensEstoque(produtos);

/// Abre a aba Produtos com as rotas do app (a de estoque é a real).
Future<void> _abrirProdutos(
  WidgetTester tester, {
  required Stream<List<ItemEstoque>> itens,
  List<ProdutoModel> produtos = const [],
}) async {
  tester.view.physicalSize = const Size(800, 2400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        itensEstoqueProvider.overrideWith((ref) => itens),
        produtosProvider.overrideWith((ref) => AsyncData(produtos)),
        movimentosDoProdutoProvider.overrideWith(
          (ref, id) => Stream.value(const []),
        ),
      ],
      child: const MaterialApp(
        routes: {AppRoutes.estoque: EstoqueScreen.daRota},
        home: ProdutosScreen(),
      ),
    ),
  );
  await tester.pump();
  await tester.pump();
}

Finder get _badge => find.byType(Badge);

bool _badgeVisivel(WidgetTester tester) =>
    tester.widget<Badge>(_badge).isLabelVisible;

void main() {
  group('aba Produtos: badge e faixa', () {
    testWidgets('com alertas mostra a contagem no ícone e a faixa', (
      tester,
    ) async {
      await _abrirProdutos(
        tester,
        itens: Stream.value(
          _itens([
            _p('Arroz', 50),
            _p('Feijão', 5), // baixo
            _p('Açúcar', 0), // sem estoque
            _p('Sal', -2), // negativo
          ]),
        ),
      );

      expect(_badgeVisivel(tester), isTrue);
      expect(find.descendant(of: _badge, matching: find.text('3')), findsOne);
      expect(find.text('3 produtos com estoque baixo ou zerado'), findsOne);
      expect(find.text('Ver'), findsOneWidget);
    });

    testWidgets('um alerta usa o singular', (tester) async {
      await _abrirProdutos(
        tester,
        itens: Stream.value(_itens([_p('Arroz', 50), _p('Feijão', 5)])),
      );
      expect(find.text('1 produto com estoque baixo ou zerado'), findsOne);
    });

    testWidgets('zero alertas: sem badge e sem faixa', (tester) async {
      await _abrirProdutos(
        tester,
        itens: Stream.value(_itens([_p('Arroz', 50), _p('Feijão', 40)])),
      );

      expect(_badgeVisivel(tester), isFalse);
      expect(find.textContaining('estoque baixo ou zerado'), findsNothing);
      expect(find.text('Ver'), findsNothing);
    });

    testWidgets('o badge some quando o estoque é reposto (tempo real)', (
      tester,
    ) async {
      final controle = StreamController<List<ItemEstoque>>();
      addTearDown(() {
        controle.close();
      });
      await _abrirProdutos(tester, itens: controle.stream);

      controle.add(_itens([_p('Arroz', 2)]));
      await tester.pump();
      await tester.pump();
      expect(_badgeVisivel(tester), isTrue);
      expect(find.text('1 produto com estoque baixo ou zerado'), findsOne);

      controle.add(_itens([_p('Arroz', 80)]));
      await tester.pump();
      await tester.pump();
      expect(_badgeVisivel(tester), isFalse);
      expect(find.textContaining('estoque baixo ou zerado'), findsNothing);
    });

    testWidgets('mínimo 0 com saldo positivo não gera alerta', (tester) async {
      await _abrirProdutos(
        tester,
        itens: Stream.value(_itens([_p('Arroz', 3, minimo: 0)])),
      );
      expect(_badgeVisivel(tester), isFalse);
    });

    testWidgets('sem emissão: sem badge, sem faixa e sem spinner da faixa', (
      tester,
    ) async {
      await _abrirProdutos(
        tester,
        itens: StreamController<List<ItemEstoque>>().stream,
      );
      expect(_badgeVisivel(tester), isFalse);
      expect(find.textContaining('estoque baixo ou zerado'), findsNothing);
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });

    testWidgets('com erro: sem badge, sem faixa e sem spinner', (tester) async {
      await _abrirProdutos(tester, itens: Stream.error(StateError('falhou')));
      expect(_badgeVisivel(tester), isFalse);
      expect(find.textContaining('estoque baixo ou zerado'), findsNothing);
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });

    testWidgets('"Ver" abre a tela Estoque já filtrada em alertas, na '
        'ordem de gravidade', (tester) async {
      await _abrirProdutos(
        tester,
        itens: Stream.value(
          _itens([
            _p('Arroz', 50),
            _p('Feijão', 5), // baixo
            _p('Açúcar', 0), // sem estoque
            _p('Sal', -2), // negativo
          ]),
        ),
      );

      await tester.tap(find.text('Ver'));
      await tester.pumpAndSettle();

      expect(find.text('Estoque'), findsWidgets);
      // O normal fica fora da lista de alertas.
      expect(find.text('Arroz'), findsNothing);
      double y(String nome) => tester.getTopLeft(find.text(nome)).dy;
      expect(y('Sal'), lessThan(y('Açúcar')));
      expect(y('Açúcar'), lessThan(y('Feijão')));

      // O chip "Alertas" é o selecionado.
      final chip = tester.widget<ChoiceChip>(
        find.widgetWithText(ChoiceChip, 'Alertas'),
      );
      expect(chip.selected, isTrue);
    });

    testWidgets('o ícone do estoque abre a tela sem filtro', (tester) async {
      await _abrirProdutos(
        tester,
        itens: Stream.value(_itens([_p('Arroz', 50), _p('Feijão', 5)])),
      );

      await tester.tap(find.byIcon(Icons.warehouse_outlined));
      await tester.pumpAndSettle();

      expect(find.text('Arroz'), findsOneWidget);
      expect(find.text('Feijão'), findsOneWidget);
      final chip = tester.widget<ChoiceChip>(
        find.widgetWithText(ChoiceChip, 'Todos'),
      );
      expect(chip.selected, isTrue);
    });
  });

  group('tela Estoque: filtro Alertas', () {
    Future<void> abrir(
      WidgetTester tester,
      List<ProdutoModel> produtos, {
      bool apenasAlertas = false,
    }) async {
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            itensEstoqueProvider.overrideWith(
              (ref) => Stream.value(_itens(produtos)),
            ),
          ],
          child: MaterialApp(home: EstoqueScreen(apenasAlertas: apenasAlertas)),
        ),
      );
      await tester.pump();
      await tester.pump();
    }

    testWidgets('chip Alertas filtra baixo + sem estoque + negativo e '
        'ordena por gravidade', (tester) async {
      await abrir(tester, [
        _p('Arroz', 50),
        _p('Feijão', 5),
        _p('Açúcar', 0),
        _p('Sal', -2),
        _p('Café', 2),
      ]);
      expect(find.text('Arroz'), findsOneWidget);

      await tester.tap(find.widgetWithText(ChoiceChip, 'Alertas'));
      await tester.pump();

      expect(find.text('Arroz'), findsNothing);
      double y(String nome) => tester.getTopLeft(find.text(nome)).dy;
      // Negativo, sem estoque; depois baixo pela menor relação (Café 0,2).
      expect(y('Sal'), lessThan(y('Açúcar')));
      expect(y('Açúcar'), lessThan(y('Café')));
      expect(y('Café'), lessThan(y('Feijão')));
    });

    testWidgets('cada alerta mostra quanto falta para o mínimo', (
      tester,
    ) async {
      await abrir(tester, [
        _p('Feijão', 5),
        _p('Sal', -3),
        _p('Arroz', 50),
      ], apenasAlertas: true);

      expect(find.text('Faltam 5 un. para o mínimo (10)'), findsOneWidget);
      expect(find.text('Faltam 13 un. para o mínimo (10)'), findsOneWidget);
    });

    testWidgets('no limite do mínimo aparece sem "faltam 0"', (tester) async {
      await abrir(tester, [_p('Feijão', 10)], apenasAlertas: true);
      expect(find.text('No limite do mínimo'), findsOneWidget);
      expect(find.textContaining('Faltam 0'), findsNothing);
    });

    testWidgets('sem alertas, o filtro mostra a mensagem de tudo certo', (
      tester,
    ) async {
      await abrir(tester, [_p('Arroz', 50)], apenasAlertas: true);
      expect(find.text('Nenhum alerta de estoque'), findsOneWidget);
    });

    testWidgets('alertas com busca sem resultado: mensagem de busca', (
      tester,
    ) async {
      await abrir(tester, [_p('Feijão', 5)], apenasAlertas: true);
      await tester.enterText(find.byType(TextField), 'zzz');
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('Nenhum produto encontrado'), findsOneWidget);
    });

    testWidgets('trocar de chip tira o filtro de alertas', (tester) async {
      await abrir(tester, [
        _p('Arroz', 50),
        _p('Feijão', 5),
      ], apenasAlertas: true);
      expect(find.text('Arroz'), findsNothing);

      await tester.tap(find.widgetWithText(ChoiceChip, 'Todos'));
      await tester.pump();
      expect(find.text('Arroz'), findsOneWidget);
    });

    testWidgets('as listas dos outros filtros mantêm a ordem da KAN-41', (
      tester,
    ) async {
      await abrir(tester, [_p('Zeta', 1), _p('Alfa', 9)]);
      await tester.tap(find.widgetWithText(ChoiceChip, 'Baixo'));
      await tester.pump();
      double y(String nome) => tester.getTopLeft(find.text(nome)).dy;
      // Mesmo grupo: por nome (Alfa antes de Zeta), não por gravidade.
      expect(y('Alfa'), lessThan(y('Zeta')));
    });

    testWidgets('erro mostra mensagem e não spinner', (tester) async {
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            itensEstoqueProvider.overrideWith(
              (ref) => Stream.error(StateError('falhou')),
            ),
          ],
          child: const MaterialApp(home: EstoqueScreen(apenasAlertas: true)),
        ),
      );
      await tester.pump();
      await tester.pump();
      expect(find.text('Erro ao carregar o estoque'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });
  });

  group('contagemAlertasEstoqueProvider', () {
    test('conta com dados, é 0 com erro e 0 enquanto carrega', () async {
      final comDados = ProviderContainer(
        overrides: [
          itensEstoqueProvider.overrideWith(
            (ref) => Stream.value(_itens([_p('A', 1), _p('B', 50)])),
          ),
        ],
      );
      addTearDown(comDados.dispose);
      comDados.listen(contagemAlertasEstoqueProvider, (_, _) {});
      expect(comDados.read(contagemAlertasEstoqueProvider), 0); // carregando
      await comDados.read(itensEstoqueProvider.future);
      expect(comDados.read(contagemAlertasEstoqueProvider), 1);

      final comErro = ProviderContainer(
        overrides: [
          itensEstoqueProvider.overrideWith(
            (ref) => Stream.error(StateError('x')),
          ),
        ],
      );
      addTearDown(comErro.dispose);
      comErro.listen(contagemAlertasEstoqueProvider, (_, _) {});
      await Future<void>.delayed(Duration.zero);
      expect(comErro.read(contagemAlertasEstoqueProvider), 0);
    });
  });
}
