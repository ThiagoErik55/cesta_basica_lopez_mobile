import 'package:cesta_basica_lopez_mobile/core/domain/enums.dart';
import 'package:cesta_basica_lopez_mobile/features/cliente/data/cliente_model.dart';
import 'package:cesta_basica_lopez_mobile/features/rota/data/rota_repository.dart';
import 'package:cesta_basica_lopez_mobile/features/rota/domain/associacao_rota.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

final _antes = DateTime(2026, 11, 1);
final _agora = DateTime(2026, 11, 13, 9);

ClienteModel _cliente(String id, {String? rotaId}) => ClienteModel(
  id: id,
  codigo: 'C-$id',
  nome: 'Cliente $id',
  cpf: '52998224725',
  telefone: '(45) 99999-0000',
  endereco: 'Rua $id',
  rotaId: rotaId,
  score: ScoreCliente.a,
  limiteCredito: 500,
  bloqueado: true,
  valorEmAberto: 123.45,
  updatedAt: _antes,
);

void main() {
  late FakeFirebaseFirestore db;
  late RotaRepository repo;

  setUp(() {
    db = FakeFirebaseFirestore();
    repo = RotaRepository(db);
  });

  Future<void> semear(Iterable<ClienteModel> clientes) async {
    for (final c in clientes) {
      await db.collection('clientes').doc(c.id).set(c.toMap());
    }
  }

  Future<Map<String, dynamic>> doc(String id) async =>
      (await db.collection('clientes').doc(id).get()).data()!;

  test('associa 3, move 1 de outra rota e remove 1: só rotaId e updatedAt '
      'mudam, e só nos clientes alterados', () async {
    await semear([
      _cliente('1'),
      _cliente('2'),
      _cliente('3'),
      _cliente('4', rotaId: 'outra'), // movido
      _cliente('5', rotaId: 'a'), // removido
      _cliente('6', rotaId: 'a'), // inalterado
      _cliente('7'), // inalterado
    ]);
    final antes = {
      for (final id in ['1', '2', '3', '4', '5', '6', '7']) id: await doc(id),
    };

    await repo.atribuirRotas({
      '1': 'a',
      '2': 'a',
      '3': 'a',
      '4': 'a',
      '5': null,
    }, agora: _agora);

    // Alterados: rotaId novo, updatedAt novo, o resto idêntico.
    for (final id in ['1', '2', '3', '4', '5']) {
      final depois = await doc(id);
      expect(
        depois['updatedAt'],
        _agora.toIso8601String(),
        reason: 'cliente $id',
      );
      final semRotaEUpdated = {...depois}
        ..remove('rotaId')
        ..remove('updatedAt');
      final antesSem = {...antes[id]!}
        ..remove('rotaId')
        ..remove('updatedAt');
      expect(semRotaEUpdated, antesSem, reason: 'cliente $id');
    }
    for (final id in ['1', '2', '3', '4']) {
      expect((await doc(id))['rotaId'], 'a');
    }
    expect((await doc('5'))['rotaId'], isNull);

    // Não alterados: documento idêntico ao de antes.
    expect(await doc('6'), antes['6']);
    expect(await doc('7'), antes['7']);
  });

  test('preserva crédito, score, bloqueio e valor em aberto', () async {
    await semear([_cliente('1')]);
    await repo.atribuirRotas({'1': 'a'}, agora: _agora);
    final d = await doc('1');
    expect(d['limiteCredito'], 500);
    expect(d['score'], 'a');
    expect(d['bloqueado'], true);
    expect(d['valorEmAberto'], 123.45);
    expect(d['nome'], 'Cliente 1');
    expect(d['cpf'], '52998224725');
  });

  test('mapa vazio (seleção sem mudança) não grava nada', () async {
    await semear([_cliente('1', rotaId: 'a')]);
    final antes = await doc('1');

    await repo.atribuirRotas({}, agora: _agora);

    expect(await doc('1'), antes);
  });

  test('1000 clientes são todos atualizados, em lotes', () async {
    await semear([for (var i = 0; i < 1000; i++) _cliente('c$i')]);

    await repo.atribuirRotas({
      for (var i = 0; i < 1000; i++) 'c$i': 'a',
    }, agora: _agora);

    final todos = (await db.collection('clientes').get()).docs;
    expect(todos, hasLength(1000));
    expect(todos.every((d) => d.data()['rotaId'] == 'a'), isTrue);
    expect(
      todos.every((d) => d.data()['updatedAt'] == _agora.toIso8601String()),
      isTrue,
    );
    // 1000 operações → 450 + 450 + 100.
    expect(dividirEmLotes(List.generate(1000, (i) => i)).map((l) => l.length), [
      450,
      450,
      100,
    ]);
  });

  test('lote menor que o total ainda grava todos', () async {
    await semear([for (var i = 0; i < 7; i++) _cliente('c$i')]);
    await repo.atribuirRotas(
      {for (var i = 0; i < 7; i++) 'c$i': 'a'},
      agora: _agora,
      tamanhoLote: 3,
    );
    final todos = (await db.collection('clientes').get()).docs;
    expect(todos.every((d) => d.data()['rotaId'] == 'a'), isTrue);
  });

  test('cliente inexistente faz o batch falhar (nada é criado)', () async {
    await expectLater(
      repo.atribuirRotas({'fantasma': 'a'}, agora: _agora),
      throwsA(anything),
    );
    expect((await db.collection('clientes').get()).docs, isEmpty);
  });

  test('a contagem em tempo real acompanha a associação', () async {
    await semear([_cliente('1'), _cliente('2')]);
    final contagens = <int>[];
    final sub = repo.observarClientesAtivos().listen(
      (l) => contagens.add(l.where((c) => c.rotaId == 'a').length),
    );
    await Future<void>.delayed(Duration.zero);

    await repo.atribuirRotas({'1': 'a', '2': 'a'}, agora: _agora);
    await Future<void>.delayed(Duration.zero);
    await repo.atribuirRotas({'1': null}, agora: _agora);
    await Future<void>.delayed(Duration.zero);
    await sub.cancel();

    expect(contagens.first, 0);
    expect(contagens.last, 1);
  });
}
