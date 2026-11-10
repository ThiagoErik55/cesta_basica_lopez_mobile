import '../../../core/domain/enums.dart';
import '../../../core/utils/id_generator.dart';
import '../data/parcela_model.dart';

/// Resultado de [registrarPagamentoParcela]: ou [erro] preenchido, ou o
/// pagamento gerado e a parcela como ficará.
class ResultadoPagamento {
  const ResultadoPagamento.erro(String this.erro)
    : pagamento = null,
      parcelaAtualizada = null,
      saldoRestante = 0,
      vendaQuitada = false;

  const ResultadoPagamento.ok({
    required PagamentoModel this.pagamento,
    required ParcelaModel this.parcelaAtualizada,
    required this.saldoRestante,
    required this.vendaQuitada,
  }) : erro = null;

  final String? erro;
  final PagamentoModel? pagamento;

  /// Parcela com o pagamento acrescentado; `pago` só se foi quitada.
  final ParcelaModel? parcelaAtualizada;

  /// Quanto ainda falta pagar na parcela depois deste pagamento.
  final double saldoRestante;

  /// Todas as parcelas da venda ficaram pagas.
  final bool vendaQuitada;

  bool get ok => erro == null;

  /// O pagamento quitou a parcela.
  bool get parcelaQuitada => ok && parcelaAtualizada!.pago;
}

int _centavos(double valor) => (valor * 100).round();

/// Valida e monta o pagamento de [valor] na parcela [parcelaId].
///
/// - Parcela já paga é recusada.
/// - [valor] precisa ser maior que zero e não passar do saldo da parcela
///   (valor atual menos o que já foi pago). Usa o valor atual, então uma
///   parcela alterada na KAN-32 é cobrada pelo valor novo.
/// - [data] não pode ser futura (compara só o dia).
/// - Pagamento igual ao saldo quita a parcela; menor, deixa a parcela
///   pendente com o saldo restante.
///
/// Tudo em centavos, para não sobrar nem faltar dinheiro.
ResultadoPagamento registrarPagamentoParcela({
  required List<ParcelaModel> parcelasDaVenda,
  required String parcelaId,
  required double valor,
  required FormaPagamento forma,
  required DateTime data,
  String? observacao,
  DateTime? agora,
  String? idPagamento,
}) {
  final momento = agora ?? DateTime.now();
  final parcela = parcelasDaVenda
      .where((p) => p.id == parcelaId && !p.deleted)
      .firstOrNull;
  if (parcela == null) {
    return const ResultadoPagamento.erro('Parcela não encontrada.');
  }
  if (parcela.pago) {
    return const ResultadoPagamento.erro('Esta parcela já está paga.');
  }

  final centavos = _centavos(valor);
  if (centavos <= 0) {
    return const ResultadoPagamento.erro(
      'O valor pago deve ser maior que zero.',
    );
  }
  final saldo = _centavos(parcela.valor) - _centavos(parcela.totalPago);
  if (centavos > saldo) {
    return ResultadoPagamento.erro(
      'O valor pago passa do saldo da parcela '
      '(${(saldo / 100).toStringAsFixed(2).replaceAll('.', ',')}).',
    );
  }

  final hoje = DateTime(momento.year, momento.month, momento.day);
  final dia = DateTime(data.year, data.month, data.day);
  if (dia.isAfter(hoje)) {
    return const ResultadoPagamento.erro(
      'A data do pagamento não pode ser futura.',
    );
  }

  final texto = observacao?.trim();
  final pagamento = PagamentoModel(
    id: idPagamento ?? gerarId(),
    valor: centavos / 100,
    // Pagamento de hoje guarda a hora real; de dia anterior, o dia
    // escolhido à meia-noite.
    data: dia == hoje ? momento : dia,
    forma: forma,
    observacao: texto == null || texto.isEmpty ? null : texto,
  );

  final quitou = centavos == saldo;
  final atualizada = parcela.copyWith(
    pagamentos: [...parcela.pagamentos, pagamento],
    pago: quitou ? true : null,
    dataPagamento: quitou ? pagamento.data : null,
  );

  final vendaQuitada = parcelasDaVenda
      .where((p) => !p.deleted)
      .every((p) => p.id == parcelaId ? quitou : p.pago);

  return ResultadoPagamento.ok(
    pagamento: pagamento,
    parcelaAtualizada: atualizada,
    saldoRestante: (saldo - centavos) / 100,
    vendaQuitada: vendaQuitada,
  );
}

/// Menor vencimento entre as parcelas ainda pendentes, ou `null` se não
/// há nenhuma. Base do `CLIENTE.proximoVencimento` (ADR 002, decisão 6).
DateTime? proximoVencimentoPendente(Iterable<ParcelaModel> parcelas) {
  DateTime? menor;
  for (final p in parcelas) {
    if (p.pago || p.deleted) continue;
    if (menor == null || p.vencimento.isBefore(menor)) menor = p.vencimento;
  }
  return menor;
}
