import '../../../core/domain/enums.dart';
import '../../../core/utils/texto.dart';
import '../data/parcela_model.dart';
import '../data/venda_model.dart';
import 'promissoria.dart';
import 'registro_pagamento.dart';

int _centavos(double valor) => (valor * 100).round();

/// Uma promissória na lista de controle (KAN-34): a visão derivada de
/// uma venda parcelada e suas parcelas, com os números já calculados.
class ItemPromissoria {
  const ItemPromissoria._({
    required this.promissoria,
    required this.situacao,
    required this.valorPago,
    required this.saldo,
    required this.saldoEmAtraso,
    required this.parcelasPagas,
    required this.totalParcelas,
    required this.proximoVencimento,
  });

  /// Monta o item de [venda] a partir das suas [parcelas].
  ///
  /// Reaproveita [Promissoria] (saldo e situação) e
  /// [proximoVencimentoPendente]. Venda sem parcelas carregadas conta
  /// como em dia, e não como quitada.
  factory ItemPromissoria.de(VendaModel venda, List<ParcelaModel> parcelas) {
    final ativas = parcelas.where((p) => !p.deleted).toList();
    final promissoria = Promissoria(venda: venda, parcelas: ativas);

    var pago = 0;
    var emAtraso = 0;
    for (final p in ativas) {
      pago += _centavos(p.pago ? p.valor : p.totalPago);
      if (p.atrasada) emAtraso += _centavos(p.saldo);
    }

    return ItemPromissoria._(
      promissoria: promissoria,
      situacao: ativas.isEmpty ? StatusPromissoria.aberta : promissoria.status,
      valorPago: pago / 100,
      saldo: _centavos(promissoria.saldo) / 100,
      saldoEmAtraso: emAtraso / 100,
      parcelasPagas: ativas.where((p) => p.pago).length,
      totalParcelas: ativas.length,
      proximoVencimento: proximoVencimentoPendente(ativas),
    );
  }

  final Promissoria promissoria;
  final StatusPromissoria situacao;

  /// Soma dos pagamentos recebidos (parcela quitada conta o valor todo).
  final double valorPago;

  /// Quanto ainda falta receber.
  final double saldo;

  /// Parte do [saldo] que está em parcelas já vencidas.
  final double saldoEmAtraso;

  final int parcelasPagas;
  final int totalParcelas;

  /// Menor vencimento entre as parcelas pendentes; `null` se quitada.
  final DateTime? proximoVencimento;

  VendaModel get venda => promissoria.venda;
  int get numeroNota => venda.numeroNota;
  String get clienteNome => venda.clienteNome;
  String get vendaId => venda.id;
  double get valorTotal => venda.valorTotal;
  DateTime get data => venda.data;

  bool get emAtraso => situacao == StatusPromissoria.atrasada;
}

/// Itens de controle das vendas parceladas em [vendas]. Vendas à vista e
/// removidas ficam de fora. [parcelasPorVenda] é indexado pelo id da venda.
List<ItemPromissoria> montarItensPromissoria({
  required List<VendaModel> vendas,
  required Map<String, List<ParcelaModel>> parcelasPorVenda,
}) => [
  for (final v in vendas)
    if (v.ehPromissoria && !v.deleted)
      ItemPromissoria.de(v, parcelasPorVenda[v.id] ?? const []),
];

/// Totais do topo da tela.
class ResumoPromissorias {
  const ResumoPromissorias({
    required this.totalEmAberto,
    required this.totalEmAtraso,
    required this.quantidadeEmAtraso,
  });

  final double totalEmAberto;
  final double totalEmAtraso;
  final int quantidadeEmAtraso;
}

/// Soma o saldo em aberto, o saldo já vencido e a quantidade de
/// promissórias em atraso.
ResumoPromissorias resumirPromissorias(Iterable<ItemPromissoria> itens) {
  var aberto = 0;
  var atraso = 0;
  var quantidade = 0;
  for (final i in itens) {
    aberto += _centavos(i.saldo);
    atraso += _centavos(i.saldoEmAtraso);
    if (i.emAtraso) quantidade++;
  }
  return ResumoPromissorias(
    totalEmAberto: aberto / 100,
    totalEmAtraso: atraso / 100,
    quantidadeEmAtraso: quantidade,
  );
}

/// Ordem padrão: em atraso primeiro, depois em dia, depois quitadas. Em
/// atraso e em dia seguem o próximo vencimento mais próximo; quitadas, a
/// venda mais recente. Empates saem pela nota mais nova.
List<ItemPromissoria> ordenarPromissorias(Iterable<ItemPromissoria> itens) {
  int grupo(ItemPromissoria i) => switch (i.situacao) {
    StatusPromissoria.atrasada => 0,
    StatusPromissoria.aberta => 1,
    StatusPromissoria.paga => 2,
  };

  return itens.toList()..sort((a, b) {
    final porGrupo = grupo(a).compareTo(grupo(b));
    if (porGrupo != 0) return porGrupo;

    final va = a.proximoVencimento;
    final vb = b.proximoVencimento;
    final porData = switch ((va, vb)) {
      (final x?, final y?) => x.compareTo(y),
      (_, _) => b.data.compareTo(a.data),
    };
    if (porData != 0) return porData;
    return b.numeroNota.compareTo(a.numeroNota);
  });
}

/// Filtra por [situacao] (`null` = todas) e por [termo], que casa com o
/// número da nota ou com o nome do cliente, sem diferenciar maiúsculas
/// nem acentos.
List<ItemPromissoria> filtrarPromissorias(
  Iterable<ItemPromissoria> itens, {
  StatusPromissoria? situacao,
  String termo = '',
}) {
  final busca = normalizarBusca(termo.trim());
  return [
    for (final i in itens)
      if ((situacao == null || i.situacao == situacao) &&
          (busca.isEmpty ||
              i.numeroNota.toString().contains(busca) ||
              normalizarBusca(i.clienteNome).contains(busca)))
        i,
  ];
}
