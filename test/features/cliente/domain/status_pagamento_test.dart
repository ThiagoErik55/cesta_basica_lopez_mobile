import 'package:cesta_basica_lopez_mobile/features/cliente/data/cliente_model.dart';
import 'package:cesta_basica_lopez_mobile/features/cliente/domain/status_pagamento.dart';
import 'package:flutter_test/flutter_test.dart';

final _agora = DateTime(2026, 10, 1, 12);
final _ontem = _agora.subtract(const Duration(days: 1));
final _amanha = _agora.add(const Duration(days: 1));

ClienteModel _cliente({
  bool bloqueado = false,
  DateTime? proximoVencimento,
  double valorEmAberto = 0,
}) => ClienteModel(
  id: '1',
  codigo: 'C-1',
  nome: 'Maria',
  cpf: '529.982.247-25',
  telefone: '(45) 99999-0001',
  endereco: 'Rua A',
  bloqueado: bloqueado,
  proximoVencimento: proximoVencimento,
  valorEmAberto: valorEmAberto,
  updatedAt: _agora,
);

StatusPagamento _status(ClienteModel c) => statusPagamento(c, agora: _agora);

void main() {
  test('bloqueado tem prioridade, mesmo em atraso', () {
    expect(
      _status(
        _cliente(bloqueado: true, proximoVencimento: _ontem, valorEmAberto: 50),
      ),
      StatusPagamento.bloqueado,
    );
    expect(_status(_cliente(bloqueado: true)), StatusPagamento.bloqueado);
  });

  test('em atraso: vencimento passou e há valor em aberto', () {
    expect(
      _status(_cliente(proximoVencimento: _ontem, valorEmAberto: 50)),
      StatusPagamento.emAtraso,
    );
  });

  test('em dia: vencimento futuro', () {
    expect(
      _status(_cliente(proximoVencimento: _amanha, valorEmAberto: 50)),
      StatusPagamento.emDia,
    );
  });

  test('em dia: sem vencimento', () {
    expect(_status(_cliente()), StatusPagamento.emDia);
    expect(_status(_cliente(valorEmAberto: 50)), StatusPagamento.emDia);
  });

  test('em dia: vencimento antigo, mas nada em aberto', () {
    expect(_status(_cliente(proximoVencimento: _ontem)), StatusPagamento.emDia);
  });
}
