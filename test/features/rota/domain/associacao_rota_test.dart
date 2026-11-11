import 'package:cesta_basica_lopez_mobile/core/domain/enums.dart';
import 'package:cesta_basica_lopez_mobile/features/cliente/data/cliente_model.dart';
import 'package:cesta_basica_lopez_mobile/features/rota/data/rota_model.dart';
import 'package:cesta_basica_lopez_mobile/features/rota/domain/associacao_rota.dart';
import 'package:flutter_test/flutter_test.dart';

final _t = DateTime(2026, 11, 13);

RotaModel _rota(String id, String nome, {bool deleted = false}) => RotaModel(
  id: id,
  codigo: 'R-$id',
  nome: nome,
  linhaAtendimento: LinhaAtendimento.toledo,
  updatedAt: _t,
  deleted: deleted,
);

ClienteModel _c(
  String id,
  String nome, {
  String? rotaId,
  String cpf = '52998224725',
  bool deleted = false,
  bool bloqueado = false,
}) => ClienteModel(
  id: id,
  codigo: 'C-$id',
  nome: nome,
  cpf: cpf,
  telefone: '',
  endereco: '',
  rotaId: rotaId,
  bloqueado: bloqueado,
  updatedAt: _t,
  deleted: deleted,
);

final _rotas = [_rota('a', 'Centro'), _rota('b', 'Norte')];

List<String> _ids(Iterable<ClienteModel> l) => [for (final c in l) c.id];

void main() {
  group('rotaValida / nomeDaRota', () {
    test('rota ativa vale', () {
      expect(rotaValida('a', _rotas), 'a');
      expect(nomeDaRota('b', _rotas), 'Norte');
    });

    test('nulo, vazio, inexistente e texto livre viram sem rota', () {
      expect(rotaValida(null, _rotas), isNull);
      expect(rotaValida('', _rotas), isNull);
      expect(rotaValida('zzz', _rotas), isNull);
      expect(rotaValida('Zona Sul', _rotas), isNull);
      expect(nomeDaRota('zzz', _rotas), isNull);
    });

    test('rota excluída conta como sem rota', () {
      final rotas = [_rota('a', 'Centro', deleted: true)];
      expect(rotaValida('a', rotas), isNull);
      expect(nomeDaRota('a', rotas), isNull);
    });
  });

  group('situacaoNaRota', () {
    test('sem rota, desta rota e de outra', () {
      SituacaoNaRota s(String? r) => situacaoNaRota(
        _c('1', 'X', rotaId: r),
        rotaId: 'a',
        rotas: _rotas,
      );
      expect(s(null), SituacaoNaRota.semRota);
      expect(s('a'), SituacaoNaRota.destaRota);
      expect(s('b'), SituacaoNaRota.outraRota);
    });

    test('rota inexistente ou excluída é tratada como sem rota', () {
      final rotas = [_rota('a', 'Centro'), _rota('x', 'Velha', deleted: true)];
      expect(
        situacaoNaRota(
          _c('1', 'X', rotaId: 'x'),
          rotaId: 'a',
          rotas: rotas,
        ),
        SituacaoNaRota.semRota,
      );
      expect(
        situacaoNaRota(
          _c('1', 'X', rotaId: 'fantasma'),
          rotaId: 'a',
          rotas: rotas,
        ),
        SituacaoNaRota.semRota,
      );
    });
  });

  group('filtrarClientesParaAssociacao', () {
    final clientes = [
      _c('1', 'Zeca', rotaId: 'a', cpf: '52998224725'),
      _c('2', 'Ângela', cpf: '11144477735'),
      _c('3', 'Beto', rotaId: 'b', cpf: '39053344705'),
      _c('4', 'Caio', rotaId: 'velha', cpf: '12345678909'),
      _c('5', 'Excluído', deleted: true),
      _c('6', 'Dora', bloqueado: true, cpf: '98765432100'),
    ];

    List<String> lista({
      FiltroAssociacao filtro = FiltroAssociacao.todos,
      String termo = '',
    }) => _ids(
      filtrarClientesParaAssociacao(
        clientes,
        rotaId: 'a',
        rotas: _rotas,
        filtro: filtro,
        termo: termo,
      ),
    );

    test('todos: ativos em ordem alfabética sem acento; excluído fora', () {
      expect(lista(), ['2', '3', '4', '6', '1']);
    });

    test('bloqueado continua podendo ser associado', () {
      expect(lista(), contains('6'));
    });

    test('sem rota inclui rota inexistente e exclui a de outra rota', () {
      expect(lista(filtro: FiltroAssociacao.semRota), ['2', '4', '6']);
    });

    test('desta rota', () {
      expect(lista(filtro: FiltroAssociacao.destaRota), ['1']);
    });

    test('de outras rotas', () {
      expect(lista(filtro: FiltroAssociacao.deOutrasRotas), ['3']);
    });

    test('busca por nome sem acento e sem maiúsculas', () {
      expect(lista(termo: 'angela'), ['2']);
      expect(lista(termo: 'ZEC'), ['1']);
    });

    test('busca por CPF parcial, com ou sem máscara', () {
      expect(lista(termo: '529982'), ['1']);
      expect(lista(termo: '529.982'), ['1']);
      expect(lista(termo: '390.533.447-05'), ['3']);
    });

    test('termo com letras e números não casa CPF', () {
      expect(lista(termo: 'zeca 5299'), isEmpty);
    });

    test('busca combina com o filtro', () {
      expect(lista(filtro: FiltroAssociacao.semRota, termo: 'dor'), ['6']);
      expect(lista(filtro: FiltroAssociacao.destaRota, termo: 'dor'), isEmpty);
    });

    test('sem resultado devolve lista vazia', () {
      expect(lista(termo: 'zzzz'), isEmpty);
    });
  });

  group('calcularDiffAssociacao', () {
    final clientes = [
      _c('1', 'Na rota', rotaId: 'a'),
      _c('2', 'Na rota 2', rotaId: 'a'),
      _c('3', 'Sem rota'),
      _c('4', 'Sem rota 2'),
      _c('5', 'Outra', rotaId: 'b'),
      _c('6', 'Outra 2', rotaId: 'b'),
      _c('7', 'Rota velha', rotaId: 'excluida'),
      _c('8', 'Excluído', deleted: true),
    ];

    DiffAssociacao diff(Map<String, bool> marcas) => calcularDiffAssociacao(
      clientes: clientes,
      marcas: marcas,
      rotaId: 'a',
      rotas: _rotas,
    );

    test('sem marcas nada muda', () {
      final d = diff({});
      expect(d.semMudancas, isTrue);
      expect(d.inalterados, hasLength(7)); // o excluído nem entra
      expect(d.novasRotas('a'), isEmpty);
    });

    test('adiciona, move e remove', () {
      final d = diff({
        '3': true, // sem rota → entra
        '4': true,
        '5': true, // de outra rota → movido
        '2': false, // da rota → removido
      });
      expect(d.adicionados, ['3', '4']);
      expect(d.movidos, ['5']);
      expect(d.removidos, ['2']);
      expect(d.associados, 3);
      expect(d.inalterados, containsAll(['1', '6', '7']));
      expect(d.novasRotas('a'), {'3': 'a', '4': 'a', '5': 'a', '2': null});
    });

    test('marcar quem já estava na rota não é mudança', () {
      expect(diff({'1': true}).semMudancas, isTrue);
    });

    test('desmarcar quem não estava marcado não é mudança', () {
      expect(diff({'3': false, '5': false}).semMudancas, isTrue);
    });

    test('marcar e desmarcar de volta zera a mudança (idempotente)', () {
      expect(diff({'3': false, '1': true}).semMudancas, isTrue);
    });

    test('cliente com rota excluída/inexistente marcado é "adicionado"', () {
      final d = diff({'7': true});
      expect(d.adicionados, ['7']);
      expect(d.movidos, isEmpty);
    });

    test('cliente excluído nunca entra no diff', () {
      final d = diff({'8': true});
      expect(d.adicionados, isEmpty);
      expect(d.novasRotas('a').containsKey('8'), isFalse);
    });

    test(
      'quem entrou na rota por outro aparelho não é removido sem querer',
      () {
        // 9 não existia quando o sheet abriu e não tem marca: fica como está.
        final d = calcularDiffAssociacao(
          clientes: [
            ...clientes,
            _c('9', 'Novo na rota', rotaId: 'a'),
          ],
          marcas: {},
          rotaId: 'a',
          rotas: _rotas,
        );
        expect(d.removidos, isEmpty);
        expect(d.semMudancas, isTrue);
      },
    );
  });

  group('textos', () {
    test('resumo com as três partes', () {
      const d = DiffAssociacao(
        adicionados: ['1', '2'],
        movidos: ['3'],
        removidos: ['4'],
      );
      expect(
        resumoDaAssociacao(d),
        '+3 associados, −1 removido, 1 movido de outra rota',
      );
    });

    test('resumo omite partes zeradas e trata plural', () {
      expect(
        resumoDaAssociacao(const DiffAssociacao(adicionados: ['1'])),
        '+1 associado',
      );
      expect(
        resumoDaAssociacao(const DiffAssociacao(removidos: ['1', '2'])),
        '−2 removidos',
      );
      expect(resumoDaAssociacao(const DiffAssociacao()), 'Nenhuma alteração.');
    });

    test('aviso de movidos só existe se houver movidos', () {
      expect(avisoDeMovidos(const DiffAssociacao(adicionados: ['1'])), isNull);
      expect(
        avisoDeMovidos(const DiffAssociacao(movidos: ['1'])),
        '1 cliente será movido de outra rota para esta.',
      );
      expect(
        avisoDeMovidos(const DiffAssociacao(movidos: ['1', '2', '3'])),
        '3 clientes serão movidos de outras rotas para esta.',
      );
    });

    test('mensagem de sucesso', () {
      expect(
        mensagemAssociacaoConcluida(
          const DiffAssociacao(adicionados: ['1', '2', '3']),
          'Centro',
        ),
        '3 clientes associados à rota Centro.',
      );
      expect(
        mensagemAssociacaoConcluida(
          const DiffAssociacao(adicionados: ['1']),
          'Centro',
        ),
        '1 cliente associado à rota Centro.',
      );
      expect(
        mensagemAssociacaoConcluida(
          const DiffAssociacao(removidos: ['1', '2']),
          'Centro',
        ),
        '2 clientes removidos da rota Centro.',
      );
      expect(
        mensagemAssociacaoConcluida(
          const DiffAssociacao(adicionados: ['1'], removidos: ['2']),
          'Centro',
        ),
        '1 cliente associado e 1 cliente removido na rota Centro.',
      );
    });
  });

  group('dividirEmLotes', () {
    test('1000 itens em lotes de 450, 450 e 100', () {
      final lotes = dividirEmLotes(List.generate(1000, (i) => i));
      expect(lotes.map((l) => l.length), [450, 450, 100]);
      expect(lotes.expand((l) => l).toList(), List.generate(1000, (i) => i));
    });

    test('exatamente 450 cabe em um lote; 451 vira dois', () {
      expect(dividirEmLotes(List.generate(450, (i) => i)), hasLength(1));
      expect(
        dividirEmLotes(List.generate(451, (i) => i)).map((l) => l.length),
        [450, 1],
      );
    });

    test('lista vazia: nenhum lote', () {
      expect(dividirEmLotes(<int>[]), isEmpty);
    });

    test('tamanho configurável', () {
      expect(dividirEmLotes([1, 2, 3, 4, 5], tamanho: 2), [
        [1, 2],
        [3, 4],
        [5],
      ]);
    });

    test('o limite é 450', () {
      expect(limiteOperacoesPorLote, 450);
    });
  });

  group('FiltroRotaCliente / clientePassaNoFiltroDeRota', () {
    test('igualdade por valor', () {
      expect(
        const FiltroRotaCliente.daRota('a'),
        const FiltroRotaCliente.daRota('a'),
      );
      expect(
        const FiltroRotaCliente.todas(),
        isNot(const FiltroRotaCliente.semRota()),
      );
      expect(const FiltroRotaCliente.todas().ativo, isFalse);
    });

    test('todas deixa todos passarem', () {
      expect(
        clientePassaNoFiltroDeRota(
          _c('1', 'X', rotaId: 'qualquer'),
          const FiltroRotaCliente.todas(),
          _rotas,
        ),
        isTrue,
      );
    });

    test('rota específica', () {
      const f = FiltroRotaCliente.daRota('a');
      expect(
        clientePassaNoFiltroDeRota(_c('1', 'X', rotaId: 'a'), f, _rotas),
        isTrue,
      );
      expect(
        clientePassaNoFiltroDeRota(_c('1', 'X', rotaId: 'b'), f, _rotas),
        isFalse,
      );
      expect(clientePassaNoFiltroDeRota(_c('1', 'X'), f, _rotas), isFalse);
    });

    test('sem rota inclui rota excluída, inexistente e texto livre', () {
      const f = FiltroRotaCliente.semRota();
      bool passa(String? r) =>
          clientePassaNoFiltroDeRota(_c('1', 'X', rotaId: r), f, _rotas);
      expect(passa(null), isTrue);
      expect(passa(''), isTrue);
      expect(passa('fantasma'), isTrue);
      expect(passa('Zona Sul'), isTrue);
      expect(passa('a'), isFalse);
    });

    test('rotas ainda não carregadas: sem rota só vale para rotaId vazio', () {
      const f = FiltroRotaCliente.semRota();
      expect(clientePassaNoFiltroDeRota(_c('1', 'X'), f, null), isTrue);
      expect(
        clientePassaNoFiltroDeRota(_c('1', 'X', rotaId: 'a'), f, null),
        isFalse,
      );
    });
  });
}
