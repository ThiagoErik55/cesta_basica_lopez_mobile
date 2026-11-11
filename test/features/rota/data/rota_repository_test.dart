import 'package:cesta_basica_lopez_mobile/core/domain/enums.dart';
import 'package:cesta_basica_lopez_mobile/features/cliente/data/cliente_model.dart';
import 'package:cesta_basica_lopez_mobile/features/rota/data/rota_model.dart';
import 'package:cesta_basica_lopez_mobile/features/rota/data/rota_repository.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

final _antes = DateTime(2026, 11, 1);
final _agora = DateTime(2026, 11, 12, 9);

RotaModel _rota(
  String id,
  String nome, {
  LinhaAtendimento linha = LinhaAtendimento.toledo,
}) => RotaModel(
  id: id,
  codigo: 'R-$id',
  nome: nome,
  linhaAtendimento: linha,
  updatedAt: _antes,
);

ClienteModel _cliente(String id, {String? rotaId, bool deleted = false}) =>
    ClienteModel(
      id: id,
      codigo: 'C-$id',
      nome: 'Cliente $id',
      cpf: '00000000000',
      telefone: '',
      endereco: '',
      rotaId: rotaId,
      updatedAt: _antes,
      deleted: deleted,
    );

void main() {
  late FakeFirebaseFirestore db;
  late RotaRepository repo;

  setUp(() {
    db = FakeFirebaseFirestore();
    repo = RotaRepository(db);
  });

  Future<Map<String, dynamic>> doc(String id) async =>
      (await db.collection('rotas').doc(id).get()).data()!;

  test('criar grava o documento com o id da rota', () async {
    await repo.salvar(_rota('r1', 'Centro', linha: LinhaAtendimento.regional));

    final d = await doc('r1');
    expect(d['id'], 'r1');
    expect(d['codigo'], 'R-r1');
    expect(d['nome'], 'Centro');
    expect(d['linhaAtendimento'], 'regional');
    expect(d['deleted'], false);
  });

  test('salvar duas vezes o mesmo id não duplica o documento', () async {
    await repo.salvar(_rota('r1', 'Centro'));
    await repo.salvar(_rota('r1', 'Centro'));
    expect((await db.collection('rotas').get()).docs, hasLength(1));
  });

  group('editar (update parcial)', () {
    setUp(() => repo.salvar(_rota('r1', 'Centro')));

    test('só o nome: muda nome e updatedAt, preserva o resto', () async {
      await repo.atualizar('r1', nome: 'Centro Norte', agora: _agora);

      final d = await doc('r1');
      expect(d['nome'], 'Centro Norte');
      expect(d['updatedAt'], _agora.toIso8601String());
      expect(d['id'], 'r1'); // o id não muda
      expect(d['codigo'], 'R-r1');
      expect(d['linhaAtendimento'], 'toledo');
      expect(d['deleted'], false);
    });

    test('só a linha: o nome não é tocado', () async {
      await repo.atualizar(
        'r1',
        linhaAtendimento: LinhaAtendimento.regional,
        agora: _agora,
      );

      final d = await doc('r1');
      expect(d['linhaAtendimento'], 'regional');
      expect(d['nome'], 'Centro');
    });

    test('renomear mantém os clientes ligados (rotaId é o id)', () async {
      await db
          .collection('clientes')
          .doc('c1')
          .set(_cliente('c1', rotaId: 'r1').toMap());

      await repo.atualizar('r1', nome: 'Outro nome', agora: _agora);

      final clientes = await repo.observarClientesAtivos().first;
      expect(clientes.single.rotaId, 'r1');
      expect((await doc('r1'))['id'], 'r1');
    });
  });

  group('excluir lógico', () {
    setUp(() => repo.salvar(_rota('r1', 'Centro')));

    test(
      'marca deleted e atualiza updatedAt, sem apagar o documento',
      () async {
        await repo.remover('r1', agora: _agora);

        final d = await doc('r1');
        expect(d['deleted'], true);
        expect(d['updatedAt'], _agora.toIso8601String());
        expect(d['nome'], 'Centro');
      },
    );

    test('a lista ignora a rota excluída', () async {
      await repo.salvar(_rota('r2', 'Zona Sul'));
      await repo.remover('r1');

      final ativas = await repo.observarAtivas().first;
      expect(ativas.map((r) => r.id), ['r2']);
    });
  });

  test(
    'a lista traz só as ativas e acompanha mudanças em tempo real',
    () async {
      await repo.salvar(_rota('r1', 'Centro'));
      final emissoes = <List<String>>[];
      final sub = repo.observarAtivas().listen(
        (l) => emissoes.add([for (final r in l) r.id]..sort()),
      );
      await Future<void>.delayed(Duration.zero);

      await repo.salvar(_rota('r2', 'Zona Sul'));
      await Future<void>.delayed(Duration.zero);
      await repo.remover('r1');
      await Future<void>.delayed(Duration.zero);
      await sub.cancel();

      expect(emissoes.first, ['r1']);
      expect(emissoes.last, ['r2']);
    },
  );

  test('clientes ativos: ignora excluídos, em uma única leitura', () async {
    await db
        .collection('clientes')
        .doc('c1')
        .set(_cliente('c1', rotaId: 'r1').toMap());
    await db
        .collection('clientes')
        .doc('c2')
        .set(_cliente('c2', rotaId: 'r1', deleted: true).toMap());
    await db.collection('clientes').doc('c3').set(_cliente('c3').toMap());

    final clientes = await repo.observarClientesAtivos().first;
    expect(clientes.map((c) => c.id).toList()..sort(), ['c1', 'c3']);
  });

  test('o repositório não altera clientes ao mexer em rotas', () async {
    await repo.salvar(_rota('r1', 'Centro'));
    await db
        .collection('clientes')
        .doc('c1')
        .set(_cliente('c1', rotaId: 'r1').toMap());
    final antes = (await db.collection('clientes').doc('c1').get()).data();

    await repo.atualizar('r1', nome: 'Novo', agora: _agora);
    await repo.remover('r1', agora: _agora);

    expect((await db.collection('clientes').doc('c1').get()).data(), antes);
  });
}
