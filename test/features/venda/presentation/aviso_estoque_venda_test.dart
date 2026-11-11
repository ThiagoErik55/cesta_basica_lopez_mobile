import 'package:cesta_basica_lopez_mobile/core/providers/regra_estoque_provider.dart';
import 'package:cesta_basica_lopez_mobile/features/estoque/domain/regra_estoque.dart';
import 'package:cesta_basica_lopez_mobile/features/produto/data/produto_model.dart';
import 'package:cesta_basica_lopez_mobile/features/venda/presentation/nova_venda_providers.dart';
import 'package:cesta_basica_lopez_mobile/features/venda/presentation/rodape_venda.dart';
import 'package:cesta_basica_lopez_mobile/features/venda/presentation/secao_produtos_venda.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

final _produto = ProdutoModel(
  id: 'a',
  codigo: 'P-A',
  nome: 'Arroz',
  marca: 'M',
  categoria: 'C',
  preco: 20,
  estoqueAtual: 3,
  updatedAt: DateTime(2026, 11, 11),
);

void main() {
  testWidgets('item acima do estoque mostra "Estoque: X · faltam Y" e o '
      'rodapé traz o aviso único', (tester) async {
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          produtosVendaProvider.overrideWith((ref) => Stream.value([_produto])),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: Consumer(
              builder: (context, ref, _) {
                final venda = ref.watch(novaVendaProvider);
                return Column(
                  children: [
                    const Expanded(child: SecaoProdutosVenda()),
                    RodapeVenda(
                      total: venda.total,
                      unidades: venda.unidades,
                      avisoEstoque: venda.avisoEstoque,
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Estoque: 3'), findsOneWidget);

    // 3 unidades = o estoque: ainda sem aviso.
    for (var i = 0; i < 3; i++) {
      await tester.tap(find.byIcon(Icons.add));
      await tester.pump();
    }
    expect(find.text('Estoque: 3'), findsOneWidget);
    expect(find.textContaining('acima do estoque'), findsNothing);

    // A 4ª passa do estoque.
    await tester.tap(find.byIcon(Icons.add));
    await tester.pump();
    expect(find.text('Estoque: 3 · faltam 1'), findsOneWidget);
    expect(
      find.text(
        '1 item acima do estoque registrado: o estoque ficará negativo.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('com bloqueio ligado o rodapé não repete o aviso', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          produtosVendaProvider.overrideWith((ref) => Stream.value([_produto])),
          regraEstoqueProvider.overrideWithValue(
            const RegraEstoque(bloquearVendaSemEstoque: true),
          ),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: Consumer(
              builder: (context, ref, _) {
                final venda = ref.watch(novaVendaProvider);
                return Column(
                  children: [
                    const Expanded(child: SecaoProdutosVenda()),
                    RodapeVenda(
                      total: venda.total,
                      unidades: venda.unidades,
                      avisoEstoque: venda.avisoEstoque,
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    for (var i = 0; i < 4; i++) {
      await tester.tap(find.byIcon(Icons.add));
      await tester.pump();
    }
    expect(find.text('Estoque: 3 · faltam 1'), findsOneWidget);
    expect(find.textContaining('o estoque ficará negativo'), findsNothing);
  });

  testWidgets('o rodapé avisa quando a venda deixa o estoque baixo, sem '
      'bloquear', (tester) async {
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    // Estoque 3, mínimo 10: qualquer venda já deixa o produto abaixo.
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          produtosVendaProvider.overrideWith((ref) => Stream.value([_produto])),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: Consumer(
              builder: (context, ref, _) {
                final venda = ref.watch(novaVendaProvider);
                return Column(
                  children: [
                    const Expanded(child: SecaoProdutosVenda()),
                    RodapeVenda(
                      total: venda.total,
                      unidades: venda.unidades,
                      avisosEstoqueBaixo: venda.avisosEstoqueBaixo,
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(find.textContaining('ficará'), findsNothing);

    await tester.tap(find.byIcon(Icons.add));
    await tester.pump();
    expect(find.text('Arroz ficará com estoque baixo (2 un.)'), findsOneWidget);

    // Vende tudo (3): fica sem estoque, não negativo.
    await tester.tap(find.byIcon(Icons.add));
    await tester.tap(find.byIcon(Icons.add));
    await tester.pump();
    expect(find.text('Arroz ficará sem estoque'), findsOneWidget);
    expect(find.textContaining('estoque baixo ('), findsNothing);
  });

  test('o aviso de estoque baixo é só informativo: não vira impedimento', () {
    final c = ProviderContainer(
      overrides: [
        produtosVendaProvider.overrideWith((ref) => Stream.value([_produto])),
      ],
    );
    addTearDown(c.dispose);
    c.read(novaVendaProvider.notifier).adicionar(_produto);

    final venda = c.read(novaVendaProvider);
    expect(venda.avisosEstoqueBaixo, [
      'Arroz ficará com estoque baixo (2 un.)',
    ]);
    // Nenhum impedimento de estoque (falta só cliente etc.).
    expect(venda.impedimento, isNot(contains('estoque')));
  });
}
