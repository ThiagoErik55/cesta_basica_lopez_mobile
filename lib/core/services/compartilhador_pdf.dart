import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:printing/printing.dart';

/// Compartilha ou salva um PDF já gerado, pelo compartilhamento do
/// sistema (KAN-36).
///
/// Genérico de propósito: recebe só os bytes e o nome do arquivo, sem
/// saber de comprovante nem de pagamento. Outros documentos podem
/// reutilizá-lo, e o envio específico por WhatsApp (KAN-39) pode vir como
/// outra implementação, trocada em [compartilhadorPdfProvider].
abstract class CompartilhadorPdf {
  Future<void> compartilhar({
    required Uint8List bytes,
    required String nomeArquivo,
  });
}

/// Abre o compartilhamento do sistema (salvar em arquivos, enviar por
/// qualquer app instalado).
class CompartilhadorPdfSistema implements CompartilhadorPdf {
  const CompartilhadorPdfSistema();

  @override
  Future<void> compartilhar({
    required Uint8List bytes,
    required String nomeArquivo,
  }) async {
    // Devolve false quando o usuário fecha a folha sem escolher nada,
    // o que não é erro.
    await Printing.sharePdf(bytes: bytes, filename: nomeArquivo);
  }
}

final compartilhadorPdfProvider = Provider<CompartilhadorPdf>(
  (ref) => const CompartilhadorPdfSistema(),
);
