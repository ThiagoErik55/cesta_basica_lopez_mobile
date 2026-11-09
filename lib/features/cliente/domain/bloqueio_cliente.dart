import '../../venda/data/parcela_model.dart';
import '../data/cliente_model.dart';
import 'regra_bloqueio.dart';
import 'status_pagamento.dart';

/// Por que o cliente deve ser bloqueado pela regra automática.
enum MotivoBloqueio { atrasoAcimaDoLimite, limiteExcedido, nenhum }

/// Resultado de [avaliarBloqueio].
///
/// Só trata a regra **automática**. O bloqueio manual
/// (`CLIENTE.bloqueado`) é independente e vem em [bloqueioManual]; a
/// regra nunca o altera (ver [bloqueado]).
class ResultadoBloqueio {
  const ResultadoBloqueio({
    required this.deveBloquear,
    required this.motivo,
    required this.diasDeAtraso,
    required this.saldoVencido,
    required this.excedenteLimite,
    required this.limiteCredito,
    required this.valorEmAberto,
    required this.bloqueioManual,
  });

  /// A regra automática manda bloquear.
  final bool deveBloquear;
  final MotivoBloqueio motivo;

  /// Maior atraso, em dias, entre as parcelas pendentes (0 se nenhuma
  /// venceu).
  final int diasDeAtraso;

  /// Saldo das parcelas já vencidas. `null` quando a avaliação foi feita
  /// só pelo resumo do cliente, sem as parcelas.
  final double? saldoVencido;

  /// Quanto `valorEmAberto` mais a nova venda passa do limite; 0 se não
  /// passa ou se o limite não vale.
  final double excedenteLimite;

  final double limiteCredito;
  final double valorEmAberto;

  /// `CLIENTE.bloqueado`, definido à mão pelo vendedor.
  final bool bloqueioManual;

  /// Bloqueado por qualquer origem. O manual prevalece: some só quando o
  /// vendedor desbloqueia, nunca pela regra automática.
  bool get bloqueado => bloqueioManual || deveBloquear;
}

/// Dias de atraso de [vencimento] em [agora], contando dias de calendário
/// depois do vencimento. No dia do vencimento é 0; um dia depois, 1.
/// Parcela a vencer devolve 0.
int diasDeAtraso(DateTime vencimento, DateTime agora) {
  final dias = DateTime.utc(agora.year, agora.month, agora.day)
      .difference(
        DateTime.utc(vencimento.year, vencimento.month, vencimento.day),
      )
      .inDays;
  return dias > 0 ? dias : 0;
}

/// Avalia o bloqueio automático de [cliente] (RF30, KAN-35) com as
/// parcelas pendentes de **todas** as vendas dele.
///
/// - Atraso: se alguma parcela pendente tem [diasDeAtraso] maior ou
///   igual à tolerância da [regra], bloqueia ("atrasoAcimaDoLimite").
///   Pagar as parcelas atrasadas faz o bloqueio sumir sozinho.
/// - Limite: com [RegraBloqueio.bloquearPorLimite] e limite maior que
///   zero, bloqueia se `valorEmAberto + valorNovaVenda` passa do limite
///   ("limiteExcedido"). [valorNovaVenda] é o total da venda parcelada em
///   andamento; 0 avalia só o que o cliente já deve.
/// - Atraso tem prioridade sobre limite quando os dois ocorrem.
ResultadoBloqueio avaliarBloqueio({
  required ClienteModel cliente,
  required Iterable<ParcelaModel> parcelasPendentes,
  required DateTime agora,
  required RegraBloqueio regra,
  double valorNovaVenda = 0,
}) {
  var maiorAtraso = 0;
  var vencido = 0;
  for (final p in parcelasPendentes) {
    if (p.pago || p.deleted) continue;
    final dias = diasDeAtraso(p.vencimento, agora);
    if (dias > maiorAtraso) maiorAtraso = dias;
    if (dias > 0) vencido += (p.saldo * 100).round();
  }

  return _avaliar(
    cliente: cliente,
    diasDeAtraso: maiorAtraso,
    saldoVencido: vencido / 100,
    regra: regra,
    valorNovaVenda: valorNovaVenda,
  );
}

/// Versão barata de [avaliarBloqueio] para listas, que não carregam as
/// parcelas de cada cliente.
///
/// `CLIENTE.proximoVencimento` é o menor vencimento entre as parcelas
/// pendentes (mantido nas vendas e nos pagamentos), então o maior atraso
/// é o atraso desse vencimento. Só não dá o saldo vencido, que fica
/// `null`. A decisão usa a mesma regra de [avaliarBloqueio].
ResultadoBloqueio avaliarBloqueioPeloResumo({
  required ClienteModel cliente,
  required DateTime agora,
  required RegraBloqueio regra,
  double valorNovaVenda = 0,
}) {
  final vencimento = cliente.proximoVencimento;
  final dias = vencimento != null && cliente.temDebito
      ? diasDeAtraso(vencimento, agora)
      : 0;
  return _avaliar(
    cliente: cliente,
    diasDeAtraso: dias,
    saldoVencido: null,
    regra: regra,
    valorNovaVenda: valorNovaVenda,
  );
}

/// A única decisão da regra, usada pelas duas avaliações.
ResultadoBloqueio _avaliar({
  required ClienteModel cliente,
  required int diasDeAtraso,
  required double? saldoVencido,
  required RegraBloqueio regra,
  required double valorNovaVenda,
}) {
  final porAtraso = diasDeAtraso >= regra.diasToleranciaAtraso;

  final limite = cliente.limiteCredito;
  final excedenteCentavos = regra.bloquearPorLimite && limite > 0
      ? ((cliente.valorEmAberto + valorNovaVenda) * 100).round() -
            (limite * 100).round()
      : 0;
  final porLimite = excedenteCentavos > 0;

  return ResultadoBloqueio(
    deveBloquear: porAtraso || porLimite,
    motivo: porAtraso
        ? MotivoBloqueio.atrasoAcimaDoLimite
        : porLimite
        ? MotivoBloqueio.limiteExcedido
        : MotivoBloqueio.nenhum,
    diasDeAtraso: diasDeAtraso,
    saldoVencido: saldoVencido,
    excedenteLimite: porLimite ? excedenteCentavos / 100 : 0,
    limiteCredito: limite,
    valorEmAberto: cliente.valorEmAberto,
    bloqueioManual: cliente.bloqueado,
  );
}

/// Situação do cliente para exibição: o status (com o bloqueio
/// automático já considerado) e o motivo, quando bloqueado.
class SituacaoCliente {
  const SituacaoCliente({
    required this.status,
    this.bloqueioManual = false,
    this.motivo,
    this.bloqueio,
  });

  final StatusPagamento status;

  /// Bloqueado pelo vendedor (manual), e não pela regra.
  final bool bloqueioManual;

  /// Texto curto do motivo ("Atraso de 23 dias", "Limite excedido",
  /// "Bloqueio manual"); `null` quando não está bloqueado.
  final String? motivo;

  /// Avaliação que originou a situação, para detalhes (saldo vencido...).
  final ResultadoBloqueio? bloqueio;

  bool get bloqueado => status == StatusPagamento.bloqueado;
}

/// Situação de [cliente] para as telas (KAN-35).
///
/// É **derivada na leitura**, nunca gravada: `CLIENTE.bloqueado` guarda
/// só o bloqueio manual. Se o status automático fosse gravado ali, a
/// regra não saberia se pode desfazê-lo sem apagar um bloqueio manual, e
/// o desbloqueio automático (parcelas pagas) não aconteceria sozinho.
///
/// Ordem: bloqueio manual, bloqueio automático, depois o status de
/// [statusPagamento] (em atraso ou em dia).
SituacaoCliente situacaoDoCliente(
  ClienteModel cliente,
  ResultadoBloqueio bloqueio, {
  DateTime? agora,
}) {
  if (cliente.bloqueado) {
    return SituacaoCliente(
      status: StatusPagamento.bloqueado,
      bloqueioManual: true,
      motivo: 'Bloqueio manual',
      bloqueio: bloqueio,
    );
  }
  if (bloqueio.deveBloquear) {
    return SituacaoCliente(
      status: StatusPagamento.bloqueado,
      motivo: rotuloMotivoBloqueio(bloqueio),
      bloqueio: bloqueio,
    );
  }
  return SituacaoCliente(
    status: statusPagamento(cliente, agora: agora),
    bloqueio: bloqueio,
  );
}

/// Atalho de [situacaoDoCliente] com a avaliação pelo resumo do cliente.
SituacaoCliente situacaoDoClientePeloResumo(
  ClienteModel cliente, {
  required RegraBloqueio regra,
  DateTime? agora,
}) {
  final momento = agora ?? DateTime.now();
  return situacaoDoCliente(
    cliente,
    avaliarBloqueioPeloResumo(cliente: cliente, agora: momento, regra: regra),
    agora: momento,
  );
}

/// Texto curto do motivo do bloqueio automático.
String rotuloMotivoBloqueio(ResultadoBloqueio r) => switch (r.motivo) {
  MotivoBloqueio.atrasoAcimaDoLimite =>
    'Atraso de ${r.diasDeAtraso} ${r.diasDeAtraso == 1 ? 'dia' : 'dias'}',
  MotivoBloqueio.limiteExcedido => 'Limite excedido',
  MotivoBloqueio.nenhum => '',
};
