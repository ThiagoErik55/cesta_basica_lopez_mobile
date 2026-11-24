import 'package:intl/intl.dart';

/// Formatação de valores para exibição (pt-BR).
final _moeda = NumberFormat.currency(locale: 'pt_BR', symbol: r'R$');
final _data = DateFormat('dd/MM/yyyy');
final _dataHora = DateFormat('dd/MM/yyyy HH:mm');

String formatarMoeda(double valor) => _moeda.format(valor);

/// Dinheiro em centavos inteiros, sem passar por ponto flutuante:
/// `123456` vira "R$ 1.234,56" e `-500` vira "−R$ 5,00".
String formatarCentavos(int centavos) {
  final abs = centavos.abs();
  final inteiro = '${abs ~/ 100}'.replaceAllMapped(
    RegExp(r'\B(?=(\d{3})+(?!\d))'),
    (_) => '.',
  );
  final cent = '${abs % 100}'.padLeft(2, '0');
  return '${centavos < 0 ? '−' : ''}R\$ $inteiro,$cent';
}

/// [vazio] é exibido quando não há data (ex. cliente que nunca comprou).
String formatarData(DateTime? data, {String vazio = '—'}) =>
    data == null ? vazio : _data.format(data);

/// Data e hora, ex. "09/11/2026 14:30" (emissão de documentos).
String formatarDataHora(DateTime data) => _dataHora.format(data);

/// Valor para um campo de texto editável: "150,00", sem símbolo.
String formatarValorEditavel(double valor) =>
    valor.toStringAsFixed(2).replaceAll('.', ',');

/// Lê um valor digitado com vírgula ou ponto como separador decimal
/// ("150", "150,5", "150.50"). Sem separador de milhar. `null` se o
/// texto não for um número.
double? lerValorMonetario(String texto) =>
    double.tryParse(texto.trim().replaceAll(',', '.'));
