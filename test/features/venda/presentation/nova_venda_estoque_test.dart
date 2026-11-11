import 'package:cesta_basica_lopez_mobile/core/domain/enums.dart';
import 'package:cesta_basica_lopez_mobile/core/providers/firebase_providers.dart';
import 'package:cesta_basica_lopez_mobile/core/providers/regra_estoque_provider.dart';
import 'package:cesta_basica_lopez_mobile/features/cliente/data/cliente_model.dart';
import 'package:cesta_basica_lopez_mobile/features/estoque/domain/regra_estoque.dart';
import 'package:cesta_basica_lopez_mobile/features/produto/data/produto_model.dart';
import 'package:cesta_basica_lopez_mobile/features/venda/data/venda_repository.dart';
import 'package:cesta_basica_lopez_mobile/features/venda/domain/carrinho.dart';
import 'package:cesta_basica_lopez_mobile/features/venda/presentation/nova_venda_providers.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

final _agora = DateTime.now();

ProdutoModel _produto(String id, int estoque, {double custo = 5}) =>
    ProdutoModel(
      id: id,
      codigo: 'P-$id',
      nome: 'Produto $id',
      marca: 'M',
      categoria: 'C',
      preco: 20,
      custoAtual: custo,
      estoqueAtual: estoque,
      updatedAt: _agora,
    );

final _cliente = ClienteModel(
  id: 'c1',
  codigo: 'C-1',
  nome: 'Maria',
  cpf: '529.982.247-25',
  telefone: '1',
  endereco: 'Rua A',
  updatedAt: _agora,
);

class _UsuarioFalso implements User {
  @override
  String get uid => 'u1';

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

NovaVendaState _estado(RegraEstoque regra, List<ItemCarrinho> itens) =>
    NovaVendaState(
      cliente: _cliente,
      itens: {for (final i in itens) i.produto.id: i},
      pagamento: const PagamentoAVista(FormaPagamento.pix),
      primeiroVencimento: DateTime(_agora.year, _agora.month, _agora.day + 30),
      regraEstoque: regra,
    );

void main() {
  group('NovaVendaState.impedimento por estoque', () {
    const bloqueia = RegraEstoque(bloquearVendaSemEstoque: true);

    test('bloqueio ligado impede, com uma mensagem por produto', () {
      final s = _estado(bloqueia, [
        ItemCarrinho(produto: _produto('a', 1), quantidade: 3),
        ItemCarrinho(produto: _produto('b', 0), quantidade: 1),
      ]);
      expect(s.impedimento, contains('Produto a: pedido 3, estoque 1'));
      expect(s.impedimento, contains('Produto b: pedido 1, estoque 0'));
      expect(s.avisoEstoque, isNull);
    });

    test('bloqueio ligado, quantidade igual ao estoque: permite', () {
      final s = _estado(bloqueia, [
        ItemCarrinho(produto: _produto('a', 3), quantidade: 3),
      ]);
      expect(s.impedimento, isNull);
    });

    test('bloqueio desligado permite e mostra o aviso único', () {
      final s = _estado(const RegraEstoque(), [
        ItemCarrinho(produto: _produto('a', 1), quantidade: 3),
        ItemCarrinho(produto: _produto('b', -2), quantidade: 1),
      ]);
      expect(s.impedimento, isNull);
      expect(s.avisoEstoque, contains('2 itens acima do estoque'));
    });

    test('padrão é permitir', () {
      final s = NovaVendaState(
        itens: {'a': ItemCarrinho(produto: _produto('a', 0), quantidade: 1)},
        primeiroVencimento: _agora,
      );
      expect(s.regraEstoque, regraEstoquePadrao);
      expect(s.regraEstoque.bloquearVendaSemEstoque, isFalse);
    });
  });

  group('finalizar com a regra de estoque', () {
    late FakeFirebaseFirestore db;

    setUp(() async {
      db = FakeFirebaseFirestore();
      await db.collection('produtos').doc('a').set(_produto('a', 2).toMap());
      await db
          .collection('produtos')
          .doc('b')
          .set(_produto('b', 10, custo: 8).toMap());
      await db.collection('clientes').doc('c1').set(_cliente.toMap());
    });

    Future<ProviderContainer> preparar(RegraEstoque regra) async {
      final c = ProviderContainer(
        overrides: [
          vendaRepositoryProvider.overrideWithValue(VendaRepository(db)),
          usuarioLogadoProvider.overrideWith(
            (ref) => Stream.value(_UsuarioFalso()),
          ),
          regraEstoqueProvider.overrideWithValue(regra),
        ],
      );
      addTearDown(c.dispose);
      c.listen(usuarioLogadoProvider, (_, _) {});
      c.listen(novaVendaProvider, (_, _) {});
      await c.read(usuarioLogadoProvider.future);
      return c;
    }

    void montar(ProviderContainer c, {required int qtdA}) {
      final n = c.read(novaVendaProvider.notifier);
      n.selecionarCliente(_cliente);
      n.definirQuantidade(_produto('a', 2), qtdA);
      n.definirQuantidade(_produto('b', 10, custo: 8), 3);
      n.selecionarPagamento(const PagamentoAVista(FormaPagamento.pix));
    }

    test('venda rejeitada pela regra não grava nada', () async {
      final c = await preparar(
        const RegraEstoque(bloquearVendaSemEstoque: true),
      );
      montar(c, qtdA: 5);

      await expectLater(
        c.read(novaVendaProvider.notifier).finalizar(),
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'mensagem',
            contains('Produto a: pedido 5, estoque 2 (faltam 3)'),
          ),
        ),
      );

      expect((await db.collection('vendas').get()).docs, isEmpty);
      expect((await db.collection('movimentosEstoque').get()).docs, isEmpty);
      expect((await db.doc('produtos/a').get()).data()!['estoqueAtual'], 2);
      expect((await db.doc('produtos/b').get()).data()!['estoqueAtual'], 10);
    });

    test('regra desligada permite e o estoque fica negativo', () async {
      final c = await preparar(const RegraEstoque());
      montar(c, qtdA: 5);

      final r = await c.read(novaVendaProvider.notifier).finalizar();
      expect(r.sincronizado, isTrue);

      expect((await db.doc('produtos/a').get()).data()!['estoqueAtual'], -3);
      expect((await db.doc('produtos/b').get()).data()!['estoqueAtual'], 7);
    });

    test('bloqueio ligado com estoque suficiente vende normalmente, com '
        'saída ao custo atual', () async {
      final c = await preparar(
        const RegraEstoque(bloquearVendaSemEstoque: true),
      );
      montar(c, qtdA: 2);

      await c.read(novaVendaProvider.notifier).finalizar();

      expect((await db.doc('produtos/a').get()).data()!['estoqueAtual'], 0);
      final movs = (await db.collection('movimentosEstoque').get()).docs
          .map((d) => d.data())
          .toList();
      expect(movs, hasLength(2));
      final porProduto = {for (final m in movs) m['produtoId']: m};
      expect(porProduto['a']!['custoUnitario'], 5);
      expect(porProduto['b']!['custoUnitario'], 8);
      expect(porProduto['a']!['quantidade'], 2);
      expect(porProduto['a']!['tipo'], 'saida');
      final venda = (await db.collection('vendas').get()).docs.single.data();
      expect(porProduto['a']!['vendaId'], venda['id']);
    });
  });
}
