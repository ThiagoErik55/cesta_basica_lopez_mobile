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
    required this.ultimaCompra,
    this.acrescimoEmAberto = 0,
    this.proximoVencimento,
  });

  final String clienteId;
  final DateTime ultimaCompra;

  /// Soma das parcelas pendentes geradas pela venda; 0 em venda à vista.
  final double acrescimoEmAberto;

  /// Menor vencimento pendente do cliente depois da venda; `null` em
  /// venda à vista (o campo não é tocado).
  final DateTime? proximoVencimento;
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
