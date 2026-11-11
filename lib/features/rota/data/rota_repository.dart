import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/domain/enums.dart';
import '../../../core/providers/firebase_providers.dart';
import '../../cliente/data/cliente_model.dart';
import '../domain/associacao_rota.dart';
import 'rota_model.dart';

/// Acesso às rotas (KAN-45). Escritas em um único documento: o `set` com
/// id gerado no cliente não duplica na sincronização offline.
class RotaRepository {
  RotaRepository(this._db);
  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> get _rotas =>
      _db.collection('rotas');

  CollectionReference<Map<String, dynamic>> get _clientes =>
      _db.collection('clientes');

  /// Cria a rota (ou regrava com o mesmo id).
  Future<void> salvar(RotaModel rota) => _rotas.doc(rota.id).set(rota.toMap());

  /// Atualização parcial: só os campos informados (e `updatedAt`) são
  /// escritos. O id não muda, então os clientes com este `rotaId`
  /// continuam associados depois de renomear.
  Future<void> atualizar(
    String id, {
    String? nome,
    LinhaAtendimento? linhaAtendimento,
    DateTime? agora,
  }) => _rotas.doc(id).update({
    'nome': ?nome,
    'linhaAtendimento': ?linhaAtendimento?.name,
    'updatedAt': (agora ?? DateTime.now()).toIso8601String(),
  });

  /// Exclusão lógica. A regra de só excluir rota sem clientes é checada
  /// antes, em `motivoBloqueioExclusaoRota`.
  Future<void> remover(String id, {DateTime? agora}) => _rotas.doc(id).update({
    'deleted': true,
    'updatedAt': (agora ?? DateTime.now()).toIso8601String(),
  });

  /// Define a rota de vários clientes (KAN-46): `clienteId → rotaId`, com
  /// `null` para tirar o cliente da rota.
  ///
  /// Cada cliente recebe um **update parcial** de `rotaId` e `updatedAt`;
  /// nenhum outro campo é regravado, então não há como sobrescrever, por
  /// exemplo, o crédito ou o valor em aberto que mudaram em outro
  /// aparelho. Quem chama deve passar só os clientes que realmente
  /// mudaram: mapa vazio não grava nada.
  ///
  /// As escritas vão em batches de até [tamanhoLote] operações (padrão
  /// [limiteOperacoesPorLote]). Os batches são todos enviados de uma vez,
  /// **sem esperar um confirmar antes de criar o próximo**: offline, um
  /// batch só completa quando a conexão volta, e esperar por ele
  /// impediria os demais de entrarem na fila local. Cada batch é atômico;
  /// entre batches, não (só importa acima de [tamanhoLote] clientes).
  Future<void> atribuirRotas(
    Map<String, String?> novasRotas, {
    DateTime? agora,
    int tamanhoLote = limiteOperacoesPorLote,
  }) {
    if (novasRotas.isEmpty) return Future.value();
    final instante = (agora ?? DateTime.now()).toIso8601String();

    final commits = <Future<void>>[];
    for (final lote in dividirEmLotes(
      novasRotas.entries.toList(),
      tamanho: tamanhoLote,
    )) {
      final batch = _db.batch();
      for (final e in lote) {
        batch.update(_clientes.doc(e.key), {
          'rotaId': e.value,
          'updatedAt': instante,
        });
      }
      commits.add(batch.commit());
    }
    return Future.wait(commits).then((_) {});
  }

  /// Rotas ativas em tempo real. Lê a coleção inteira e ignora as
  /// excluídas em memória: sem índice composto (poucas rotas).
  Stream<List<RotaModel>> observarAtivas() =>
      _rotas.snapshots().map(_rotasAtivas);

  /// Rotas ativas só do cache local, para quando o servidor não responde.
  Future<List<RotaModel>> ativasEmCache() async =>
      _rotasAtivas(await _rotas.get(const GetOptions(source: Source.cache)));

  /// Clientes ativos em tempo real, em **uma** leitura da coleção, para
  /// contar e listar os clientes de todas as rotas em memória (sem um
  /// listener por rota). Fica aqui, na camada de rota, para não mexer no
  /// `ClienteRepository`.
  Stream<List<ClienteModel>> observarClientesAtivos() =>
      _clientes.snapshots().map(_clientesAtivos);

  Future<List<ClienteModel>> clientesAtivosEmCache() async => _clientesAtivos(
    await _clientes.get(const GetOptions(source: Source.cache)),
  );

  List<RotaModel> _rotasAtivas(QuerySnapshot<Map<String, dynamic>> s) => [
    for (final d in s.docs)
      if (!RotaModel.fromMap(d.data()).deleted) RotaModel.fromMap(d.data()),
  ];

  List<ClienteModel> _clientesAtivos(QuerySnapshot<Map<String, dynamic>> s) => [
    for (final d in s.docs)
      if (!ClienteModel.fromMap(d.data()).deleted)
        ClienteModel.fromMap(d.data()),
  ];
}

final rotaRepositoryProvider = Provider<RotaRepository>((ref) {
  return RotaRepository(ref.watch(firestoreProvider));
});
