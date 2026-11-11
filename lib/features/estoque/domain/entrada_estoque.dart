import '../../../core/domain/enums.dart';
import '../data/movimento_estoque_model.dart';

/// Lê a quantidade digitada. Só aceita número inteiro sem sinal: vazio,
/// decimal ("1,5", "1.5"), negativo e texto devolvem `null`.
int? lerQuantidadeInteira(String texto) {
  final t = texto.trim();
  if (!RegExp(r'^\d+$').hasMatch(t)) return null;
  return int.tryParse(t);
}

/// Resultado da avaliação de uma entrada de estoque (KAN-42): erros por
/// campo e a prévia do que a entrada produz.
class ResultadoEntrada {
  const ResultadoEntrada({
    this.erroQuantidade,
    this.erroCusto,
    this.erroData,
    this.quantidade,
    required this.estoqueAtual,
    required this.custoAtual,
    this.estoqueApos,
    this.novoCusto,
  });

  final String? erroQuantidade;
  final String? erroCusto;
  final String? erroData;

  /// Quantidade lida; `null` se inválida.
  final int? quantidade;
  final int estoqueAtual;
  final double custoAtual;

  /// Estoque depois da entrada; `null` se a quantidade é inválida.
  final int? estoqueApos;

  /// Novo `custoAtual` do produto: o custo da última compra (não é custo
  /// médio); `null` se o custo é inválido.
  final double? novoCusto;

  bool get ok =>
      erroQuantidade == null && erroCusto == null && erroData == null;

  /// O produto está com saldo negativo (venda acima do estoque
  /// registrado). A entrada soma normalmente sobre esse saldo.
  bool get saldoNegativoAntes => estoqueAtual < 0;
}

/// Avalia os dados digitados da entrada. Os campos são validados
/// separadamente para a tela mostrar todos os erros de uma vez.
///
/// - Quantidade: inteira e maior que zero.
/// - Custo unitário: maior que zero ([custo] `null` = não informado).
/// - Data: não pode ser posterior ao dia de [agora].
/// - Estoque após: `estoqueAtual + quantidade`, também sobre saldo
///   negativo.
/// - Novo custo: o custo informado (custo da última compra).
ResultadoEntrada avaliarEntrada({
  required String quantidade,
  required double? custo,
  required DateTime data,
  required DateTime agora,
  required int estoqueAtual,
  required double custoAtual,
}) {
  final qtd = lerQuantidadeInteira(quantidade);
  String? erroQuantidade;
  if (quantidade.trim().isEmpty) {
    erroQuantidade = 'Informe a quantidade.';
  } else if (qtd == null) {
    erroQuantidade = 'A quantidade deve ser um número inteiro.';
  } else if (qtd <= 0) {
    erroQuantidade = 'A quantidade deve ser maior que zero.';
  }

  String? erroCusto;
  if (custo == null) {
    erroCusto = 'Informe o custo unitário.';
  } else if (custo <= 0) {
    erroCusto = 'O custo unitário deve ser maior que zero.';
  }

  final dia = DateTime(data.year, data.month, data.day);
  final hoje = DateTime(agora.year, agora.month, agora.day);
  final erroData = dia.isAfter(hoje)
      ? 'A data da entrada não pode ser futura.'
      : null;

  return ResultadoEntrada(
    erroQuantidade: erroQuantidade,
    erroCusto: erroCusto,
    erroData: erroData,
    quantidade: erroQuantidade == null ? qtd : null,
    estoqueAtual: estoqueAtual,
    custoAtual: custoAtual,
    estoqueApos: erroQuantidade == null ? estoqueAtual + qtd! : null,
    novoCusto: erroCusto == null ? custo : null,
  );
}

/// Data do movimento: o dia escolhido com a hora de [agora], para a
/// entrada entrar na ordem certa do histórico. Nunca fica no futuro,
/// desde que o dia não seja posterior a hoje (ver [avaliarEntrada]).
DateTime dataDaEntrada(DateTime escolhida, DateTime agora) => DateTime(
  escolhida.year,
  escolhida.month,
  escolhida.day,
  agora.hour,
  agora.minute,
  agora.second,
);

/// Monta o movimento de entrada. Observação em branco vira `null`.
MovimentoEstoqueModel montarMovimentoEntrada({
  required String id,
  required String produtoId,
  required int quantidade,
  required double custoUnitario,
  required DateTime data,
  required String vendedorUid,
  String? observacao,
  required DateTime agora,
}) {
  final obs = observacao?.trim();
  return MovimentoEstoqueModel(
    id: id,
    produtoId: produtoId,
    tipo: TipoMovimento.entrada,
    quantidade: quantidade,
    custoUnitario: custoUnitario,
    data: dataDaEntrada(data, agora),
    vendedorUid: vendedorUid,
    observacao: obs == null || obs.isEmpty ? null : obs,
    updatedAt: agora,
  );
}
