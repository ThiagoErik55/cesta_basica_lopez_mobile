import 'package:flutter/services.dart';

import 'cpf.dart';

/// Máscaras de entrada para CPF e telefone. Implementadas aqui em vez de
/// um pacote (mask_text_input_formatter e similares) porque os dois
/// formatos são fixos e curtos — não justificam uma dependência nova.
///
/// O formatter descarta tudo que não é dígito e reaplica a máscara a
/// cada alteração, deixando o cursor sempre no fim do texto.
class MascaraFormatter extends TextInputFormatter {
  MascaraFormatter._(this._formatar, this._maxDigitos);

  /// 000.000.000-00
  factory MascaraFormatter.cpf() => MascaraFormatter._(_formatarCpf, 11);

  /// (00) 0000-0000 para fixo, (00) 00000-0000 para celular.
  factory MascaraFormatter.telefone() =>
      MascaraFormatter._(_formatarTelefone, 11);

  final String Function(String digitos) _formatar;
  final int _maxDigitos;

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    var digitos = apenasDigitos(newValue.text);
    if (digitos.length > _maxDigitos) {
      digitos = digitos.substring(0, _maxDigitos);
    }
    final texto = _formatar(digitos);
    return TextEditingValue(
      text: texto,
      selection: TextSelection.collapsed(offset: texto.length),
    );
  }
}

String _formatarCpf(String d) {
  final b = StringBuffer();
  for (var i = 0; i < d.length; i++) {
    if (i == 3 || i == 6) b.write('.');
    if (i == 9) b.write('-');
    b.write(d[i]);
  }
  return b.toString();
}

String _formatarTelefone(String d) {
  if (d.isEmpty) return '';
  if (d.length <= 2) return '($d';
  final ddd = d.substring(0, 2);
  final numero = d.substring(2);
  // Com 9 dígitos após o DDD é celular (5 + 4); até 8, fixo (4 + 4).
  final corte = numero.length > 8 ? 5 : 4;
  if (numero.length <= corte) return '($ddd) $numero';
  return '($ddd) ${numero.substring(0, corte)}-${numero.substring(corte)}';
}

/// Entrada de valor monetário: só dígitos e um separador decimal
/// (vírgula ou ponto) com até duas casas. Edições fora desse formato
/// são ignoradas. Ler com `lerValorMonetario` (formatadores.dart).
final valorMonetarioFormatter = TextInputFormatter.withFunction(
  (antigo, novo) =>
      RegExp(r'^\d*([.,]\d{0,2})?$').hasMatch(novo.text) ? novo : antigo,
);
