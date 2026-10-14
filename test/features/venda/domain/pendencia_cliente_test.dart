import 'package:cesta_basica_lopez_mobile/features/cliente/data/cliente_model.dart';
import 'package:cesta_basica_lopez_mobile/features/venda/domain/pendencia_cliente.dart';
import 'package:flutter_test/flutter_test.dart';

final _agora = DateTime(2026, 10, 14, 12);

ClienteModel _cliente({
  bool bloqueado = false,
  DateTime? proximoVencimento,
  double valorEmAberto = 0,
  double limiteCredito = 0,
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
  limiteCredito: limiteCredito,
  updatedAt: _agora,
);

void main() {
  test('cliente em dia não tem pendência', () {
    final p = avaliarPendencia(_cliente(), agora: _agora);
    expect(p.nivel, NivelPendencia.nenhuma);
    expect(p.permiteParcelado, isTrue);
  });

  test('bloqueado não permite parcelado', () {
    final p = avaliarPendencia(_cliente(bloqueado: true), agora: _agora);
    expect(p.nivel, NivelPendencia.bloqueado);
    expect(p.permiteParcelado, isFalse);
  });

  test('em atraso pede aprovação no parcelado', () {
    final p = avaliarPendencia(
      _cliente(
        proximoVencimento: _agora.subtract(const Duration(days: 3)),
        valorEmAberto: 50,
      ),
      agora: _agora,
    );
    expect(p.nivel, NivelPendencia.atencao);
    expect(p.exigeAprovacaoParcelado, isTrue);
  });

  test('parcelado acima do limite gera atenção', () {
    final p = avaliarPendencia(
      _cliente(limiteCredito: 200, valorEmAberto: 150),
      valorVendaParcelada: 100,
      agora: _agora,
    );
    expect(p.nivel, NivelPendencia.atencao);
  });

  test('limite zero significa sem limite definido', () {
    final p = avaliarPendencia(
      _cliente(valorEmAberto: 1000),
      valorVendaParcelada: 500,
      agora: _agora,
    );
    expect(p.nivel, NivelPendencia.nenhuma);
  });
}
