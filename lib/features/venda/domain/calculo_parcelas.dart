import '../../../core/utils/id_generator.dart';
import '../data/parcela_model.dart';

/// Divide [total] em [quantidade] parcelas mensais (RF14), a primeira
/// vencendo em [primeiroVencimento].
///
/// O cálculo é feito em centavos para não sobrar nem faltar dinheiro por
/// arredondamento: os centavos que não dividem certo vão para a última
/// parcela. Ex.: 100,00 em 3 = 33,33 + 33,33 + 33,34.
List<ParcelaModel> gerarParcelas({
  required String vendaId,
  required double total,
  required int quantidade,
  required DateTime primeiroVencimento,
  DateTime? agora,
}) {
  assert(quantidade > 0, 'quantidade de parcelas deve ser maior que zero');
  final momento = agora ?? DateTime.now();
  final totalCentavos = (total * 100).round();
  final base = totalCentavos ~/ quantidade;
  final resto = totalCentavos - base * quantidade;

  return List.generate(quantidade, (i) {
    final centavos = i == quantidade - 1 ? base + resto : base;
    return ParcelaModel(
      id: gerarId(),
      vendaId: vendaId,
      numero: i + 1,
      valor: centavos / 100,
      vencimento: somarMeses(primeiroVencimento, i),
      updatedAt: momento,
    );
  });
}

/// Soma [meses] a [data] mantendo o dia. Se o dia não existir no mês de
/// destino (ex. 31 em fevereiro), usa o último dia desse mês.
DateTime somarMeses(DateTime data, int meses) {
  final mesBruto = data.month - 1 + meses;
  final ano = data.year + mesBruto ~/ 12;
  final mes = mesBruto % 12 + 1;
  final ultimoDia = DateTime(ano, mes + 1, 0).day;
  final dia = data.day > ultimoDia ? ultimoDia : data.day;
  return DateTime(ano, mes, dia);
}

/// Mínimo de parcelas para uma venda parcelada; com uma só parcela a
/// venda seria à vista.
const minimoParcelas = 2;

/// Valida o parcelamento escolhido. Devolve a mensagem do problema ou
/// `null` se está tudo certo. [hoje] só existe para os testes.
String? validarParcelamento({
  required int quantidade,
  required DateTime primeiroVencimento,
  DateTime? hoje,
}) {
  if (quantidade < minimoParcelas) {
    return 'Parcelado exige pelo menos $minimoParcelas parcelas.';
  }
  final agora = hoje ?? DateTime.now();
  final dia = DateTime(agora.year, agora.month, agora.day);
  final vencimento = DateTime(
    primeiroVencimento.year,
    primeiroVencimento.month,
    primeiroVencimento.day,
  );
  if (vencimento.isBefore(dia)) {
    return 'A data da 1ª parcela não pode ser anterior a hoje.';
  }
  return null;
}
