import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/domain/enums.dart';
import '../../../core/providers/firebase_providers.dart';
import '../../cliente/data/cliente_model.dart';
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
