import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:printing/printing.dart';

import '../services/compartilhador_pdf.dart';
import '../services/envio_whatsapp.dart';
import '../services/whatsapp_sharer.dart';
import '../theme/app_spacing.dart';
import 'empty_state.dart';
import 'primary_button.dart';

/// Dados para o botão "Enviar por WhatsApp" (KAN-39).
class DadosWhatsapp {
  const DadosWhatsapp({required this.mensagem, required this.telefone});

  /// Mensagem pronta, sem dados sensíveis.
  final String mensagem;

  /// Telefone do cliente como cadastrado; o envio o normaliza.
  final String telefone;
}

/// Preview de um PDF já gerado, com o botão "Compartilhar ou salvar PDF"
/// (comprovante, KAN-36, e nota provisória, KAN-37).
///
/// As ações nativas do `PdfPreview` ficam desligadas: o envio usa o
/// [compartilhadorPdfProvider], que a KAN-39 pode trocar (WhatsApp).
class PdfPreviewCompartilhavel extends ConsumerWidget {
  const PdfPreviewCompartilhavel({
    required this.bytes,
    required this.nomeArquivo,
    required this.mensagemErroCompartilhar,
    this.whatsapp,
    super.key,
  });

  final Uint8List bytes;
  final String nomeArquivo;

  /// Texto do aviso quando o compartilhamento falha.
  final String mensagemErroCompartilhar;

  /// Quando informado, mostra o botão "Enviar por WhatsApp".
  final DadosWhatsapp? whatsapp;

  Future<void> _compartilhar(BuildContext context, WidgetRef ref) async {
    final mensageiro = ScaffoldMessenger.of(context);
    try {
      await ref
          .read(compartilhadorPdfProvider)
          .compartilhar(bytes: bytes, nomeArquivo: nomeArquivo);
    } catch (e) {
      debugPrint('Erro ao compartilhar $nomeArquivo: $e');
      mensageiro.showSnackBar(
        SnackBar(content: Text(mensagemErroCompartilhar)),
      );
    }
  }

  Future<void> _enviarWhatsapp(BuildContext context, WidgetRef ref) async {
    final dados = whatsapp!;
    final mensageiro = ScaffoldMessenger.of(context);
    final desfecho = await enviarPorWhatsapp(
      sharer: ref.read(whatsappSharerProvider),
      fallback: ref.read(compartilhadorPdfProvider),
      bytes: bytes,
      nomeArquivo: nomeArquivo,
      mensagem: dados.mensagem,
      telefoneCliente: dados.telefone,
    );
    final aviso = switch (desfecho) {
      DesfechoEnvioWhatsapp.compartilhado =>
        'Escolha o WhatsApp e o contato do cliente na lista.',
      DesfechoEnvioWhatsapp.compartilhadoSemTelefone =>
        'Cliente sem telefone válido; escolha o contato no WhatsApp.',
      DesfechoEnvioWhatsapp.chatSemArquivo =>
        'O WhatsApp Web recebe só a mensagem. Salve o PDF e anexe na conversa.',
      DesfechoEnvioWhatsapp.fallbackCompartilhamento =>
        'Não foi possível abrir o WhatsApp. Use o compartilhamento do '
            'sistema.',
      DesfechoEnvioWhatsapp.falha =>
        'Não foi possível enviar. Tente "Compartilhar ou salvar PDF".',
    };
    mensageiro.showSnackBar(SnackBar(content: Text(aviso)));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      children: [
        Expanded(
          child: PdfPreview(
            build: (_) async => bytes,
            pdfFileName: nomeArquivo,
            useActions: false,
            allowSharing: false,
            allowPrinting: false,
            canChangePageFormat: false,
            canChangeOrientation: false,
            canDebug: false,
            loadingWidget: const CircularProgressIndicator(),
            onError: (context, error) => const Center(
              child: EmptyState(
                icone: Icons.error_outline,
                titulo: 'Erro ao exibir o documento',
                descricao: 'Tente compartilhar o arquivo pelo botão abaixo.',
              ),
            ),
          ),
        ),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                PrimaryButton(
                  texto: 'Compartilhar ou salvar PDF',
                  onPressed: () => _compartilhar(context, ref),
                ),
                if (whatsapp != null) ...[
                  const SizedBox(height: AppSpacing.sm),
                  SecondaryButton(
                    texto: 'Enviar por WhatsApp',
                    onPressed: () => _enviarWhatsapp(context, ref),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}
