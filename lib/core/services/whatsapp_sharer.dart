import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../utils/whatsapp.dart';
import 'compartilhador_pdf.dart';

/// O que o envio por WhatsApp conseguiu fazer.
enum ResultadoWhatsapp {
  /// Abriu a folha de compartilhamento com o PDF e a mensagem, para o
  /// usuário escolher o WhatsApp e o contato.
  compartilhado,

  /// Abriu o chat pelo link `wa.me` só com a mensagem (web): o link não
  /// anexa arquivo.
  chatSemArquivo,

  /// O WhatsApp não está instalado.
  naoInstalado,
}

/// Envia um PDF por WhatsApp (KAN-39). Atrás de interface para os fluxos
/// serem testados com um fake.
///
/// **Limitação:** o link `wa.me` leva só texto e não anexa arquivo, e o
/// plugin de compartilhamento não deixa escolher o app nem o contato de
/// destino. Por isso, no celular o PDF e a mensagem vão pela folha de
/// compartilhamento do sistema e o usuário escolhe o WhatsApp e o
/// contato; [telefone] só é usado na web, onde abre a conversa com a
/// mensagem (sem o PDF, que o usuário baixa à parte).
abstract class WhatsappSharer {
  /// [telefone] já normalizado (`55DDDNÚMERO`) ou `null`.
  Future<ResultadoWhatsapp> enviar({
    required Uint8List bytes,
    required String nomeArquivo,
    required String mensagem,
    String? telefone,
  });
}

class WhatsappSharerSistema implements WhatsappSharer {
  const WhatsappSharerSistema(this._compartilhador);

  final CompartilhadorPdf _compartilhador;

  @override
  Future<ResultadoWhatsapp> enviar({
    required Uint8List bytes,
    required String nomeArquivo,
    required String mensagem,
    String? telefone,
  }) async {
    if (kIsWeb) {
      final aberto = await launchUrl(
        linkWhatsApp(mensagem: mensagem, telefoneWhatsApp: telefone),
        mode: LaunchMode.externalApplication,
      );
      if (!aberto) return ResultadoWhatsapp.naoInstalado;
      return ResultadoWhatsapp.chatSemArquivo;
    }

    // Precisa do <queries> (Android) e do LSApplicationQueriesSchemes
    // (iOS) para enxergar o app.
    final instalado = await canLaunchUrl(Uri.parse('whatsapp://send'));
    if (!instalado) return ResultadoWhatsapp.naoInstalado;

    await _compartilhador.compartilhar(
      bytes: bytes,
      nomeArquivo: nomeArquivo,
      mensagem: mensagem,
    );
    return ResultadoWhatsapp.compartilhado;
  }
}

final whatsappSharerProvider = Provider<WhatsappSharer>(
  (ref) => WhatsappSharerSistema(ref.watch(compartilhadorPdfProvider)),
);
