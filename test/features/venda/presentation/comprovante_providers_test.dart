import 'dart:convert';

import 'package:cesta_basica_lopez_mobile/core/domain/enums.dart';
import 'package:cesta_basica_lopez_mobile/features/cliente/data/cliente_model.dart';
import 'package:cesta_basica_lopez_mobile/features/cliente/presentation/cliente_providers.dart';
import 'package:cesta_basica_lopez_mobile/features/venda/data/parcela_model.dart';
import 'package:cesta_basica_lopez_mobile/features/venda/data/venda_model.dart';
import 'package:cesta_basica_lopez_mobile/features/venda/presentation/comprovante_providers.dart';
import 'package:cesta_basica_lopez_mobile/features/venda/presentation/pos_venda_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

final _agora = DateTime(2026, 11, 20, 16);

final _cliente = ClienteModel(
  id: 'c1',
  codigo: 'C-1',
  nome: 'Maria',
  cpf: '529.982.247-25',
  telefone: '1',
  endereco: 'Rua A',
  updatedAt: _agora,
);

final _venda = VendaModel(
  id: 'v1',
  clienteId: 'c1',
  clienteNome: 'Maria',
  vendedorUid: 'u',
  numeroNota: 123,
  data: _agora,
  itens: const [],
  valorTotal: 200,
  tipo: TipoVenda.parcelado,
  updatedAt: _agora,
);

final _parcelas = [
  ParcelaModel(
    id: 'p1',
    vendaId: 'v1',
    numero: 1,
    valor: 100,
    vencimento: DateTime(2026, 12, 1),
    pagamentos: [
      PagamentoModel(
        id: 'g1',
        valor: 40,
        data: DateTime(2026, 11, 15),
        forma: FormaPagamento.pix,
      ),
    ],
    updatedAt: _agora,
  ),
];

ProviderContainer _container({VendaModel? venda, ClienteModel? cliente}) {
  final c = ProviderContainer(
    overrides: [
      vendaPorIdProvider('v1').overrideWith((ref) => Stream.value(venda)),
      parcelasDaVendaProvider('v1')
          .overrideWith((ref) => Stream.value(_parcelas)),
      clientePorIdProvider('c1').overrideWith((ref) async => cliente),
    ],
  );
  addTearDown(c.dispose);
  return c;
}

/// O provider é autoDispose: um listener o mantém vivo, como a tela faz.
Future<ComprovanteGerado> _gerar(ProviderContainer c, ComprovanteArgs args) {
  c.listen(comprovanteProvider(args), (_, _) {});
  return c.read(comprovanteProvider(args).future);
}

Future<Object?> _erro(ProviderContainer c, ComprovanteArgs args) async {
  try {
    await _gerar(c, args);
    return null;
  } catch (e) {
    return e;
  }
}

void main() {
  const args = ComprovanteArgs(
    vendaId: 'v1',
    parcelaId: 'p1',
    pagamentoId: 'g1',
  );

  test('gera o comprovante com PDF e nome de arquivo', () async {
    final c = _container(venda: _venda, cliente: _cliente);
    final gerado = await _gerar(c, args);
    expect(ascii.decode(gerado.bytes.sublist(0, 4)), '%PDF');
    expect(gerado.nomeArquivo, 'comprovante-123-parcela1-20261115.pdf');
    expect(gerado.comprovante.saldoRestanteParcela, 60);
  });

  test('venda inexistente', () async {
    final c = _container(venda: null, cliente: _cliente);
    final erro = await _erro(c, args);
    expect(erro, isA<ComprovanteIndisponivel>());
    expect((erro! as ComprovanteIndisponivel).mensagem, contains('Venda'));
  });

  test('cliente inexistente', () async {
    final c = _container(venda: _venda, cliente: null);
    final erro = await _erro(c, args);
    expect((erro! as ComprovanteIndisponivel).mensagem, contains('Cliente'));
  });

  test('parcela inexistente', () async {
    final c = _container(venda: _venda, cliente: _cliente);
    final erro = await _erro(
      c,
      const ComprovanteArgs(vendaId: 'v1', parcelaId: 'x', pagamentoId: 'g1'),
    );
    expect((erro! as ComprovanteIndisponivel).mensagem, contains('Parcela'));
  });

  test('pagamento inexistente', () async {
    final c = _container(venda: _venda, cliente: _cliente);
    final erro = await _erro(
      c,
      const ComprovanteArgs(vendaId: 'v1', parcelaId: 'p1', pagamentoId: 'x'),
    );
    expect((erro! as ComprovanteIndisponivel).mensagem, contains('Pagamento'));
  });

  test('argumentos iguais são a mesma chave', () {
    const a = ComprovanteArgs(vendaId: 'v', parcelaId: 'p', pagamentoId: 'g');
    const b = ComprovanteArgs(vendaId: 'v', parcelaId: 'p', pagamentoId: 'g');
    expect(a, b);
    expect(a.hashCode, b.hashCode);
  });
}
