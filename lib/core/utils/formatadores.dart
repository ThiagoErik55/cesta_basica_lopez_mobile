import 'package:intl/intl.dart';

/// Formatação de valores para exibição (pt-BR).
final _moeda = NumberFormat.currency(locale: 'pt_BR', symbol: r'R$');
final _data = DateFormat('dd/MM/yyyy');

String formatarMoeda(double valor) => _moeda.format(valor);

/// [vazio] é exibido quando não há data (ex. cliente que nunca comprou).
String formatarData(DateTime? data, {String vazio = '—'}) =>
    data == null ? vazio : _data.format(data);
