import '../data/parcela_model.dart';

/// Campos desnormalizados do cliente que uma venda altera (ADR 002,
/// decisão 6).
///
/// Não é um ClienteModel inteiro de propósito: gravar o cliente todo a
/// partir de uma cópia local sobrescreveria alterações feitas por outro
/// vendedor enquanto estava offline. Só estes campos são escritos.
class AtualizacaoClienteVenda {
  const AtualizacaoClienteVenda({
    required this.clienteId,
    this.ultimaCompra,
    this.acrescimoEmAberto = 0,
    this.proximoVencimento,
    this.limparProximoVencimento = false,
  });

  final String clienteId;

  /// `null` quando a operação não é uma compra (ex. alteração de parcela).
  final DateTime? ultimaCompra;

  /// Variação do valor em aberto: soma das parcelas geradas por uma
  /// venda parcelada (0 em venda à vista) ou diferença de uma parcela
  /// alterada (pode ser negativa).
  final double acrescimoEmAberto;

  /// Menor vencimento pendente do cliente depois da operação; `null` não
  /// toca no campo (ex. venda à vista).
  final DateTime? proximoVencimento;

  /// Grava `null` em `proximoVencimento`: o cliente ficou sem parcelas
  /// pendentes. Só vale quando [proximoVencimento] é `null`.
  final bool limparProximoVencimento;
}

/// Monta a atualização do cliente para uma venda feita em [agora].
///
/// - `ultimaCompra`: sempre.
/// - `valorEmAberto`: acrescido da soma das [parcelas] (todas nascem
///   pendentes).
/// - `proximoVencimento`: o menor entre o vencimento já registrado (se o
///   cliente ainda deve algo) e o da primeira parcela nova.
AtualizacaoClienteVenda atualizacaoClienteDaVenda({
  required String clienteId,
  required DateTime agora,
  required List<ParcelaModel> parcelas,
  required double valorEmAbertoAtual,
  required DateTime? proximoVencimentoAtual,
}) {
  if (parcelas.isEmpty) {
    return AtualizacaoClienteVenda(clienteId: clienteId, ultimaCompra: agora);
  }

  final centavos = parcelas.fold<int>(
    0,
    (soma, p) => soma + (p.valor * 100).round(),
  );
  final menorNova = parcelas
      .map((p) => p.vencimento)
      .reduce((a, b) => a.isBefore(b) ? a : b);
  final atual = valorEmAbertoAtual > 0 ? proximoVencimentoAtual : null;

  return AtualizacaoClienteVenda(
    clienteId: clienteId,
    ultimaCompra: agora,
    acrescimoEmAberto: centavos / 100,
    proximoVencimento: atual != null && atual.isBefore(menorNova)
        ? atual
        : menorNova,
  );
}
