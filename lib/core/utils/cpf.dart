/// Validação de CPF pelos dígitos verificadores (RF01, ADR 002).
///
/// Aceita o CPF com ou sem máscara — só os dígitos são considerados.
/// Sequências repetidas (000.000.000-00, 111.111.111-11...) passam no
/// cálculo dos dígitos, mas não são CPFs emitidos, então são rejeitadas.
bool cpfValido(String cpf) {
  final digitos = apenasDigitos(cpf);
  if (digitos.length != 11) return false;
  if (RegExp(r'^(\d)\1{10}$').hasMatch(digitos)) return false;

  final numeros = digitos.split('').map(int.parse).toList();
  return _digitoVerificador(numeros, 9) == numeros[9] &&
      _digitoVerificador(numeros, 10) == numeros[10];
}

/// Calcula o dígito verificador sobre os [quantidade] primeiros dígitos,
/// com pesos decrescentes a partir de quantidade + 1.
int _digitoVerificador(List<int> numeros, int quantidade) {
  var soma = 0;
  for (var i = 0; i < quantidade; i++) {
    soma += numeros[i] * (quantidade + 1 - i);
  }
  final resto = soma % 11;
  return resto < 2 ? 0 : 11 - resto;
}

String apenasDigitos(String texto) => texto.replaceAll(RegExp(r'\D'), '');

/// CPF com a parte do meio oculta, para documentos que saem do app
/// (LGPD): só os 3 primeiros e os 2 últimos dígitos aparecem, como em
/// `529.***.***-25`. CPF que não tem 11 dígitos é todo oculto.
String mascararCpf(String cpf) {
  final d = apenasDigitos(cpf);
  if (d.length != 11) return '***.***.***-**';
  return '${d.substring(0, 3)}.***.***-${d.substring(9)}';
}
