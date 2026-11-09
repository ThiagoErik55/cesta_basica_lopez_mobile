import 'package:cesta_basica_lopez_mobile/core/domain/enums.dart';
import 'package:cesta_basica_lopez_mobile/features/cliente/data/cliente_model.dart';
import 'package:cesta_basica_lopez_mobile/features/cliente/domain/bloqueio_cliente.dart';
import 'package:cesta_basica_lopez_mobile/features/cliente/domain/regra_bloqueio.dart';
import 'package:cesta_basica_lopez_mobile/features/cliente/domain/status_pagamento.dart';
import 'package:cesta_basica_lopez_mobile/features/venda/data/parcela_model.dart';
import 'package:flutter_test/flutter_test.dart';

final _agora = DateTime(2026, 11, 20, 14);

DateTime _diasAtras(int dias) =>
    DateTime(_agora.year, _agora.month, _agora.day - dias);

ClienteModel _cliente({
  bool bloqueado = false,
  double valorEmAberto = 0,
  double limiteCredito = 0,
  DateTime? proximoVencimento,
}) => ClienteModel(
  id: 'c1',
  codigo: 'C-1',
  nome: 'Maria',
  cpf: '529.982.247-25',
  telefone: '(45) 99999-0001',
  endereco: 'Rua A',
  bloqueado: bloqueado,
  valorEmAberto: valorEmAberto,
  limiteCredito: limiteCredito,
  proximoVencimento: proximoVencimento,
  updatedAt: _agora,
);

ParcelaModel _parcela(
  String id,
  DateTime vencimento, {
  double valor = 100,
  bool pago = false,
  String vendaId = 'v1',
}) => ParcelaModel(
  id: id,
  vendaId: vendaId,
  numero: 1,
  valor: valor,
  vencimento: vencimento,
  pago: pago,
  updatedAt: _agora,
);

ResultadoBloqueio _avaliar(
  List<ParcelaModel> parcelas, {
  ClienteModel? cliente,
  RegraBloqueio regra = regraBloqueioPadrao,
  double novaVenda = 0,
}) => avaliarBloqueio(
  cliente: cliente ?? _cliente(valorEmAberto: 100),
  parcelasPendentes: parcelas,
  agora: _agora,
  regra: regra,
  valorNovaVenda: novaVenda,
);

void main() {
  group('RegraBloqueio', () {
    test('padrões: 15 dias e bloquear por limite', () {
      expect(regraBloqueioPadrao.diasToleranciaAtraso, 15);
      expect(regraBloqueioPadrao.bloquearPorLimite, isTrue);
      expect(const RegraBloqueio(), regraBloqueioPadrao);
    });

    test('troca de valores sem mudar a lógica', () {
      final regra = regraBloqueioPadrao.copyWith(
        diasToleranciaAtraso: 30,
        bloquearPorLimite: false,
      );
      expect(regra.diasToleranciaAtraso, 30);
      expect(regra.bloquearPorLimite, isFalse);
      // 20 dias bloqueia com 15, mas não com 30.
      final parcelas = [_parcela('a', _diasAtras(20))];
      expect(_avaliar(parcelas).deveBloquear, isTrue);
      expect(_avaliar(parcelas, regra: regra).deveBloquear, isFalse);
    });
  });

  group('diasDeAtraso', () {
    test('conta dias de calendário depois do vencimento', () {
      expect(diasDeAtraso(_diasAtras(0), _agora), 0);
      expect(diasDeAtraso(_diasAtras(1), _agora), 1);
      expect(diasDeAtraso(_diasAtras(23), _agora), 23);
    });

    test('parcela a vencer não tem atraso', () {
      expect(diasDeAtraso(_diasAtras(-5), _agora), 0);
    });

    test('vence hoje não conta como atraso', () {
      expect(diasDeAtraso(DateTime(2026, 11, 20), _agora), 0);
    });
  });

  group('avaliarBloqueio por atraso', () {
    test('sem parcelas pendentes: não bloqueia', () {
      final r = _avaliar(const [], cliente: _cliente());
      expect(r.deveBloquear, isFalse);
      expect(r.motivo, MotivoBloqueio.nenhum);
      expect(r.diasDeAtraso, 0);
      expect(r.saldoVencido, 0);
    });

    test('só parcelas a vencer: não bloqueia', () {
      final r = _avaliar([_parcela('a', _diasAtras(-10))]);
      expect(r.deveBloquear, isFalse);
      expect(r.diasDeAtraso, 0);
    });

    test('atraso abaixo da tolerância: não bloqueia', () {
      final r = _avaliar([_parcela('a', _diasAtras(14))]);
      expect(r.deveBloquear, isFalse);
      expect(r.diasDeAtraso, 14);
      expect(r.saldoVencido, 100);
    });

    test('exatamente na tolerância: bloqueia', () {
      final r = _avaliar([_parcela('a', _diasAtras(15))]);
      expect(r.deveBloquear, isTrue);
      expect(r.motivo, MotivoBloqueio.atrasoAcimaDoLimite);
      expect(r.diasDeAtraso, 15);
    });

    test('acima da tolerância: bloqueia com o motivo e os dias', () {
      final r = _avaliar([_parcela('a', _diasAtras(23))]);
      expect(r.deveBloquear, isTrue);
      expect(r.diasDeAtraso, 23);
      expect(rotuloMotivoBloqueio(r), 'Atraso de 23 dias');
    });

    test('uma parcela atrasada basta, mesmo com outras em dia', () {
      final r = _avaliar([
        _parcela('a', _diasAtras(-30)),
        _parcela('b', _diasAtras(20), valor: 40),
        _parcela('c', _diasAtras(-5)),
      ]);
      expect(r.deveBloquear, isTrue);
      expect(r.saldoVencido, 40);
    });

    test('várias vendas: vale o maior atraso e soma o saldo vencido', () {
      final r = _avaliar([
        _parcela('a', _diasAtras(3), valor: 50, vendaId: 'v1'),
        _parcela('b', _diasAtras(18), valor: 70, vendaId: 'v2'),
        _parcela('c', _diasAtras(9), valor: 30, vendaId: 'v3'),
      ]);
      expect(r.diasDeAtraso, 18);
      expect(r.saldoVencido, 150);
      expect(r.deveBloquear, isTrue);
    });

    test('várias vendas, todas abaixo da tolerância: não bloqueia', () {
      final r = _avaliar([
        _parcela('a', _diasAtras(3), vendaId: 'v1'),
        _parcela('b', _diasAtras(10), vendaId: 'v2'),
      ]);
      expect(r.deveBloquear, isFalse);
      expect(r.diasDeAtraso, 10);
    });

    test('desbloqueio automático depois de pagar a parcela atrasada', () {
      final atrasada = _parcela('a', _diasAtras(23));
      final emDia = _parcela('b', _diasAtras(-10));
      expect(_avaliar([atrasada, emDia]).deveBloquear, isTrue);

      // Paga: sai das pendentes (e ficaria pago = true).
      final paga = _parcela('a', _diasAtras(23), pago: true);
      final depois = _avaliar([paga, emDia]);
      expect(depois.deveBloquear, isFalse);
      expect(depois.motivo, MotivoBloqueio.nenhum);
    });

    test('ignora parcelas pagas ou removidas na lista', () {
      final removida = ParcelaModel(
        id: 'x',
        vendaId: 'v',
        numero: 1,
        valor: 10,
        vencimento: _diasAtras(40),
        updatedAt: _agora,
        deleted: true,
      );
      final r = _avaliar([_parcela('a', _diasAtras(40), pago: true), removida]);
      expect(r.deveBloquear, isFalse);
    });

    test('pagamento parcial reduz o saldo vencido mas não o atraso', () {
      final parcial = _parcela('a', _diasAtras(20)).copyWith(
        pagamentos: [
          PagamentoModel(
            id: 'g',
            valor: 30,
            data: _agora,
            forma: FormaPagamento.pix,
          ),
        ],
      );
      final r = _avaliar([parcial]);
      expect(r.saldoVencido, 70);
      expect(r.deveBloquear, isTrue);
    });
  });

  group('avaliarBloqueio por limite', () {
    test('limite 0 é ignorado, mesmo com muito em aberto', () {
      final r = _avaliar(
        const [],
        cliente: _cliente(valorEmAberto: 5000, limiteCredito: 0),
        novaVenda: 5000,
      );
      expect(r.deveBloquear, isFalse);
      expect(r.excedenteLimite, 0);
    });

    test('em aberto mais a venda passa do limite: bloqueia', () {
      final r = _avaliar(
        const [],
        cliente: _cliente(valorEmAberto: 150, limiteCredito: 200),
        novaVenda: 80,
      );
      expect(r.deveBloquear, isTrue);
      expect(r.motivo, MotivoBloqueio.limiteExcedido);
      expect(r.excedenteLimite, 30);
      expect(r.limiteCredito, 200);
      expect(r.valorEmAberto, 150);
      expect(rotuloMotivoBloqueio(r), 'Limite excedido');
    });

    test('exatamente no limite: não bloqueia', () {
      final r = _avaliar(
        const [],
        cliente: _cliente(valorEmAberto: 150, limiteCredito: 200),
        novaVenda: 50,
      );
      expect(r.deveBloquear, isFalse);
    });

    test('sem venda em andamento, só o que já deve conta', () {
      final cliente = _cliente(valorEmAberto: 250, limiteCredito: 200);
      expect(_avaliar(const [], cliente: cliente).deveBloquear, isTrue);
      expect(
        _avaliar(
          const [],
          cliente: _cliente(valorEmAberto: 150, limiteCredito: 200),
        ).deveBloquear,
        isFalse,
      );
    });

    test('regra desligada não bloqueia por limite', () {
      final r = _avaliar(
        const [],
        cliente: _cliente(valorEmAberto: 150, limiteCredito: 200),
        novaVenda: 500,
        regra: const RegraBloqueio(bloquearPorLimite: false),
      );
      expect(r.deveBloquear, isFalse);
    });

    test('atraso tem prioridade sobre limite no motivo', () {
      final r = _avaliar([
        _parcela('a', _diasAtras(20)),
      ], cliente: _cliente(valorEmAberto: 500, limiteCredito: 200));
      expect(r.motivo, MotivoBloqueio.atrasoAcimaDoLimite);
    });
  });

  group('bloqueio manual', () {
    test('prevalece: continua bloqueado mesmo sem atraso nem limite', () {
      final cliente = _cliente(bloqueado: true);
      final r = _avaliar(const [], cliente: cliente);
      expect(r.deveBloquear, isFalse);
      expect(r.bloqueioManual, isTrue);
      expect(r.bloqueado, isTrue);

      final s = situacaoDoCliente(cliente, r, agora: _agora);
      expect(s.status, StatusPagamento.bloqueado);
      expect(s.bloqueioManual, isTrue);
      expect(s.motivo, 'Bloqueio manual');
    });

    test('some o bloqueio automático mas o manual permanece', () {
      final cliente = _cliente(bloqueado: true, valorEmAberto: 100);
      final atrasada = _avaliar([
        _parcela('a', _diasAtras(30)),
      ], cliente: cliente);
      expect(atrasada.deveBloquear, isTrue);
      final quitada = _avaliar(const [], cliente: cliente);
      expect(quitada.deveBloquear, isFalse);
      expect(quitada.bloqueado, isTrue);
    });
  });

  group('situacaoDoCliente', () {
    test('bloqueio automático vira status bloqueado com o motivo', () {
      final cliente = _cliente(valorEmAberto: 100);
      final r = _avaliar([_parcela('a', _diasAtras(23))], cliente: cliente);
      final s = situacaoDoCliente(cliente, r, agora: _agora);
      expect(s.status, StatusPagamento.bloqueado);
      expect(s.bloqueioManual, isFalse);
      expect(s.motivo, 'Atraso de 23 dias');
    });

    test('atraso dentro da tolerância continua "em atraso"', () {
      final cliente = _cliente(
        valorEmAberto: 100,
        proximoVencimento: _diasAtras(5),
      );
      final r = _avaliar([_parcela('a', _diasAtras(5))], cliente: cliente);
      final s = situacaoDoCliente(cliente, r, agora: _agora);
      expect(s.status, StatusPagamento.emAtraso);
      expect(s.motivo, isNull);
    });

    test('sem pendência: em dia', () {
      final cliente = _cliente();
      final s = situacaoDoCliente(
        cliente,
        _avaliar(const [], cliente: cliente),
        agora: _agora,
      );
      expect(s.status, StatusPagamento.emDia);
      expect(s.bloqueado, isFalse);
    });
  });

  group('avaliarBloqueioPeloResumo', () {
    test('usa o próximo vencimento do cliente como maior atraso', () {
      final cliente = _cliente(
        valorEmAberto: 100,
        proximoVencimento: _diasAtras(23),
      );
      final r = avaliarBloqueioPeloResumo(
        cliente: cliente,
        agora: _agora,
        regra: regraBloqueioPadrao,
      );
      expect(r.deveBloquear, isTrue);
      expect(r.diasDeAtraso, 23);
      expect(r.saldoVencido, isNull);
    });

    test('mesma decisão da avaliação por parcelas', () {
      for (final dias in [0, 1, 14, 15, 16, 40]) {
        final cliente = _cliente(
          valorEmAberto: 100,
          proximoVencimento: _diasAtras(dias),
        );
        final porResumo = avaliarBloqueioPeloResumo(
          cliente: cliente,
          agora: _agora,
          regra: regraBloqueioPadrao,
        );
        final porParcelas = _avaliar([
          _parcela('a', _diasAtras(dias)),
        ], cliente: cliente);
        expect(
          porResumo.deveBloquear,
          porParcelas.deveBloquear,
          reason: '$dias',
        );
        expect(porResumo.diasDeAtraso, porParcelas.diasDeAtraso);
      }
    });

    test('sem débito, vencimento antigo não bloqueia', () {
      final cliente = _cliente(proximoVencimento: _diasAtras(60));
      final r = avaliarBloqueioPeloResumo(
        cliente: cliente,
        agora: _agora,
        regra: regraBloqueioPadrao,
      );
      expect(r.deveBloquear, isFalse);
    });

    test('situacaoDoClientePeloResumo aplica manual e automático', () {
      final manual = situacaoDoClientePeloResumo(
        _cliente(bloqueado: true),
        regra: regraBloqueioPadrao,
        agora: _agora,
      );
      expect(manual.bloqueioManual, isTrue);

      final automatico = situacaoDoClientePeloResumo(
        _cliente(valorEmAberto: 10, proximoVencimento: _diasAtras(16)),
        regra: regraBloqueioPadrao,
        agora: _agora,
      );
      expect(automatico.status, StatusPagamento.bloqueado);
      expect(automatico.motivo, 'Atraso de 16 dias');
    });
  });
}
