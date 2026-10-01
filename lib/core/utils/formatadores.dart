import 'package:intl/intl.dart';

/// Formatação de valores para exibição (pt-BR).
final _moeda = NumberFormat.currency(locale: 'pt_BR', symbol: r'R$');
final _data = DateFormat('dd/MM/yyyy');

String formatarMoeda(double valor) => _moeda.format(valor);

/// [vazio] é exibido quando não há data (ex. cliente que nunca comprou).
String formatarData(DateTime? data, {String vazio = '—'}) =>
    data == null ? vazio : _data.format(data);

/// Valor para um campo de texto editável: "150,00", sem símbolo.
String formatarValorEditavel(double valor) =>
    valor.toStringAsFixed(2).replaceAll('.', ',');

/// Lê um valor digitado com vírgula ou ponto como separador decimal
/// ("150", "150,5", "150.50"). Sem separador de milhar. `null` se o
/// texto não for um número.
double? lerValorMonetario(String texto) =>
    double.tryParse(texto.trim().replaceAll(',', '.'));
