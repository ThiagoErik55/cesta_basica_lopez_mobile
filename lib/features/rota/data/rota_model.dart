import '../../../core/domain/entidade_base.dart';
import '../../../core/domain/enums.dart';
import '../../../core/utils/firestore_utils.dart';

class RotaModel implements EntidadeBase {
  @override
  final String id;
  final String codigo;
  final String nome;
  final LinhaAtendimento linhaAtendimento;
  @override
  final DateTime updatedAt;
  @override
  final bool deleted;

  const RotaModel({
    required this.id,
    required this.codigo,
    required this.nome,
    required this.linhaAtendimento,
    required this.updatedAt,
    this.deleted = false,
  });

  @override
  Map<String, dynamic> toMap() => {
    'id': id,
    'codigo': codigo,
    'nome': nome,
    'linhaAtendimento': linhaAtendimento.name,
    'updatedAt': updatedAt.toIso8601String(),
    'deleted': deleted,
  };

  factory RotaModel.fromMap(Map<String, dynamic> map) => RotaModel(
    id: map['id'] as String,
    codigo: map['codigo'] as String? ?? '',
    nome: map['nome'] as String? ?? '',
    linhaAtendimento: lerEnum(
      LinhaAtendimento.values,
      map['linhaAtendimento'],
      LinhaAtendimento.toledo,
    ),
    updatedAt: lerData(map['updatedAt']),
    deleted: map['deleted'] as bool? ?? false,
  );
}
