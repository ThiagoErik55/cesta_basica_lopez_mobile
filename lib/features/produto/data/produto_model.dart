import '../../../core/domain/entidade_base.dart';
import '../../../core/utils/firestore_utils.dart';

class ProdutoModel implements EntidadeBase {
  @override
  final String id;
  final String codigo;
  final String nome;
  final String marca;
  final String categoria;
  final double preco;
  final double custoAtual;
  final int estoqueAtual;
  final int estoqueMinimo;
  @override
  final DateTime updatedAt;
  @override
  final bool deleted;

  const ProdutoModel({
    required this.id,
    required this.codigo,
    required this.nome,
    required this.marca,
    required this.categoria,
    required this.preco,
    this.custoAtual = 0,
    this.estoqueAtual = 0,
    this.estoqueMinimo = 10,
    required this.updatedAt,
    this.deleted = false,
  });

  bool get estoqueBaixo => estoqueAtual <= estoqueMinimo;

  double get margemUnitaria => preco - custoAtual;

  @override
  Map<String, dynamic> toMap() => {
    'id': id,
    'codigo': codigo,
    'nome': nome,
    'nomeBusca': nome.toLowerCase(),
    'marca': marca,
    'categoria': categoria,
    'preco': preco,
    'custoAtual': custoAtual,
    'estoqueAtual': estoqueAtual,
    'estoqueMinimo': estoqueMinimo,
    'updatedAt': updatedAt.toIso8601String(),
    'deleted': deleted,
  };

  factory ProdutoModel.fromMap(Map<String, dynamic> map) => ProdutoModel(
    id: map['id'] as String,
    codigo: map['codigo'] as String? ?? '',
    nome: map['nome'] as String? ?? '',
    marca: map['marca'] as String? ?? '',
    categoria: map['categoria'] as String? ?? '',
    preco: lerDouble(map['preco']),
    custoAtual: lerDouble(map['custoAtual']),
    estoqueAtual: lerInt(map['estoqueAtual']),
    estoqueMinimo: lerInt(map['estoqueMinimo']),
    updatedAt: lerData(map['updatedAt']),
    deleted: map['deleted'] as bool? ?? false,
  );

  ProdutoModel copyWith({
    double? preco,
    double? custoAtual,
    int? estoqueAtual,
    int? estoqueMinimo,
    bool? deleted,
  }) => ProdutoModel(
    id: id,
    codigo: codigo,
    nome: nome,
    marca: marca,
    categoria: categoria,
    preco: preco ?? this.preco,
    custoAtual: custoAtual ?? this.custoAtual,
    estoqueAtual: estoqueAtual ?? this.estoqueAtual,
    estoqueMinimo: estoqueMinimo ?? this.estoqueMinimo,
    updatedAt: DateTime.now(),
    deleted: deleted ?? this.deleted,
  );
}
