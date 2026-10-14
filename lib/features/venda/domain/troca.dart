import '../../../core/utils/formatadores.dart';
import '../../produto/data/produto_model.dart';
import '../data/venda_model.dart';

/// Quantas unidades de [item] ainda podem ser trocadas em [venda]
/// (KAN-28): a quantidade vendida menos o que já foi trocado dele.
int quantidadeTrocavel(VendaModel venda, ItemVenda item) {
  final trocadas = venda.trocas
      .where((t) => t.itemOriginalId == item.id)
      .fold<int>(0, (soma, t) => soma + t.quantidade);
  final resto = item.quantidade - trocadas;
  return resto < 0 ? 0 : resto;
}

/// Diferença de valor da troca: positiva quando o produto novo é mais
/// caro (cliente paga a diferença), negativa quando é mais barato
/// (devolve ao cliente). Usa o preço praticado na venda para o item
/// original e o preço atual para o novo.
double diferencaTroca({
  required ItemVenda original,
  required ProdutoModel novo,
  required int quantidade,
}) {
  final centavos =
      ((novo.preco - original.precoUnitario) * quantidade * 100).round();
  return centavos / 100;
}

/// Linha de observação registrada automaticamente na troca (RF26), ex.
/// "14/10/2026: troca de 2x Arroz 5kg por 2x Feijão 1kg (cliente pagou
/// R$ 3,00)".
String descricaoTroca({
  required DateTime data,
  required ItemVenda original,
  required ProdutoModel novo,
  required int quantidade,
  required double diferenca,
}) {
  final valor = switch (diferenca) {
    > 0 => ' (cliente pagou ${formatarMoeda(diferenca)})',
    < 0 => ' (devolvido ao cliente ${formatarMoeda(-diferenca)})',
    _ => '',
  };
  return '${formatarData(data)}: troca de ${quantidade}x ${original.nome} '
      'por ${quantidade}x ${novo.nome}$valor';
}

/// Acrescenta [linha] ao fim da observação existente.
String acrescentarObservacao(String? atual, String linha) {
  final texto = atual?.trim() ?? '';
  return texto.isEmpty ? linha : '$texto\n$linha';
}
