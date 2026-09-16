import '../../../core/domain/entidade_base.dart';
import '../../../core/domain/enums.dart';
import '../../../core/utils/firestore_utils.dart';

class PagamentoModel {
  final String id;
  final double valor;
  final DateTime data;
  final FormaPagamento forma;

  const PagamentoModel({
    required this.id,
    required this.valor,
    required this.data,
    required this.forma,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'valor': valor,
    'data': data.toIso8601String(),
    'forma': forma.name,
  };

  factory PagamentoModel.fromMap(Map<String, dynamic> map) => PagamentoModel(
    id: map['id'] as String,
    valor: lerDouble(map['valor']),
    data: lerData(map['data']),
    forma: lerEnum(
      FormaPagamento.values,
      map['forma'],
      FormaPagamento.dinheiro,
    ),
  );
}

class ParcelaModel implements EntidadeBase {
  @override
  final String id;
  final String vendaId;
  final int numero;
  final double valor;
  final DateTime vencimento;
  final bool pago;
  final DateTime? dataPagamento;
  final List<PagamentoModel> pagamentos;
  @override
  final DateTime updatedAt;
  @override
  final bool deleted;

  const ParcelaModel({
    required this.id,
    required this.vendaId,
    required this.numero,
    required this.valor,
    required this.vencimento,
    this.pago = false,
    this.dataPagamento,
    this.pagamentos = const [],
    required this.updatedAt,
    this.deleted = false,
  });

  double get totalPago =>
      pagamentos.fold<double>(0, (soma, p) => soma + p.valor);

  double get saldo => valor - totalPago;

  bool get atrasada => !pago && DateTime.now().isAfter(vencimento);

  @override
  Map<String, dynamic> toMap() => {
    'id': id,
    'vendaId': vendaId,
    'numero': numero,
    'valor': valor,
    'vencimento': vencimento.toIso8601String(),
    'pago': pago,
    'dataPagamento': dataPagamento?.toIso8601String(),
    'pagamentos': pagamentos.map((e) => e.toMap()).toList(),
    'updatedAt': updatedAt.toIso8601String(),
    'deleted': deleted,
  };

  factory ParcelaModel.fromMap(Map<String, dynamic> map) => ParcelaModel(
    id: map['id'] as String,
    vendaId: map['vendaId'] as String? ?? '',
    numero: lerInt(map['numero']),
    valor: lerDouble(map['valor']),
    vencimento: lerData(map['vencimento']),
    pago: map['pago'] as bool? ?? false,
    dataPagamento: lerDataOpcional(map['dataPagamento']),
    pagamentos: (map['pagamentos'] as List<dynamic>? ?? [])
        .map((e) => PagamentoModel.fromMap(e as Map<String, dynamic>))
        .toList(),
    updatedAt: lerData(map['updatedAt']),
    deleted: map['deleted'] as bool? ?? false,
  );

  ParcelaModel copyWith({
    double? valor,
    bool? pago,
    DateTime? dataPagamento,
    List<PagamentoModel>? pagamentos,
  }) => ParcelaModel(
    id: id,
    vendaId: vendaId,
    numero: numero,
    valor: valor ?? this.valor,
    vencimento: vencimento,
    pago: pago ?? this.pago,
    dataPagamento: dataPagamento ?? this.dataPagamento,
    pagamentos: pagamentos ?? this.pagamentos,
    updatedAt: DateTime.now(),
    deleted: deleted,
  );
}
