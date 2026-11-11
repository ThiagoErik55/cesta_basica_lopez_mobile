/// Se a venda é bloqueada quando algum item passa do estoque registrado,
/// enquanto a empresa não define outra política (KAN-43).
///
/// Começa desligado de propósito: o vendedor vende na rua com o estoque
/// em cache, que pode estar desatualizado, e parar a venda por isso seria
/// pior que deixar o saldo ficar negativo. O saldo negativo aparece na
/// tela de estoque.
const bool padraoBloquearVendaSemEstoque = false;

/// Política de estoque insuficiente na venda (KAN-43).
///
/// É um valor, não código espalhado: toda a lógica recebe uma
/// [RegraEstoque]. Para trocar a política (por exemplo, lendo de
/// `configuracoes/geral`), basta fornecer outra instância em
/// `regraEstoqueProvider`.
class RegraEstoque {
  const RegraEstoque({
    this.bloquearVendaSemEstoque = padraoBloquearVendaSemEstoque,
  });

  /// `true`: impede finalizar a venda com quantidade acima do estoque.
  /// `false`: só avisa e permite (o estoque fica negativo).
  final bool bloquearVendaSemEstoque;

  RegraEstoque copyWith({bool? bloquearVendaSemEstoque}) => RegraEstoque(
    bloquearVendaSemEstoque:
        bloquearVendaSemEstoque ?? this.bloquearVendaSemEstoque,
  );

  @override
  bool operator ==(Object other) =>
      other is RegraEstoque &&
      other.bloquearVendaSemEstoque == bloquearVendaSemEstoque;

  @override
  int get hashCode => bloquearVendaSemEstoque.hashCode;
}

/// Regra em vigor enquanto a empresa não define outra.
const RegraEstoque regraEstoquePadrao = RegraEstoque();
