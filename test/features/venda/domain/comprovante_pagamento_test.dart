import 'package:cesta_basica_lopez_mobile/core/domain/enums.dart';
import 'package:cesta_basica_lopez_mobile/features/cliente/data/cliente_model.dart';
import 'package:cesta_basica_lopez_mobile/features/venda/data/parcela_model.dart';
import 'package:cesta_basica_lopez_mobile/features/venda/data/venda_model.dart';
import 'package:cesta_basica_lopez_mobile/features/venda/domain/comprovante_pagamento.dart';
import 'package:flutter_test/flutter_test.dart';

final _emissao = DateTime(2026, 11, 20, 16, 45);

final _cliente = ClienteModel(
  id: 'c1',
  codigo: 'C-1',
  nome: 'Maria da Silva',
  cpf: '529.982.247-25',
  telefone: '(45) 99999-0001',
  endereco: 'Rua A',
  updatedAt: _emissao,
);

final _venda = VendaModel(
  id: 'v1',
  clienteId: 'c1',
  clienteNome: 'Maria da Silva',
  vendedorUid: 'u1',
  numeroNota: 2611091530,
  data: DateTime(2026, 11, 9),
  itens: const [],
  valorTotal: 300,
  tipo: TipoVenda.parcelado,
  updatedAt: _emissao,
);

PagamentoModel _pagto(
  String id,
  double valor,
  DateTime data, {
  FormaPagamento forma = FormaPagamento.pix,
  String? observacao,
}) => PagamentoModel(
  id: id,
  valor: valor,
  data: data,
  forma: forma,
  observacao: observacao,
);

ParcelaModel _parcela(
  int numero,
  double valor, {
  List<PagamentoModel> pagamentos = const [],
  bool pago = false,
}) => ParcelaModel(
  id: 'p$numero',
  vendaId: 'v1',
  numero: numero,
  valor: valor,
  vencimento: DateTime(2026, 12, numero),
  pago: pago,
  pagamentos: pagamentos,
  updatedAt: _emissao,
);

ComprovantePagamento _montar(
  List<ParcelaModel> parcelas,
  String parcelaId,
  String pagamentoId,
) {
  final r = montarComprovantePagamento(
    cliente: _cliente,
    venda: _venda,
    parcelas: parcelas,
    parcelaId: parcelaId,
    pagamentoId: pagamentoId,
    emitidoEm: _emissao,
  );
  expect(r.ok, isTrue, reason: r.erro);
  return r.comprovante!;
}

void main() {
  group('dados básicos', () {
    final parcelas = [
      _parcela(
        1,
        100,
        pago: true,
        pagamentos: [_pagto('g1', 100, DateTime(2026, 11, 10))],
      ),
      _parcela(
        2,
        100,
        pagamentos: [
          _pagto(
            'g2',
            30,
            DateTime(2026, 11, 15),
            observacao: '  sinal  ',
            forma: FormaPagamento.dinheiro,
          ),
        ],
      ),
      _parcela(3, 100),
    ];

    test('número do comprovante: nota, parcela e ordem do pagamento', () {
      final c = _montar(parcelas, 'p2', 'g2');
      expect(c.numero, '2611091530-P2-1');
    });

    test('CPF sai mascarado, só 3 primeiros e 2 últimos dígitos', () {
      final c = _montar(parcelas, 'p2', 'g2');
      expect(c.cpfMascarado, '529.***.***-25');
      expect(c.cpfMascarado, isNot(contains('982')));
      expect(c.cpfMascarado, isNot(contains('247')));
    });

    test('traz cliente, venda, parcela, data, valor, forma e observação', () {
      final c = _montar(parcelas, 'p2', 'g2');
      expect(c.clienteNome, 'Maria da Silva');
      expect(c.numeroNota, 2611091530);
      expect(c.numeroParcela, 2);
      expect(c.totalParcelas, 3);
      expect(c.dataPagamento, DateTime(2026, 11, 15));
      expect(c.valorPago, 30);
      expect(c.forma, FormaPagamento.dinheiro);
      expect(c.observacao, 'sinal');
      expect(c.emitidoEm, _emissao);
    });

    test('observação ausente ou em branco vira nula', () {
      final sem = [
        _parcela(1, 100, pagamentos: [_pagto('g', 40, DateTime(2026, 11, 10))]),
      ];
      expect(_montar(sem, 'p1', 'g').observacao, isNull);
      final branco = [
        _parcela(
          1,
          100,
          pagamentos: [
            _pagto('g', 40, DateTime(2026, 11, 10), observacao: '   '),
          ],
        ),
      ];
      expect(_montar(branco, 'p1', 'g').observacao, isNull);
    });
  });

  group('situação depois do pagamento', () {
    test('pagamento parcial: saldo restante da parcela e da venda', () {
      final parcelas = [
        _parcela(1, 100, pagamentos: [_pagto('g', 30, DateTime(2026, 11, 15))]),
        _parcela(2, 100),
        _parcela(3, 100),
      ];
      final c = _montar(parcelas, 'p1', 'g');
      expect(c.saldoRestanteParcela, 70);
      expect(c.saldoEmAbertoVenda, 270);
      expect(c.parcelaQuitada, isFalse);
    });

    test('pagamento total: parcela quitada e saldo da venda', () {
      final parcelas = [
        _parcela(
          1,
          100,
          pago: true,
          pagamentos: [_pagto('g', 100, DateTime(2026, 11, 15))],
        ),
        _parcela(2, 100),
      ];
      final c = _montar(parcelas, 'p1', 'g');
      expect(c.saldoRestanteParcela, 0);
      expect(c.parcelaQuitada, isTrue);
      expect(c.saldoEmAbertoVenda, 100);
    });

    test('último pagamento da venda zera o saldo em aberto', () {
      final parcelas = [
        _parcela(
          1,
          100,
          pago: true,
          pagamentos: [_pagto('a', 100, DateTime(2026, 11, 10))],
        ),
        _parcela(
          2,
          100,
          pago: true,
          pagamentos: [_pagto('b', 100, DateTime(2026, 11, 15))],
        ),
      ];
      final c = _montar(parcelas, 'p2', 'b');
      expect(c.saldoEmAbertoVenda, 0);
      expect(c.parcelaQuitada, isTrue);
    });

    test('pagamento antigo mostra o saldo da época, não o atual', () {
      final parcelas = [
        _parcela(
          1,
          100,
          pago: true,
          pagamentos: [
            _pagto('g1', 30, DateTime(2026, 11, 10)),
            _pagto('g2', 50, DateTime(2026, 11, 20)),
            _pagto('g3', 20, DateTime(2026, 11, 25)),
          ],
        ),
        _parcela(
          2,
          100,
          pagamentos: [_pagto('o', 100, DateTime(2026, 11, 22))],
          pago: true,
        ),
      ];

      final primeiro = _montar(parcelas, 'p1', 'g1');
      expect(primeiro.saldoRestanteParcela, 70);
      expect(primeiro.parcelaQuitada, isFalse);
      // A parcela 2 só foi paga depois: na época ainda faltava tudo.
      expect(primeiro.saldoEmAbertoVenda, 170);

      final segundo = _montar(parcelas, 'p1', 'g2');
      expect(segundo.saldoRestanteParcela, 20);
      expect(segundo.saldoEmAbertoVenda, 120);

      final ultimo = _montar(parcelas, 'p1', 'g3');
      expect(ultimo.saldoRestanteParcela, 0);
      expect(ultimo.parcelaQuitada, isTrue);
      expect(ultimo.saldoEmAbertoVenda, 0);
    });

    test('número do comprovante antigo não muda com pagamentos novos', () {
      final antes = [
        _parcela(
          1,
          100,
          pagamentos: [_pagto('g1', 30, DateTime(2026, 11, 10))],
        ),
      ];
      final depois = [
        _parcela(
          1,
          100,
          pagamentos: [
            _pagto('g1', 30, DateTime(2026, 11, 10)),
            _pagto('g2', 20, DateTime(2026, 11, 12)),
          ],
        ),
      ];
      expect(
        _montar(antes, 'p1', 'g1').numero,
        _montar(depois, 'p1', 'g1').numero,
      );
      expect(_montar(depois, 'p1', 'g2').numero, '2611091530-P1-2');
    });

    test('usa o valor atual da parcela alterada (KAN-32)', () {
      final parcelas = [
        _parcela(1, 80, pagamentos: [_pagto('g', 30, DateTime(2026, 11, 10))]),
      ];
      expect(_montar(parcelas, 'p1', 'g').saldoRestanteParcela, 50);
    });

    test('parcela paga sem pagamento registrado não entra no saldo', () {
      final parcelas = [
        _parcela(1, 100, pagamentos: [_pagto('g', 40, DateTime(2026, 11, 10))]),
        _parcela(2, 100, pago: true),
      ];
      expect(_montar(parcelas, 'p1', 'g').saldoEmAbertoVenda, 60);
    });
  });

  group('erros', () {
    final parcelas = [
      _parcela(1, 100, pagamentos: [_pagto('g', 40, DateTime(2026, 11, 10))]),
    ];

    ResultadoComprovante tentar(String parcelaId, String pagamentoId) =>
        montarComprovantePagamento(
          cliente: _cliente,
          venda: _venda,
          parcelas: parcelas,
          parcelaId: parcelaId,
          pagamentoId: pagamentoId,
        );

    test('parcela não encontrada', () {
      final r = tentar('x', 'g');
      expect(r.ok, isFalse);
      expect(r.erro, contains('Parcela'));
    });

    test('pagamento não encontrado', () {
      final r = tentar('p1', 'x');
      expect(r.ok, isFalse);
      expect(r.erro, contains('Pagamento'));
    });
  });

  test('nome do arquivo usa nota, parcela e data do pagamento', () {
    final c = _montar(
      [
        _parcela(2, 100, pagamentos: [_pagto('g', 40, DateTime(2026, 11, 5))]),
      ],
      'p2',
      'g',
    );
    expect(
      nomeArquivoComprovante(c),
      'comprovante-2611091530-parcela2-20261105.pdf',
    );
  });
}
