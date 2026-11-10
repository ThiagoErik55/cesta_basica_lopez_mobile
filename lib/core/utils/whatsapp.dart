import 'cpf.dart' show apenasDigitos;

/// Telefone no formato do WhatsApp (KAN-39): só dígitos, com o código do
/// país, ex. `5545999990001`. Aceita o telefone com ou sem máscara, com 10
/// dígitos (DDD + fixo) ou 11 (DDD + celular), com ou sem o `55` na
/// frente. Devolve `null` se não for um número brasileiro válido: vazio,
/// curto ou longo demais, DDD inexistente (começa com 0), celular sem o 9.
String? normalizarTelefoneWhatsApp(String? telefone) {
  var d = apenasDigitos(telefone ?? '');
  // 12 ou 13 dígitos começando em 55 já têm o país. Com 10 ou 11, o 55
  // inicial é o DDD (RS), então não se remove.
  if ((d.length == 12 || d.length == 13) && d.startsWith('55')) {
    d = d.substring(2);
  }
  if (d.length != 10 && d.length != 11) return null;

  // DDD de 11 a 99: nenhum dos dois dígitos é zero.
  if (d[0] == '0' || d[1] == '0') return null;
  // Celular tem o nono dígito 9 logo depois do DDD.
  if (d.length == 11 && d[2] != '9') return null;
  return '55$d';
}

/// Link `wa.me` que abre a conversa com [mensagem] pronta. O link só leva
/// texto: o WhatsApp não aceita anexo por URL. Sem [telefoneWhatsApp]
/// (já normalizado) abre o WhatsApp para o usuário escolher o contato.
Uri linkWhatsApp({required String mensagem, String? telefoneWhatsApp}) => Uri(
  scheme: 'https',
  host: 'wa.me',
  path: '/${telefoneWhatsApp ?? ''}',
  // encodeComponent usa %20 para o espaço; queryParameters usaria '+'.
  query: 'text=${Uri.encodeComponent(mensagem)}',
);

/// Primeiro nome de [nome], ou `null` se não houver nome.
String? primeiroNome(String nome) {
  final partes = nome.trim().split(RegExp(r'\s+'));
  return partes.first.isEmpty ? null : partes.first;
}
