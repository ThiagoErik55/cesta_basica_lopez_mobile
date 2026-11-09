/// Dias de atraso, a partir dos quais o cliente é bloqueado, quando a
/// empresa ainda não definiu outro valor (RF30, pendência 7.3 do modelo
/// lógico).
const int padraoDiasToleranciaAtraso = 15;

/// Se a venda parcelada que estoura o limite de crédito é bloqueada,
/// quando a empresa ainda não definiu outra regra.
const bool padraoBloquearPorLimite = true;

/// Regra de bloqueio automático de cliente (RF30, KAN-35).
///
/// A empresa ainda não fechou a regra final, então ela é um valor, não
/// código espalhado: toda a lógica recebe uma [RegraBloqueio], e os
/// padrões acima são os únicos números fixos. Para trocar a regra (por
/// exemplo, lendo de `configuracoes/geral`), basta fornecer outra
/// instância em `regraBloqueioProvider`.
class RegraBloqueio {
  const RegraBloqueio({
    this.diasToleranciaAtraso = padraoDiasToleranciaAtraso,
    this.bloquearPorLimite = padraoBloquearPorLimite,
  }) : assert(diasToleranciaAtraso > 0, 'tolerância deve ser positiva');

  /// Dias de atraso de qualquer parcela pendente, contados depois do
  /// vencimento, a partir dos quais o cliente é bloqueado. Com 15, uma
  /// parcela com 14 dias de atraso ainda passa; com 15, bloqueia.
  final int diasToleranciaAtraso;

  /// Bloqueia a venda parcelada quando `valorEmAberto` mais o total da
  /// venda passa de `limiteCredito`. Limite zero significa "não definido"
  /// e nunca bloqueia.
  final bool bloquearPorLimite;

  RegraBloqueio copyWith({
    int? diasToleranciaAtraso,
    bool? bloquearPorLimite,
  }) => RegraBloqueio(
    diasToleranciaAtraso: diasToleranciaAtraso ?? this.diasToleranciaAtraso,
    bloquearPorLimite: bloquearPorLimite ?? this.bloquearPorLimite,
  );

  @override
  bool operator ==(Object other) =>
      other is RegraBloqueio &&
      other.diasToleranciaAtraso == diasToleranciaAtraso &&
      other.bloquearPorLimite == bloquearPorLimite;

  @override
  int get hashCode => Object.hash(diasToleranciaAtraso, bloquearPorLimite);
}

/// Regra em vigor enquanto a empresa não define outra.
const RegraBloqueio regraBloqueioPadrao = RegraBloqueio();
