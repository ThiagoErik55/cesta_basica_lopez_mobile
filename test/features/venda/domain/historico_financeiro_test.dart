import 'package:cesta_basica_lopez_mobile/core/domain/enums.dart';
import 'package:cesta_basica_lopez_mobile/features/venda/data/parcela_model.dart';
import 'package:cesta_basica_lopez_mobile/features/venda/data/venda_model.dart';
import 'package:cesta_basica_lopez_mobile/features/venda/domain/historico_financeiro.dart';
import 'package:cesta_basica_lopez_mobile/features/venda/domain/rotulos_venda.dart';
import 'package:flutter_test/flutter_test.dart';

VendaModel venda(
  String id,
  DateTime data, {
  TipoVenda tipo = TipoVenda.parcelado,
  int nota = 1,
  bool deleted = false,
}) => VendaModel(
  id: id,
  clienteId: 'c1',
  clienteNome: 'Maria',
  vendedorUid: 'u1',
  numeroNota: nota,
  data: data,
  itens: const [],
  valorTotal: 100,
  tipo: tipo,
  updatedAt: data,
  deleted: deleted,
);

PagamentoModel pagto(String id, DateTime data, double valor) =>
    PagamentoModel(id: id, valor: valor, data: data, forma: FormaPagamento.pix);

ParcelaModel parcela(
  String vendaId,
  int numero, {
  bool pago = false,
  DateTime? vencimento,
  List<PagamentoModel> pagamentos = const [],
  double valor = 50,
}) => ParcelaModel(
  id: '$vendaId-$numero',
  vendaId: vendaId,
  numero: numero,
  valor: valor,
  vencimento: vencimento ?? DateTime(2099, 1, 1),
  pago: pago,
  pagamentos: pagamentos,
  updatedAt: DateTime(2026, 1, 1),
);

void main() {
  test('compras do mais recente para o mais antigo', () {
    final h = montarHistorico(
      vendas: [
        venda('a', DateTime(2026, 9, 1), nota: 1),
        venda('b', DateTime(2026, 11, 1), nota: 2),
        venda('c', DateTime(2026, 10, 1), nota: 3),
      ],
      parcelasPorVenda: const {},
    );
    expect(h.compras.map((c) => c.venda.numeroNota), [2, 3, 1]);
  });

  test('venda à vista é paga; parcelada reflete a promissória', () {
    final h = montarHistorico(
      vendas: [
        venda('avista', DateTime(2026, 11, 4), tipo: TipoVenda.aVista),
        venda('quitada', DateTime(2026, 11, 3)),
        venda('atrasada', DateTime(2026, 11, 2)),
        venda('aberta', DateTime(2026, 11, 1)),
      ],
      parcelasPorVenda: {
        'quitada': [parcela('quitada', 1, pago: true)],
        'atrasada': [parcela('atrasada', 1, vencimento: DateTime(2020, 1, 1))],
        'aberta': [parcela('aberta', 1)],
      },
    );
    expect(h.compras.map((c) => c.situacao), [
      SituacaoCompra.paga,
      SituacaoCompra.quitada,
      SituacaoCompra.emAtraso,
      SituacaoCompra.emAberto,
    ]);
  });

  test('pagamentos de todas as vendas, do mais recente ao mais antigo', () {
    final h = montarHistorico(
      vendas: [
        venda('a', DateTime(2026, 9, 1), nota: 10),
        venda('b', DateTime(2026, 10, 1), nota: 20),
      ],
      parcelasPorVenda: {
        'a': [
          parcela('a', 1, pagamentos: [pagto('g1', DateTime(2026, 9, 10), 20)]),
          parcela('a', 2, pagamentos: [pagto('g3', DateTime(2026, 11, 5), 30)]),
        ],
        'b': [
          parcela(
            'b',
            1,
            pagamentos: [pagto('g2', DateTime(2026, 10, 20), 50)],
          ),
        ],
      },
    );
    expect(h.pagamentos.map((p) => p.pagamento.id), ['g3', 'g2', 'g1']);
    final primeiro = h.pagamentos.first;
    expect(primeiro.numeroParcela, 2);
    expect(primeiro.numeroNota, 10);
    expect(primeiro.vendaId, 'a');
  });

  test('pagamento aparece com o valor pago, mesmo após alterar a parcela', () {
    final alterada =
        parcela(
          'a',
          1,
          valor: 80,
          pagamentos: [pagto('g1', DateTime(2026, 10, 1), 50)],
        ).copyWith(
          alteracoes: [
            AlteracaoValorParcela(
              valorAnterior: 50,
              valorNovo: 80,
              data: DateTime(2026, 10, 2),
            ),
          ],
        );
    final h = montarHistorico(
      vendas: [venda('a', DateTime(2026, 9, 1))],
      parcelasPorVenda: {
        'a': [alterada],
      },
    );
    expect(h.pagamentos.single.pagamento.valor, 50);
  });

  test('ignora vendas removidas e histórico vazio', () {
    final h = montarHistorico(
      vendas: [venda('a', DateTime(2026, 9, 1), deleted: true)],
      parcelasPorVenda: const {},
    );
    expect(h.compras, isEmpty);
    expect(h.pagamentos, isEmpty);
  });

  test('venda parcelada sem parcelas carregadas fica em aberto', () {
    final h = montarHistorico(
      vendas: [venda('a', DateTime(2026, 9, 1))],
      parcelasPorVenda: const {},
    );
    expect(h.compras.single.situacao, SituacaoCompra.emAberto);
  });
}
