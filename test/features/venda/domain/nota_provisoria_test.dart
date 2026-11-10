import 'package:cesta_basica_lopez_mobile/core/domain/enums.dart';
import 'package:cesta_basica_lopez_mobile/features/cliente/data/cliente_model.dart';
import 'package:cesta_basica_lopez_mobile/features/venda/data/parcela_model.dart';
import 'package:cesta_basica_lopez_mobile/features/venda/data/venda_model.dart';
import 'package:cesta_basica_lopez_mobile/features/venda/domain/nota_provisoria.dart';
import 'package:flutter_test/flutter_test.dart';

final _emissao = DateTime(2026, 11, 20, 16, 45);

final _cliente = ClienteModel(
  id: 'c1',
  codigo: 'C-1',
  nome: 'Maria da Silva',
  cpf: '529.982.247-25',
  telefone: '(45) 99999-0001',
  endereco: 'Rua A, 10',
  updatedAt: _emissao,
);

const _itens = [
  ItemVenda(
    id: 'i1',
    produtoId: 'p1',
    nome: 'Arroz 5kg',
    quantidade: 2,
    precoUnitario: 25.5,
    custoUnitario: 20,
  ),
  ItemVenda(
    id: 'i2',
    produtoId: 'p2',
    nome: 'Feijão 1kg',
    quantidade: 3,
    precoUnitario: 8.1,
    custoUnitario: 6,
  ),
];

VendaModel _venda({
  TipoVenda tipo = TipoVenda.aVista,
  FormaPagamento? forma = FormaPagamento.pix,
  double total = 75.3,
  List<TrocaItem> trocas = const [],
  List<ItemVenda> itens = _itens,
}) => VendaModel(
  id: 'v1',
  clienteId: 'c1',
  clienteNome: 'Maria da Silva',
  vendedorUid: 'u1',
  numeroNota: 2611091530,
  data: DateTime(2026, 11, 9, 14, 30),
  itens: itens,
  trocas: trocas,
  valorTotal: total,
  formaPagamento: forma,
  tipo: tipo,
  updatedAt: _emissao,
);

ParcelaModel _parcela(int n, double valor, {bool deleted = false}) =>
    ParcelaModel(
      id: 'pc$n',
      vendaId: 'v1',
      numero: n,
      valor: valor,
      vencimento: DateTime(2026, 12, n),
      updatedAt: _emissao,
      deleted: deleted,
    );

NotaProvisoria _ok(ResultadoNotaProvisoria r) {
  expect(r.erro, isNull);
  return r.nota!;
}

void main() {
  test('nota à vista: itens, totais, forma e CPF mascarado', () {
    final venda = _venda();
    final nota = _ok(
      montarNotaProvisoria(
        cliente: _cliente,
        venda: venda,
        itens: venda.itens,
        parcelas: const [],
        codigos: {'p1': 'ARR-5'},
        emitidoEm: _emissao,
      ),
    );

    expect(nota.numeroNota, 2611091530);
    expect(nota.clienteNome, 'Maria da Silva');
    expect(nota.cpfMascarado, '529.***.***-25');
    expect(nota.cpfMascarado.contains('982'), isFalse);
    expect(nota.telefone, '(45) 99999-0001');
    expect(nota.endereco, 'Rua A, 10');
    expect(nota.itens, hasLength(2));
    expect(nota.itens[0].codigo, 'ARR-5');
    expect(nota.itens[0].subtotal, 51);
    expect(nota.itens[1].codigo, '');
    expect(nota.itens[1].subtotal, 24.3);
    expect(nota.subtotal, 75.3);
    expect(nota.total, 75.3);
    expect(nota.temAjuste, isFalse);
    expect(nota.tipo, TipoVenda.aVista);
    expect(nota.forma, FormaPagamento.pix);
    expect(nota.parcelas, isEmpty);
    expect(nota.trocas, isEmpty);
    expect(nota.assinatura, isNull);
    expect(nota.emitidoEm, _emissao);
  });

  test('nota parcelada: tabela de parcelas ordenada, sem as removidas', () {
    final venda = _venda(tipo: TipoVenda.parcelado, forma: null);
    final nota = _ok(
      montarNotaProvisoria(
        cliente: _cliente,
        venda: venda,
        itens: venda.itens,
        parcelas: [
          _parcela(3, 25.1),
          _parcela(1, 25.1),
          _parcela(2, 25.1),
          _parcela(4, 99, deleted: true),
        ],
      ),
    );

    expect(nota.tipo, TipoVenda.parcelado);
    expect(nota.forma, isNull);
    expect(nota.parcelas.map((p) => p.numero), [1, 2, 3]);
    expect(nota.parcelas.first.vencimento, DateTime(2026, 12, 1));
    expect(nota.parcelas.first.valor, 25.1);
  });

  test('venda parcelada sem parcelas devolve erro', () {
    final venda = _venda(tipo: TipoVenda.parcelado, forma: null);
    final r = montarNotaProvisoria(
      cliente: _cliente,
      venda: venda,
      itens: venda.itens,
      parcelas: const [],
    );
    expect(r.ok, isFalse);
    expect(r.erro, 'Parcelas da venda não encontradas.');
  });

  test('venda com troca: seção de trocas sem alterar o total', () {
    final venda = _venda(
      trocas: [
        TrocaItem(
          id: 't1',
          itemOriginalId: 'i1',
          produtoNovoId: 'p9',
          produtoNovoNome: 'Arroz 2kg',
          quantidade: 1,
          diferencaValor: -10,
          data: DateTime(2026, 11, 12),
        ),
        TrocaItem(
          id: 't2',
          itemOriginalId: 'inexistente',
          produtoNovoId: 'p8',
          produtoNovoNome: 'Óleo',
          quantidade: 2,
          diferencaValor: 3,
          data: DateTime(2026, 11, 13),
        ),
      ],
    );
    final nota = _ok(
      montarNotaProvisoria(
        cliente: _cliente,
        venda: venda,
        itens: venda.itens,
        parcelas: const [],
      ),
    );

    expect(nota.trocas, hasLength(2));
    expect(nota.trocas[0].produtoOriginal, 'Arroz 5kg');
    expect(nota.trocas[0].produtoNovo, 'Arroz 2kg');
    expect(nota.trocas[0].diferenca, -10);
    expect(nota.trocas[1].produtoOriginal, 'Produto');
    expect(nota.total, 75.3);
    expect(nota.temAjuste, isFalse);
  });

  test('divergência de total (parcela alterada) vira Ajuste de parcela', () {
    final venda = _venda(tipo: TipoVenda.parcelado, forma: null, total: 80.3);
    final nota = _ok(
      montarNotaProvisoria(
        cliente: _cliente,
        venda: venda,
        itens: venda.itens,
        parcelas: [_parcela(1, 40.15), _parcela(2, 40.15)],
      ),
    );

    expect(nota.subtotal, 75.3);
    expect(nota.total, 80.3);
    expect(nota.ajusteParcela, 5);
    expect(nota.temAjuste, isTrue);
  });

  test('ajuste negativo e sem ruído de ponto flutuante', () {
    final venda = _venda(total: 75.2);
    final nota = _ok(
      montarNotaProvisoria(
        cliente: _cliente,
        venda: venda,
        itens: venda.itens,
        parcelas: const [],
      ),
    );
    expect(nota.ajusteParcela, -0.1);
  });

  test('venda sem itens devolve erro', () {
    final venda = _venda(itens: const []);
    final r = montarNotaProvisoria(
      cliente: _cliente,
      venda: venda,
      itens: venda.itens,
      parcelas: const [],
    );
    expect(r.ok, isFalse);
    expect(r.erro, 'Venda sem itens.');
  });

  test('venda ausente e cliente ausente devolvem erro', () {
    final venda = _venda();
    final semVenda = montarNotaProvisoria(
      cliente: _cliente,
      venda: null,
      itens: const [],
      parcelas: const [],
    );
    expect(semVenda.erro, 'Venda não encontrada.');

    final semCliente = montarNotaProvisoria(
      cliente: null,
      venda: venda,
      itens: venda.itens,
      parcelas: const [],
    );
    expect(semCliente.erro, 'Cliente não encontrado.');
  });

  test('nome do arquivo usa a nota e a data da venda', () {
    final venda = _venda();
    final nota = _ok(
      montarNotaProvisoria(
        cliente: _cliente,
        venda: venda,
        itens: venda.itens,
        parcelas: const [],
      ),
    );
    expect(nomeArquivoNota(nota), 'nota-2611091530-20261109.pdf');
  });
}
