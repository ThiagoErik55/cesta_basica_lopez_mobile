import 'package:cesta_basica_lopez_mobile/core/domain/enums.dart';
import 'package:cesta_basica_lopez_mobile/features/cliente/data/cliente_model.dart';
import 'package:cesta_basica_lopez_mobile/features/estoque/data/estoque_repository.dart';
import 'package:cesta_basica_lopez_mobile/features/estoque/data/movimento_estoque_model.dart';
import 'package:cesta_basica_lopez_mobile/features/estoque/presentation/estoque_screen.dart';
import 'package:cesta_basica_lopez_mobile/features/produto/data/produto_model.dart';
import 'package:cesta_basica_lopez_mobile/features/produto/data/produto_repository.dart';
import 'package:cesta_basica_lopez_mobile/features/venda/data/venda_model.dart';
import 'package:cesta_basica_lopez_mobile/features/venda/data/venda_repository.dart';
import 'package:cesta_basica_lopez_mobile/features/venda/domain/atualizacao_cliente.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

final _agora = DateTime(2026, 11, 11, 10);

void main() {
  testWidgets('depois da venda, estoque, situação e histórico atualizam em '
      'tempo real', (tester) async {
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final db = FakeFirebaseFirestore();
    await db
        .collection('produtos')
        .doc('a')
        .set(
          ProdutoModel(
            id: 'a',
            codigo: 'P-A',
            nome: 'Arroz',
            marca: 'Tio João',
            categoria: 'Grãos',
            preco: 20,
            custoAtual: 5,
            estoqueAtual: 12,
            updatedAt: _agora,
          ).toMap(),
        );
    await db
        .collection('clientes')
        .doc('c1')
        .set(
          ClienteModel(
            id: 'c1',
            codigo: 'C-1',
            nome: 'Maria',
            cpf: '529.982.247-25',
            telefone: '1',
            endereco: 'Rua A',
            updatedAt: _agora,
          ).toMap(),
        );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          produtoRepositoryProvider.overrideWithValue(ProdutoRepository(db)),
          estoqueRepositoryProvider.overrideWithValue(EstoqueRepository(db)),
          vendaRepositoryProvider.overrideWithValue(VendaRepository(db)),
        ],
        child: const MaterialApp(home: EstoqueScreen()),
      ),
    );
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.text('NORMAL'), findsOneWidget);
    await tester.tap(find.text('Arroz'));
    await tester.pumpAndSettle();
    expect(find.text('Nenhuma movimentação'), findsOneWidget);

    // Venda de 5 unidades: 12 → 7, que passa do mínimo (10).
    await VendaRepository(db).registrarVenda(
      venda: VendaModel(
        id: 'v1',
        clienteId: 'c1',
        clienteNome: 'Maria',
        vendedorUid: 'u1',
        numeroNota: 261111100000,
        data: _agora,
        itens: const [
          ItemVenda(
            id: 'i1',
            produtoId: 'a',
            nome: 'Arroz',
            quantidade: 5,
            precoUnitario: 20,
            custoUnitario: 5,
          ),
        ],
        valorTotal: 100,
        formaPagamento: FormaPagamento.pix,
        tipo: TipoVenda.aVista,
        updatedAt: _agora,
      ),
      parcelas: const [],
      movimentos: [
        MovimentoEstoqueModel(
          id: 'm1',
          produtoId: 'a',
          vendaId: 'v1',
          tipo: TipoMovimento.saida,
          quantidade: 5,
          data: _agora,
          vendedorUid: 'u1',
          custoUnitario: 5,
          updatedAt: _agora,
        ),
      ],
      cliente: AtualizacaoClienteVenda(clienteId: 'c1', ultimaCompra: _agora),
    );
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pumpAndSettle();

    // Detalhe: saldo, situação e movimento de saída com a nota.
    expect(find.text('ESTOQUE BAIXO'), findsWidgets);
    expect(find.text('7'), findsWidgets);
    expect(find.text('Saída'), findsOneWidget);
    expect(find.text('-5'), findsOneWidget);
    expect(find.textContaining('Venda · Nota 261111100000'), findsOneWidget);
    expect(find.text('Nenhuma movimentação'), findsNothing);
  });
}
