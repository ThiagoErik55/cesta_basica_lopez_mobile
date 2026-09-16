enum LinhaAtendimento { toledo, regional }

enum ScoreCliente { a, b, c, d }

enum FormaPagamento { pix, credito, debito, valeAlimentacao, dinheiro }

enum TipoVenda { aVista, parcelado }

enum TipoMovimento { entrada, saida, troca }

enum StatusPromissoria { aberta, paga, atrasada }

T lerEnum<T>(List<T> valores, dynamic bruto, T padrao) {
  for (final v in valores) {
    if ((v as Enum).name == bruto) return v;
  }
  return padrao;
}
