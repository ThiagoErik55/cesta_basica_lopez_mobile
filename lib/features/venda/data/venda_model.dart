import '../../../core/domain/entidade_base.dart';
import '../../../core/domain/enums.dart';
import '../../../core/utils/firestore_utils.dart';

class ItemVenda {
  final String id;
  final String produtoId;
  final String nome;
  final int quantidade;
  final double precoUnitario;
  final double custoUnitario;

  const ItemVenda({
    required this.id,
    required this.produtoId,
    required this.nome,
    required this.quantidade,
    required this.precoUnitario,
    required this.custoUnitario,
  });

  double get subtotal => quantidade * precoUnitario;

  double get margem => quantidade * (precoUnitario - custoUnitario);

  Map<String, dynamic> toMap() => {
    'id': id,
    'produtoId': produtoId,
    'nome': nome,
    'quantidade': quantidade,
    'precoUnitario': precoUnitario,
    'custoUnitario': custoUnitario,
  };

  factory ItemVenda.fromMap(Map<String, dynamic> map) => ItemVenda(
    id: map['id'] as String,
    produtoId: map['produtoId'] as String,
    nome: map['nome'] as String? ?? '',
    quantidade: lerInt(map['quantidade']),
    precoUnitario: lerDouble(map['precoUnitario']),
    custoUnitario: lerDouble(map['custoUnitario']),
  );
}

class TrocaItem {
  final String id;
  final String itemOriginalId;
  final String produtoNovoId;
  final String produtoNovoNome;
  final int quantidade;
  final double diferencaValor;
  final DateTime data;

  const TrocaItem({
    required this.id,
    required this.itemOriginalId,
    required this.produtoNovoId,
    required this.produtoNovoNome,
    required this.quantidade,
    this.diferencaValor = 0,
    required this.data,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'itemOriginalId': itemOriginalId,
    'produtoNovoId': produtoNovoId,
    'produtoNovoNome': produtoNovoNome,
    'quantidade': quantidade,
    'diferencaValor': diferencaValor,
    'data': data.toIso8601String(),
  };

  factory TrocaItem.fromMap(Map<String, dynamic> map) => TrocaItem(
    id: map['id'] as String,
    itemOriginalId: map['itemOriginalId'] as String,
    produtoNovoId: map['produtoNovoId'] as String,
    produtoNovoNome: map['produtoNovoNome'] as String? ?? '',
    quantidade: lerInt(map['quantidade']),
    diferencaValor: lerDouble(map['diferencaValor']),
    data: lerData(map['data']),
  );
}

class VendaModel implements EntidadeBase {
  @override
  final String id;
  final String clienteId;
  final String clienteNome;
  final String vendedorUid;
  final int numeroNota;
  final DateTime data;
  final List<ItemVenda> itens;
  final List<TrocaItem> trocas;
  final double valorTotal;
  final FormaPagamento? formaPagamento;
  final TipoVenda tipo;
  final String? assinaturaBase64;
  final String? observacao;
  @override
  final DateTime updatedAt;
  @override
  final bool deleted;

  const VendaModel({
    required this.id,
    required this.clienteId,
    required this.clienteNome,
    required this.vendedorUid,
    required this.numeroNota,
    required this.data,
    required this.itens,
    this.trocas = const [],
    required this.valorTotal,
    this.formaPagamento,
    required this.tipo,
    this.assinaturaBase64,
    this.observacao,
    required this.updatedAt,
    this.deleted = false,
  });

  bool get ehPromissoria => tipo == TipoVenda.parcelado;

  double get margemBruta =>
      itens.fold<double>(0, (soma, i) => soma + i.margem) +
      trocas.fold<double>(0, (soma, t) => soma + t.diferencaValor);

  @override
  Map<String, dynamic> toMap() => {
    'id': id,
    'clienteId': clienteId,
    'clienteNome': clienteNome,
    'vendedorUid': vendedorUid,
    'numeroNota': numeroNota,
    'data': data.toIso8601String(),
    'itens': itens.map((e) => e.toMap()).toList(),
    'trocas': trocas.map((e) => e.toMap()).toList(),
    'valorTotal': valorTotal,
    'formaPagamento': formaPagamento?.name,
    'tipo': tipo.name,
    'assinaturaBase64': assinaturaBase64,
    'observacao': observacao,
    'updatedAt': updatedAt.toIso8601String(),
    'deleted': deleted,
  };

  factory VendaModel.fromMap(Map<String, dynamic> map) => VendaModel(
    id: map['id'] as String,
    clienteId: map['clienteId'] as String? ?? '',
    clienteNome: map['clienteNome'] as String? ?? '',
    vendedorUid: map['vendedorUid'] as String? ?? '',
    numeroNota: lerInt(map['numeroNota']),
    data: lerData(map['data']),
    itens: (map['itens'] as List<dynamic>? ?? [])
        .map((e) => ItemVenda.fromMap(e as Map<String, dynamic>))
        .toList(),
    trocas: (map['trocas'] as List<dynamic>? ?? [])
        .map((e) => TrocaItem.fromMap(e as Map<String, dynamic>))
        .toList(),
    valorTotal: lerDouble(map['valorTotal']),
    formaPagamento: map['formaPagamento'] == null
        ? null
        : lerEnum(
            FormaPagamento.values,
            map['formaPagamento'],
            FormaPagamento.dinheiro,
          ),
    tipo: lerEnum(TipoVenda.values, map['tipo'], TipoVenda.aVista),
    assinaturaBase64: map['assinaturaBase64'] as String?,
    observacao: map['observacao'] as String?,
    updatedAt: lerData(map['updatedAt']),
    deleted: map['deleted'] as bool? ?? false,
  );
}
