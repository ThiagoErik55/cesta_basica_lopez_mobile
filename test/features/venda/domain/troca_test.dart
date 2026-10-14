import 'package:cesta_basica_lopez_mobile/core/domain/enums.dart';
import 'package:cesta_basica_lopez_mobile/features/produto/data/produto_model.dart';
import 'package:cesta_basica_lopez_mobile/features/venda/data/venda_model.dart';
import 'package:cesta_basica_lopez_mobile/features/venda/domain/troca.dart';
import 'package:flutter_test/flutter_test.dart';

final _data = DateTime(2026, 10, 14);

const _arroz = ItemVenda(
  id: 'i1',
  produtoId: 'arroz',
  nome: 'Arroz 5kg',
  quantidade: 3,
  precoUnitario: 27.5,
  custoUnitario: 20,
);

ProdutoModel _produto(String id, double preco) => ProdutoModel(
  id: id,
  codigo: id,
  nome: id,
  marca: '',
  categoria: '',
  preco: preco,
  updatedAt: _data,
);

VendaModel _venda({List<TrocaItem> trocas = const []}) => VendaModel(
  id: 'v1',
  clienteId: 'c1',
  clienteNome: 'Maria',
  vendedorUid: 'u1',
  numeroNota: 1,
  data: _data,
  itens: const [_arroz],
  trocas: trocas,
  valorTotal: 82.5,
  tipo: TipoVenda.aVista,
  updatedAt: _data,
);

void main() {
  test('quantidade trocável desconta trocas anteriores', () {
    expect(quantidadeTrocavel(_venda(), _arroz), 3);
    final venda = _venda(
      trocas: [
        TrocaItem(
          id: 't1',
          itemOriginalId: 'i1',
          produtoNovoId: 'feijao',
          produtoNovoNome: 'Feijão',
          quantidade: 2,
          data: _data,
        ),
      ],
    );
    expect(quantidadeTrocavel(venda, _arroz), 1);
  });

  test('diferença positiva quando o novo é mais caro', () {
    expect(
      diferencaTroca(
        original: _arroz,
        novo: _produto('cafe', 30),
        quantidade: 2,
      ),
      5,
    );
  });

  test('diferença negativa quando o novo é mais barato', () {
    expect(
      diferencaTroca(
        original: _arroz,
        novo: _produto('feijao', 8.9),
        quantidade: 1,
      ),
      -18.6,
    );
  });

  test('acrescentarObservacao junta com quebra de linha', () {
    expect(acrescentarObservacao(null, 'a'), 'a');
    expect(acrescentarObservacao('  ', 'a'), 'a');
    expect(acrescentarObservacao('x', 'a'), 'x\na');
  });
}
