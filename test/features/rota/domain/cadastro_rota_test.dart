import 'package:cesta_basica_lopez_mobile/core/domain/enums.dart';
import 'package:cesta_basica_lopez_mobile/features/cliente/data/cliente_model.dart';
import 'package:cesta_basica_lopez_mobile/features/rota/data/rota_model.dart';
import 'package:cesta_basica_lopez_mobile/features/rota/domain/cadastro_rota.dart';
import 'package:flutter_test/flutter_test.dart';

final _t = DateTime(2026, 11, 12);

RotaModel _r(String id, String nome, {bool deleted = false}) => RotaModel(
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
  bool deleted = false,
}) => ClienteModel(
  id: id,
  codigo: 'C-$id',
  nome: nome,
  cpf: '00000000000',
  telefone: '',
  endereco: '',
  rotaId: rotaId,
  updatedAt: _t,
  deleted: deleted,
);

void main() {
  group('validarNomeRota', () {
    final rotas = [_r('1', 'Centro'), _r('2', 'São Cristóvão')];

    test('vazio ou só espaços', () {
      expect(validarNomeRota('', rotas: rotas), 'Informe o nome da rota.');
      expect(validarNomeRota('   ', rotas: rotas), 'Informe o nome da rota.');
    });

    test('curto: 1 caractere recusa, 2 aceita (limite)', () {
      expect(
        validarNomeRota('A', rotas: rotas),
        'O nome deve ter pelo menos 2 caracteres.',
      );
      expect(validarNomeRota('AB', rotas: rotas), isNull);
    });

    test('os espaços das pontas não contam no tamanho', () {
      expect(
        validarNomeRota('  A  ', rotas: rotas),
        'O nome deve ter pelo menos 2 caracteres.',
      );
    });

    test('longo: 60 aceita, 61 recusa (limite)', () {
      expect(validarNomeRota('a' * 60, rotas: rotas), isNull);
      expect(
        validarNomeRota('a' * 61, rotas: rotas),
        'O nome deve ter no máximo 60 caracteres.',
      );
    });

    test('duplicado sem diferenciar maiúsculas', () {
      expect(
        validarNomeRota('CENTRO', rotas: rotas),
        'Já existe uma rota com esse nome.',
      );
    });

    test('duplicado sem diferenciar acento', () {
      expect(
        validarNomeRota('sao cristovao', rotas: rotas),
        'Já existe uma rota com esse nome.',
      );
      expect(
        validarNomeRota('Sao   Cristovao', rotas: rotas),
        'Já existe uma rota com esse nome.',
      );
    });

    test('na edição, o próprio nome não é duplicado', () {
      expect(validarNomeRota('Centro', rotas: rotas, idAtual: '1'), isNull);
      // Mudar só a caixa/acento da própria rota também passa.
      expect(
        validarNomeRota('são cristóvão', rotas: rotas, idAtual: '2'),
        isNull,
      );
    });

    test('na edição, o nome de OUTRA rota continua duplicado', () {
      expect(
        validarNomeRota('Centro', rotas: rotas, idAtual: '2'),
        'Já existe uma rota com esse nome.',
      );
    });

    test('rota excluída não conta como duplicada', () {
      expect(
        validarNomeRota('Antiga', rotas: [_r('3', 'Antiga', deleted: true)]),
        isNull,
      );
    });

    test('nome parecido, mas diferente, passa', () {
      expect(validarNomeRota('Centro Norte', rotas: rotas), isNull);
    });
  });

  group('limparNomeRota', () {
    test('apara e junta espaços repetidos', () {
      expect(limparNomeRota('  Vila   Nova  '), 'Vila Nova');
    });
  });

  group('contarClientesPorRota', () {
    test('conta por rotaId e ignora sem rota e excluídos', () {
      final contagem = contarClientesPorRota([
        _c('1', 'Ana', rotaId: 'a'),
        _c('2', 'Beto', rotaId: 'a'),
        _c('3', 'Caio', rotaId: 'b'),
        _c('4', 'Dora'),
        _c('5', 'Edu', rotaId: ''),
        _c('6', 'Fábio', rotaId: 'a', deleted: true),
      ]);
      expect(contagem, {'a': 2, 'b': 1});
    });

    test('sem clientes: mapa vazio', () {
      expect(contarClientesPorRota(const []), isEmpty);
    });
  });

  group('montarItensRota', () {
    test('rotas sem cliente ficam com 0; ordem por nome sem acento', () {
      final itens = montarItensRota(
        [_r('1', 'Zona Sul'), _r('2', 'Ágata'), _r('3', 'Centro')],
        [_c('1', 'Ana', rotaId: '3')],
      );
      expect(
        [for (final i in itens) i.rota.nome],
        ['Ágata', 'Centro', 'Zona Sul'],
      );
      expect([for (final i in itens) i.clientes], [0, 1, 0]);
    });

    test('rota excluída não aparece', () {
      final itens = montarItensRota([_r('1', 'A1', deleted: true)], const []);
      expect(itens, isEmpty);
    });

    test('clientes ainda não carregados: contagem desconhecida, não zero', () {
      final itens = montarItensRota([_r('1', 'Centro')], null);
      expect(itens.single.clientes, isNull);
    });
  });

  group('filtrarRotas', () {
    final itens = montarItensRota([
      _r('1', 'São Cristóvão'),
      _r('2', 'Centro'),
    ], const []);

    List<String> nomes(String termo) => [
      for (final i in filtrarRotas(itens, termo)) i.rota.nome,
    ];

    test('busca sem acento e sem maiúsculas, por trecho do nome', () {
      expect(nomes('sao crist'), ['São Cristóvão']);
      expect(nomes('CENT'), ['Centro']);
      expect(nomes('tro'), ['Centro']);
    });

    test('termo vazio devolve tudo; sem resultado, vazio', () {
      expect(nomes(''), ['Centro', 'São Cristóvão']);
      expect(nomes('   '), ['Centro', 'São Cristóvão']);
      expect(nomes('zzz'), isEmpty);
    });
  });

  group('nomesDosClientesDaRota', () {
    test('só os ativos da rota, em ordem alfabética sem acento', () {
      final nomes = nomesDosClientesDaRota('a', [
        _c('1', 'Zeca', rotaId: 'a'),
        _c('2', 'Ângela', rotaId: 'a'),
        _c('3', 'Beto', rotaId: 'b'),
        _c('4', 'Caio', rotaId: 'a', deleted: true),
        _c('5', 'Dora'),
      ]);
      expect(nomes, ['Ângela', 'Zeca']);
    });
  });

  group('motivoBloqueioExclusaoRota', () {
    test('sem clientes pode excluir', () {
      expect(motivoBloqueioExclusaoRota(0), isNull);
    });

    test('com clientes bloqueia e diz quantos', () {
      expect(
        motivoBloqueioExclusaoRota(3),
        'Remova ou mude os 3 clientes desta rota antes de excluir.',
      );
      expect(
        motivoBloqueioExclusaoRota(1),
        'Remova ou mude o cliente desta rota antes de excluir.',
      );
    });

    test('contagem desconhecida também bloqueia', () {
      expect(motivoBloqueioExclusaoRota(null), isNotNull);
    });
  });

  group('textoClientesDaRota', () {
    test('singular, plural, zero e desconhecido', () {
      expect(textoClientesDaRota(0), 'Nenhum cliente');
      expect(textoClientesDaRota(1), '1 cliente');
      expect(textoClientesDaRota(7), '7 clientes');
      expect(textoClientesDaRota(null), isNull);
    });
  });
}
