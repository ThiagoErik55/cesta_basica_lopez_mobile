import 'whatsapp.dart';

/// Link `tel:` para ligar ao cliente (KAN-47), ex. `tel:+5545999990001`.
///
/// Reaproveita a normalização do WhatsApp (KAN-39): aceita o telefone com
/// ou sem máscara, com 10 ou 11 dígitos, com ou sem o `55`. Devolve
/// `null` se o número não é um telefone brasileiro válido; nesse caso a
/// tela não mostra o botão "Ligar".
Uri? uriDeLigacao(String? telefone) {
  final normalizado = normalizarTelefoneWhatsApp(telefone);
  if (normalizado == null) return null;
  return Uri(scheme: 'tel', path: '+$normalizado');
}
