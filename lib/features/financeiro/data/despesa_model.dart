import '../../../core/domain/entidade_base.dart';
import '../../../core/utils/firestore_utils.dart';

class DespesaModel implements EntidadeBase {
  @override
  final String id;
  final String vendedorUid;
  final String descricao;
  final double valor;
  final DateTime data;
  @override
  final DateTime updatedAt;
  @override
  final bool deleted;

  const DespesaModel({
    required this.id,
    required this.vendedorUid,
    required this.descricao,
    required this.valor,
    required this.data,
    required this.updatedAt,
    this.deleted = false,
  });

  @override
  Map<String, dynamic> toMap() => {
    'id': id,
    'vendedorUid': vendedorUid,
    'descricao': descricao,
    'valor': valor,
    'data': data.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
    'deleted': deleted,
  };

  factory DespesaModel.fromMap(Map<String, dynamic> map) => DespesaModel(
    id: map['id'] as String,
    vendedorUid: map['vendedorUid'] as String? ?? '',
    descricao: map['descricao'] as String? ?? '',
    valor: lerDouble(map['valor']),
    data: lerData(map['data']),
    updatedAt: lerData(map['updatedAt']),
    deleted: map['deleted'] as bool? ?? false,
  );

  DespesaModel copyWith({
    String? descricao,
    double? valor,
    DateTime? data,
    bool? deleted,
  }) => DespesaModel(
    id: id,
    vendedorUid: vendedorUid,
    descricao: descricao ?? this.descricao,
    valor: valor ?? this.valor,
    data: data ?? this.data,
    updatedAt: DateTime.now(),
    deleted: deleted ?? this.deleted,
  );
}