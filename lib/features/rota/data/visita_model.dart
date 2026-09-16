import '../../../core/domain/entidade_base.dart';
import '../../../core/utils/firestore_utils.dart';

class VisitaModel implements EntidadeBase {
  @override
  final String id;
  final String clienteId;
  final String clienteNome;
  final String rotaId;
  final String? vendaId;
  final DateTime dataPrevista;
  final bool realizada;
  @override
  final DateTime updatedAt;
  @override
  final bool deleted;

  const VisitaModel({
    required this.id,
    required this.clienteId,
    required this.clienteNome,
    required this.rotaId,
    this.vendaId,
    required this.dataPrevista,
    this.realizada = false,
    required this.updatedAt,
    this.deleted = false,
  });

  @override
  Map<String, dynamic> toMap() => {
    'id': id,
    'clienteId': clienteId,
    'clienteNome': clienteNome,
    'rotaId': rotaId,
    'vendaId': vendaId,
    'dataPrevista': dataPrevista.toIso8601String(),
    'realizada': realizada,
    'updatedAt': updatedAt.toIso8601String(),
    'deleted': deleted,
  };

  factory VisitaModel.fromMap(Map<String, dynamic> map) => VisitaModel(
    id: map['id'] as String,
    clienteId: map['clienteId'] as String? ?? '',
    clienteNome: map['clienteNome'] as String? ?? '',
    rotaId: map['rotaId'] as String? ?? '',
    vendaId: map['vendaId'] as String?,
    dataPrevista: lerData(map['dataPrevista']),
    realizada: map['realizada'] as bool? ?? false,
    updatedAt: lerData(map['updatedAt']),
    deleted: map['deleted'] as bool? ?? false,
  );
}
