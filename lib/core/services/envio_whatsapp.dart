import 'package:flutter/foundation.dart';

import '../utils/whatsapp.dart';
import 'compartilhador_pdf.dart';
import 'whatsapp_sharer.dart';

/// Como terminou o envio, para a tela escolher a mensagem ao usuário.
enum DesfechoEnvioWhatsapp {
  /// Folha aberta e o telefone do cliente é válido: o usuário só precisa
  /// escolher o contato certo.
  compartilhado,

  /// Folha aberta, mas o cliente não tem telefone válido.
  compartilhadoSemTelefone,

  /// Conversa aberta só com o texto (web).
  chatSemArquivo,

  /// WhatsApp ausente ou com falha: abriu o compartilhamento comum.
  fallbackCompartilhamento,

  /// Nem o fallback funcionou.
  falha,
}

/// Envia [bytes] por WhatsApp e decide o que fazer quando algo falha
/// (KAN-39).
///
/// - [telefoneCliente] é normalizado; se não for válido, o envio segue
///   sem número e o desfecho avisa a tela.
/// - WhatsApp ausente ou erro: cai em [fallback] (compartilhamento comum)
///   com a mesma mensagem.
Future<DesfechoEnvioWhatsapp> enviarPorWhatsapp({
  required WhatsappSharer sharer,
  required CompartilhadorPdf fallback,
  required Uint8List bytes,
  required String nomeArquivo,
  required String mensagem,
  required String? telefoneCliente,
}) async {
  final telefone = normalizarTelefoneWhatsApp(telefoneCliente);

  try {
    final resultado = await sharer.enviar(
      bytes: bytes,
      nomeArquivo: nomeArquivo,
      mensagem: mensagem,
      telefone: telefone,
    );
    switch (resultado) {
      case ResultadoWhatsapp.compartilhado:
        return telefone == null
            ? DesfechoEnvioWhatsapp.compartilhadoSemTelefone
            : DesfechoEnvioWhatsapp.compartilhado;
      case ResultadoWhatsapp.chatSemArquivo:
        return DesfechoEnvioWhatsapp.chatSemArquivo;
      case ResultadoWhatsapp.naoInstalado:
        break;
    }
  } catch (e) {
    debugPrint('Falha no envio por WhatsApp: ${e.runtimeType}');
  }

  try {
    await fallback.compartilhar(
      bytes: bytes,
      nomeArquivo: nomeArquivo,
      mensagem: mensagem,
    );
    return DesfechoEnvioWhatsapp.fallbackCompartilhamento;
  } catch (e) {
    debugPrint('Falha no compartilhamento comum: ${e.runtimeType}');
    return DesfechoEnvioWhatsapp.falha;
  }
}
