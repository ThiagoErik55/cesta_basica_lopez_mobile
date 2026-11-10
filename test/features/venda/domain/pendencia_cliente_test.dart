import 'package:cesta_basica_lopez_mobile/features/cliente/data/cliente_model.dart';
import 'package:cesta_basica_lopez_mobile/features/cliente/domain/regra_bloqueio.dart';
import 'package:cesta_basica_lopez_mobile/features/venda/data/parcela_model.dart';
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

  test('bloqueio manual impede qualquer venda, à vista e parcelada', () {
    final p = avaliarPendencia(_cliente(bloqueado: true), agora: _agora);
    expect(p.nivel, NivelPendencia.bloqueado);
    expect(p.permiteParcelado, isFalse);
    expect(p.permiteAVista, isFalse);
    expect(p.mensagens.single, contains('manualmente'));
  });

  test('bloqueio por atraso impede só o parcelado; à vista liberada', () {
    final p = avaliarPendencia(
      _cliente(
        proximoVencimento: _agora.subtract(const Duration(days: 23)),
        valorEmAberto: 50,
      ),
      agora: _agora,
    );
    expect(p.nivel, NivelPendencia.bloqueado);
    expect(p.permiteParcelado, isFalse);
    expect(p.permiteAVista, isTrue);
    expect(p.mensagens.single, contains('23 dias'));
    expect(p.mensagens.single, contains('à vista'));
  });

  test('atraso exatamente na tolerância já bloqueia o parcelado', () {
    final p = avaliarPendencia(
      _cliente(
        proximoVencimento: _agora.subtract(const Duration(days: 15)),
        valorEmAberto: 50,
      ),
      agora: _agora,
    );
    expect(p.permiteParcelado, isFalse);
    final quase = avaliarPendencia(
      _cliente(
        proximoVencimento: _agora.subtract(const Duration(days: 14)),
        valorEmAberto: 50,
      ),
      agora: _agora,
    );
    expect(quase.permiteParcelado, isTrue);
    expect(quase.exigeAprovacaoParcelado, isTrue);
  });

  test('usa as parcelas pendentes quando carregadas', () {
    final parcela = ParcelaModel(
      id: 'p',
      vendaId: 'v',
      numero: 1,
      valor: 50,
      vencimento: _agora.subtract(const Duration(days: 20)),
      updatedAt: _agora,
    );
    final p = avaliarPendencia(
      _cliente(valorEmAberto: 50),
      parcelasPendentes: [parcela],
      agora: _agora,
    );
    expect(p.permiteParcelado, isFalse);
    expect(p.permiteAVista, isTrue);
  });

  test('regra mais branda deixa o mesmo atraso passar', () {
    final p = avaliarPendencia(
      _cliente(
        proximoVencimento: _agora.subtract(const Duration(days: 23)),
        valorEmAberto: 50,
      ),
      regra: const RegraBloqueio(diasToleranciaAtraso: 30),
      agora: _agora,
    );
    expect(p.permiteParcelado, isTrue);
    expect(p.exigeAprovacaoParcelado, isTrue);
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

  test('parcelado acima do limite é impedido, com os números', () {
    final p = avaliarPendencia(
      _cliente(limiteCredito: 200, valorEmAberto: 150),
      valorVendaParcelada: 100,
      agora: _agora,
    );
    expect(p.nivel, NivelPendencia.bloqueado);
    expect(p.permiteParcelado, isFalse);
    expect(p.permiteAVista, isTrue);
    final msg = p.mensagens.single;
    expect(msg, contains('200,00'));
    expect(msg, contains('150,00'));
    expect(msg, contains('50,00'));
  });

  test('a mesma venda à vista não estoura o limite', () {
    final p = avaliarPendencia(
      _cliente(limiteCredito: 200, valorEmAberto: 150),
      agora: _agora,
    );
    expect(p.nivel, NivelPendencia.nenhuma);
    expect(p.permiteAVista, isTrue);
  });

  test('com bloqueio por limite desligado, estourar só gera atenção', () {
    final p = avaliarPendencia(
      _cliente(limiteCredito: 200, valorEmAberto: 150),
      regra: const RegraBloqueio(bloquearPorLimite: false),
      valorVendaParcelada: 100,
      agora: _agora,
    );
    expect(p.nivel, NivelPendencia.atencao);
    expect(p.permiteParcelado, isTrue);
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
