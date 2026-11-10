import '../../../core/domain/entidade_base.dart';
import '../../../core/domain/enums.dart';
import '../../../core/utils/firestore_utils.dart';

class MovimentoEstoqueModel implements EntidadeBase {
  @override
  final String id;
  final String produtoId;
  final String? vendaId;
  final TipoMovimento tipo;
  final int quantidade;
  final DateTime data;
  final String vendedorUid;
  final double?
  custoUnitario; // custo de aquisição (entrada) ou do item (saída em venda)
  @override
  final DateTime updatedAt;
  @override
  final bool deleted;

  const MovimentoEstoqueModel({
    required this.id,
    required this.produtoId,
    this.vendaId,
    required this.tipo,
    required this.quantidade,
    required this.data,
    required this.vendedorUid,
    this.custoUnitario,
    required this.updatedAt,
    this.deleted = false,
  });

  /// Valor com sinal, para somatório do saldo.
  int get delta => tipo == TipoMovimento.entrada ? quantidade : -quantidade;

  @override
  Map<String, dynamic> toMap() => {
    'id': id,
    'produtoId': produtoId,
    'vendaId': vendaId,
    'tipo': tipo.name,
    'quantidade': quantidade,
    'data': data.toIso8601String(),
    'vendedorUid': vendedorUid,
    'custoUnitario': custoUnitario,
    'updatedAt': updatedAt.toIso8601String(),
    'deleted': deleted,
  };

  factory MovimentoEstoqueModel.fromMap(Map<String, dynamic> map) =>
      MovimentoEstoqueModel(
        id: map['id'] as String,
        produtoId: map['produtoId'] as String? ?? '',
        vendaId: map['vendaId'] as String?,
        tipo: lerEnum(TipoMovimento.values, map['tipo'], TipoMovimento.saida),
        quantidade: lerInt(map['quantidade']),
        data: lerData(map['data']),
        vendedorUid: map['vendedorUid'] as String? ?? '',
        custoUnitario: lerDoubleOpcional(map['custoUnitario']),
        updatedAt: lerData(map['updatedAt']),
        deleted: map['deleted'] as bool? ?? false,
      );
}
