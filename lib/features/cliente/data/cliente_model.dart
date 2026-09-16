import '../../../core/domain/entidade_base.dart';
import '../../../core/domain/enums.dart';
import '../../../core/utils/firestore_utils.dart';

class ClienteModel implements EntidadeBase {
  @override
  final String id;
  final String codigo;
  final String nome;
  final String cpf;
  final String telefone;
  final String endereco;
  final String? rotaId;
  final ScoreCliente score;
  final double limiteCredito;
  final bool bloqueado;
  final DateTime? ultimaCompra;
  final DateTime? proximoVencimento;
  final double valorEmAberto;
  @override
  final DateTime updatedAt;
  @override
  final bool deleted;

  const ClienteModel({
    required this.id,
    required this.codigo,
    required this.nome,
    required this.cpf,
    required this.telefone,
    required this.endereco,
    this.rotaId,
    this.score = ScoreCliente.b,
    this.limiteCredito = 0,
    this.bloqueado = false,
    this.ultimaCompra,
    this.proximoVencimento,
    this.valorEmAberto = 0,
    required this.updatedAt,
    this.deleted = false,
  });

  bool get temDebito => valorEmAberto > 0;

  bool get emAtraso =>
      proximoVencimento != null &&
      DateTime.now().isAfter(proximoVencimento!) &&
      temDebito;

  @override
  Map<String, dynamic> toMap() => {
    'id': id,
    'codigo': codigo,
    'nome': nome,
    'nomeBusca': nome.toLowerCase(),
    'cpf': cpf,
    'telefone': telefone,
    'endereco': endereco,
    'rotaId': rotaId,
    'score': score.name,
    'limiteCredito': limiteCredito,
    'bloqueado': bloqueado,
    'ultimaCompra': ultimaCompra?.toIso8601String(),
    'proximoVencimento': proximoVencimento?.toIso8601String(),
    'valorEmAberto': valorEmAberto,
    'updatedAt': updatedAt.toIso8601String(),
    'deleted': deleted,
  };

  factory ClienteModel.fromMap(Map<String, dynamic> map) => ClienteModel(
    id: map['id'] as String,
    codigo: map['codigo'] as String? ?? '',
    nome: map['nome'] as String? ?? '',
    cpf: map['cpf'] as String? ?? '',
    telefone: map['telefone'] as String? ?? '',
    endereco: map['endereco'] as String? ?? '',
    rotaId: map['rotaId'] as String?,
    score: lerEnum(ScoreCliente.values, map['score'], ScoreCliente.b),
    limiteCredito: lerDouble(map['limiteCredito']),
    bloqueado: map['bloqueado'] as bool? ?? false,
    ultimaCompra: lerDataOpcional(map['ultimaCompra']),
    proximoVencimento: lerDataOpcional(map['proximoVencimento']),
    valorEmAberto: lerDouble(map['valorEmAberto']),
    updatedAt: lerData(map['updatedAt']),
    deleted: map['deleted'] as bool? ?? false,
  );

  ClienteModel copyWith({
    String? nome,
    String? telefone,
    String? endereco,
    String? rotaId,
    ScoreCliente? score,
    double? limiteCredito,
    bool? bloqueado,
    DateTime? ultimaCompra,
    DateTime? proximoVencimento,
    double? valorEmAberto,
    bool? deleted,
  }) => ClienteModel(
    id: id,
    codigo: codigo,
    nome: nome ?? this.nome,
    cpf: cpf,
    telefone: telefone ?? this.telefone,
    endereco: endereco ?? this.endereco,
    rotaId: rotaId ?? this.rotaId,
    score: score ?? this.score,
    limiteCredito: limiteCredito ?? this.limiteCredito,
    bloqueado: bloqueado ?? this.bloqueado,
    ultimaCompra: ultimaCompra ?? this.ultimaCompra,
    proximoVencimento: proximoVencimento ?? this.proximoVencimento,
    valorEmAberto: valorEmAberto ?? this.valorEmAberto,
    updatedAt: DateTime.now(),
    deleted: deleted ?? this.deleted,
  );
}
