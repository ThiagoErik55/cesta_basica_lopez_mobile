import 'package:cesta_basica_lopez_mobile/features/estoque/domain/controle_estoque.dart';
import 'package:cesta_basica_lopez_mobile/features/produto/data/produto_model.dart';
import 'package:flutter_test/flutter_test.dart';

ItemEstoque _i(String nome, int estoque, int minimo, {bool deleted = false}) =>
    ItemEstoque.de(
      ProdutoModel(
        id: nome.toLowerCase(),
        codigo: 'P-$nome',
        nome: nome,
        marca: 'M',
        categoria: 'C',
        preco: 10,
        estoqueAtual: estoque,
        estoqueMinimo: minimo,
        deleted: deleted,
        updatedAt: DateTime(2026, 11, 11),
      ),
    );

List<String> _nomes(List<ItemEstoque> itens) => [
  for (final i in itens) i.produto.nome,
];

void main() {
  group('emAlerta / contarAlertas', () {
    test('baixo, sem estoque e negativo alertam; normal não', () {
      expect(emAlerta(_i('A', 50, 10)), isFalse);
      expect(emAlerta(_i('B', 5, 10)), isTrue);
      expect(emAlerta(_i('C', 0, 10)), isTrue);
      expect(emAlerta(_i('D', -3, 10)), isTrue);
    });

    test('estoque exatamente igual ao mínimo é baixo (regra da KAN-41)', () {
      final item = _i('A', 10, 10);
      expect(item.situacao, SituacaoEstoque.baixo);
      expect(emAlerta(item), isTrue);
      // Um acima do mínimo já é normal.
      expect(emAlerta(_i('B', 11, 10)), isFalse);
    });

    test('mínimo 0 nunca fica em baixo: só sem estoque ou negativo', () {
      expect(_i('A', 1, 0).situacao, SituacaoEstoque.normal);
      expect(emAlerta(_i('A', 1, 0)), isFalse);
      expect(_i('B', 0, 0).situacao, SituacaoEstoque.semEstoque);
      expect(emAlerta(_i('B', 0, 0)), isTrue);
      expect(emAlerta(_i('C', -2, 0)), isTrue);
    });

    test('conta baixo + sem estoque + negativo', () {
      final itens = [
        _i('A', 50, 10),
        _i('B', 5, 10),
        _i('C', 0, 10),
        _i('D', -3, 10),
        _i('E', 1, 0),
      ];
      expect(contarAlertas(itens), 3);
      expect(contarAlertas(const []), 0);
    });

    test('produto excluído não entra na contagem', () {
      final itens = montarItensEstoque([
        _i('A', 0, 10).produto,
        _i('B', 0, 10, deleted: true).produto,
      ]);
      expect(contarAlertas(itens), 1);
    });

    test('o resumo e o alerta concordam: baixo + sem estoque', () {
      final itens = [_i('A', 5, 10), _i('B', 0, 10), _i('C', -1, 10)];
      final r = resumirEstoque(itens);
      expect(contarAlertas(itens), r.estoqueBaixo + r.semEstoque);
    });
  });

  group('filtrarEstoque com apenasAlertas', () {
    final todos = [
      _i('Arroz', 50, 10),
      _i('Feijão', 5, 10),
      _i('Açúcar', 0, 10),
      _i('Sal', -1, 10),
    ];

    test('deixa só baixo, sem estoque e negativo', () {
      expect(_nomes(filtrarEstoque(todos, apenasAlertas: true)), [
        'Feijão',
        'Açúcar',
        'Sal',
      ]);
    });

    test('combina com a busca', () {
      expect(
        _nomes(filtrarEstoque(todos, apenasAlertas: true, termo: 'acucar')),
        ['Açúcar'],
      );
      expect(
        filtrarEstoque(todos, apenasAlertas: true, termo: 'arroz'),
        isEmpty,
      );
    });

    test('sem alertas devolve lista vazia', () {
      expect(filtrarEstoque([_i('A', 50, 10)], apenasAlertas: true), isEmpty);
    });
  });

  group('faltamParaMinimo', () {
    test('mínimo menos saldo', () {
      expect(faltamParaMinimo(estoqueAtual: 3, estoqueMinimo: 10), 7);
      expect(faltamParaMinimo(estoqueAtual: 0, estoqueMinimo: 10), 10);
    });

    test('saldo negativo conta a partir do saldo', () {
      expect(faltamParaMinimo(estoqueAtual: -3, estoqueMinimo: 10), 13);
    });

    test('nunca é negativo', () {
      expect(faltamParaMinimo(estoqueAtual: 10, estoqueMinimo: 10), 0);
      expect(faltamParaMinimo(estoqueAtual: 50, estoqueMinimo: 10), 0);
      expect(faltamParaMinimo(estoqueAtual: 3, estoqueMinimo: 0), 0);
    });

    test('mínimo 0: só falta algo com saldo negativo', () {
      expect(faltamParaMinimo(estoqueAtual: 0, estoqueMinimo: 0), 0);
      expect(faltamParaMinimo(estoqueAtual: -2, estoqueMinimo: 0), 2);
    });
  });

  group('textoFaltaParaMinimo', () {
    test('mostra quantas unidades faltam', () {
      expect(
        textoFaltaParaMinimo(_i('A', 3, 10)),
        'Faltam 7 un. para o mínimo (10)',
      );
      expect(
        textoFaltaParaMinimo(_i('B', -3, 10)),
        'Faltam 13 un. para o mínimo (10)',
      );
    });

    test('no limite do mínimo não diz "faltam 0"', () {
      expect(textoFaltaParaMinimo(_i('A', 10, 10)), 'No limite do mínimo');
    });

    test('nulo fora de alerta e com mínimo 0', () {
      expect(textoFaltaParaMinimo(_i('A', 50, 10)), isNull);
      expect(textoFaltaParaMinimo(_i('B', 0, 0)), isNull);
    });
  });

  group('ordenarAlertas', () {
    test('negativo e sem estoque antes de baixo', () {
      final ordenados = ordenarAlertas([
        _i('Baixo', 2, 10),
        _i('Zero', 0, 10),
        _i('Negativo', -4, 10),
      ]);
      expect(_nomes(ordenados), ['Negativo', 'Zero', 'Baixo']);
    });

    test('no grupo, menor relação saldo/mínimo primeiro', () {
      // 1/10 = 0,1 · 3/10 = 0,3 · 2/4 = 0,5
      final ordenados = ordenarAlertas([
        _i('C', 2, 4),
        _i('A', 1, 10),
        _i('B', 3, 10),
      ]);
      expect(_nomes(ordenados), ['A', 'B', 'C']);
    });

    test('relação igual desempata por nome, sem acento', () {
      final ordenados = ordenarAlertas([
        _i('Sal', 5, 10),
        _i('Açúcar', 5, 10),
        _i('Café', 5, 10),
      ]);
      expect(_nomes(ordenados), ['Açúcar', 'Café', 'Sal']);
    });

    test('negativo vem antes de zero no mesmo grupo', () {
      final ordenados = ordenarAlertas([_i('A', 0, 10), _i('B', -1, 10)]);
      expect(_nomes(ordenados), ['B', 'A']);
    });

    test('mínimo 0 não divide por zero', () {
      final ordenados = ordenarAlertas([
        _i('A', 0, 0),
        _i('B', -2, 0),
        _i('C', 3, 10),
      ]);
      expect(_nomes(ordenados), ['B', 'A', 'C']);
    });

    test('normais, se vierem na lista, ficam por último', () {
      final ordenados = ordenarAlertas([
        _i('Normal', 50, 10),
        _i('Baixo', 2, 10),
      ]);
      expect(_nomes(ordenados), ['Baixo', 'Normal']);
    });

    test('não altera a lista original', () {
      final original = [_i('B', 5, 10), _i('A', 0, 10)];
      ordenarAlertas(original);
      expect(_nomes(original), ['B', 'A']);
    });
  });

  group('textoFaixaAlertas', () {
    test('singular, plural e zero', () {
      expect(textoFaixaAlertas(0), isNull);
      expect(textoFaixaAlertas(1), '1 produto com estoque baixo ou zerado');
      expect(textoFaixaAlertas(4), '4 produtos com estoque baixo ou zerado');
    });
  });

  group('avisoAposEntrada', () {
    test('continua abaixo do mínimo: diz quanto falta', () {
      expect(
        avisoAposEntrada(estoqueApos: 6, estoqueMinimo: 10),
        'Ainda abaixo do mínimo: faltam 4 un.',
      );
    });

    test('saldo negativo que segue negativo ou zero', () {
      expect(
        avisoAposEntrada(estoqueApos: -2, estoqueMinimo: 10),
        'Ainda abaixo do mínimo: faltam 12 un.',
      );
      expect(
        avisoAposEntrada(estoqueApos: 0, estoqueMinimo: 10),
        'Ainda abaixo do mínimo: faltam 10 un.',
      );
    });

    test('exatamente no mínimo: ainda é baixo, mas não falta nada', () {
      expect(
        avisoAposEntrada(estoqueApos: 10, estoqueMinimo: 10),
        'Estoque no limite do mínimo.',
      );
    });

    test('acima do mínimo: sem aviso', () {
      expect(avisoAposEntrada(estoqueApos: 11, estoqueMinimo: 10), isNull);
    });

    test('mínimo 0: positivo sem aviso; negativo ainda falta; zero fica '
        'sem estoque', () {
      expect(avisoAposEntrada(estoqueApos: 5, estoqueMinimo: 0), isNull);
      expect(
        avisoAposEntrada(estoqueApos: -3, estoqueMinimo: 0),
        'Ainda abaixo do mínimo: faltam 3 un.',
      );
      expect(
        avisoAposEntrada(estoqueApos: 0, estoqueMinimo: 0),
        'O produto continua sem estoque.',
      );
    });
  });
}
