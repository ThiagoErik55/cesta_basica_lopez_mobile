import 'dart:convert';
import 'dart:typed_data';

import 'package:cesta_basica_lopez_mobile/core/domain/enums.dart';
import 'package:cesta_basica_lopez_mobile/features/cliente/data/cliente_model.dart';
import 'package:cesta_basica_lopez_mobile/features/cliente/presentation/cliente_providers.dart';
import 'package:cesta_basica_lopez_mobile/features/produto/data/produto_model.dart';
import 'package:cesta_basica_lopez_mobile/features/produto/data/produto_repository.dart';
import 'package:cesta_basica_lopez_mobile/features/venda/data/parcela_model.dart';
import 'package:cesta_basica_lopez_mobile/features/venda/data/venda_model.dart';
import 'package:cesta_basica_lopez_mobile/features/venda/presentation/nota_provisoria_providers.dart';
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

VendaModel _venda({List<ItemVenda>? itens, String? assinatura}) => VendaModel(
  id: 'v1',
  clienteId: 'c1',
  clienteNome: 'Maria',
  vendedorUid: 'u',
  numeroNota: 123,
  data: DateTime(2026, 11, 9),
  itens:
      itens ??
      const [
        ItemVenda(
          id: 'i1',
          produtoId: 'pr1',
          nome: 'Arroz',
          quantidade: 1,
          precoUnitario: 10,
          custoUnitario: 6,
        ),
      ],
  valorTotal: 10,
  formaPagamento: FormaPagamento.pix,
  tipo: TipoVenda.aVista,
  assinaturaBase64: assinatura,
  updatedAt: _agora,
);

/// Só `buscarPorId` é usado pelo provider.
class _ProdutosFalso implements ProdutoRepository {
  _ProdutosFalso({this.falha = false});

  final bool falha;

  @override
  Future<ProdutoModel?> buscarPorId(String id) async {
    if (falha) throw StateError('offline');
    return ProdutoModel(
      id: id,
      codigo: 'ARR-5',
      nome: 'Arroz',
      marca: 'M',
      categoria: 'Grãos',
      preco: 10,
      updatedAt: _agora,
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

ProviderContainer _container({
  VendaModel? venda,
  ClienteModel? cliente,
  bool produtosFalham = false,
}) {
  final c = ProviderContainer(
    overrides: [
      vendaPorIdProvider('v1').overrideWith((ref) => Stream.value(venda)),
      parcelasDaVendaProvider('v1')
          .overrideWith((ref) => Stream.value(const <ParcelaModel>[])),
      clientePorIdProvider('c1').overrideWith((ref) async => cliente),
      produtoRepositoryProvider.overrideWithValue(
        _ProdutosFalso(falha: produtosFalham),
      ),
    ],
  );
  addTearDown(c.dispose);
  return c;
}

/// O provider é autoDispose: um listener o mantém vivo, como a tela faz.
Future<NotaGerada> _gerar(ProviderContainer c) {
  c.listen(notaProvisoriaProvider('v1'), (_, _) {});
  return c.read(notaProvisoriaProvider('v1').future);
}

Future<Object?> _erro(ProviderContainer c) async {
  try {
    await _gerar(c);
    return null;
  } catch (e) {
    return e;
  }
}

void main() {
  test('gera a nota com PDF, nome de arquivo e código do produto', () async {
    final c = _container(venda: _venda(), cliente: _cliente);
    final gerado = await _gerar(c);
    expect(ascii.decode(gerado.bytes.sublist(0, 4)), '%PDF');
    expect(gerado.nomeArquivo, 'nota-123-20261109.pdf');
    expect(gerado.nota.itens.single.codigo, 'ARR-5');
  });

  test('sem o cadastro do produto a nota sai sem código', () async {
    final c = _container(
      venda: _venda(),
      cliente: _cliente,
      produtosFalham: true,
    );
    final gerado = await _gerar(c);
    expect(gerado.nota.itens.single.codigo, '');
  });

  test('venda inexistente', () async {
    final erro = await _erro(_container(venda: null, cliente: _cliente));
    expect(erro, isA<NotaIndisponivel>());
    expect((erro! as NotaIndisponivel).mensagem, 'Venda não encontrada.');
  });

  test('cliente inexistente', () async {
    final erro = await _erro(_container(venda: _venda(), cliente: null));
    expect((erro! as NotaIndisponivel).mensagem, 'Cliente não encontrado.');
  });

  test('venda sem itens', () async {
    final erro = await _erro(
      _container(
        venda: _venda(itens: const []),
        cliente: _cliente,
      ),
    );
    expect((erro! as NotaIndisponivel).mensagem, 'Venda sem itens.');
  });

  group('assinatura', () {
    // PNG 1x1 válido.
    final png = base64Decode(
      'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA'
      '60e6kgAAAABJRU5ErkJggg==',
    );

    test('válida: os bytes vão para a nota', () async {
      final c = _container(
        venda: _venda(assinatura: base64Encode(png)),
        cliente: _cliente,
      );
      final gerado = await _gerar(c);
      expect(gerado.nota.assinatura, png);
      expect(ascii.decode(gerado.bytes.sublist(0, 4)), '%PDF');
    });

    test('sem assinatura: nula', () async {
      final c = _container(venda: _venda(), cliente: _cliente);
      expect((await _gerar(c)).nota.assinatura, isNull);
    });

    test('base64 corrompido: nula e a nota sai', () async {
      final c = _container(
        venda: _venda(assinatura: '%%%corrompido%%%'),
        cliente: _cliente,
      );
      final gerado = await _gerar(c);
      expect(gerado.nota.assinatura, isNull);
      expect(ascii.decode(gerado.bytes.sublist(0, 4)), '%PDF');
    });

    test(
      'PNG com cabeçalho mas conteúdo quebrado: nula e a nota sai',
      () async {
        final quebrado = Uint8List.fromList([...png.sublist(0, 16), 1, 2, 3]);
        final c = _container(
          venda: _venda(assinatura: base64Encode(quebrado)),
          cliente: _cliente,
        );
        final gerado = await _gerar(c);
        expect(gerado.nota.assinatura, isNull);
        expect(ascii.decode(gerado.bytes.sublist(0, 4)), '%PDF');
      },
    );
  });
}
