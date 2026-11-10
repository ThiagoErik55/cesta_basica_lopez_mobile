import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../theme/app_colors.dart';

/// Peças compartilhadas pelos PDFs do app (comprovante, KAN-36, e nota
/// provisória, KAN-37): cores, sanitização de texto, cabeçalho, seções,
/// linhas e rodapé. Só fontes padrão do PDF, então tudo funciona sem rede.

/// Troca por "?" o que as fontes padrão do PDF não desenham (acima de
/// U+00FF, como emoji) e remove quebras de controle. Sem isso, um nome
/// ou observação digitado com um desses caracteres faria a geração
/// lançar exceção.
String textoSeguroPdf(String texto) {
  final b = StringBuffer();
  for (final r in texto.runes) {
    if (r == 0x0A || r == 0x0D || r == 0x09) {
      b.write(' ');
    } else if (r < 0x20 || (r >= 0x7F && r <= 0x9F)) {
      continue;
    } else {
      b.write(r <= 0xFF ? String.fromCharCode(r) : '?');
    }
  }
  return b.toString();
}

/// Cores da marca no formato do pacote `pdf`.
class CoresPdf {
  CoresPdf._();

  static final marca = PdfColor.fromInt(AppColors.primary.toARGB32());
  static final marcaEscura = PdfColor.fromInt(AppColors.primaryDark.toARGB32());
  static final cinza = PdfColor.fromInt(AppColors.textSecondary.toARGB32());
  static final verde = PdfColor.fromInt(AppColors.scoreA.toARGB32());
  static final borda = PdfColor.fromInt(AppColors.border.toARGB32());
}

/// "Cesta Básica Lopez", o título do documento e, opcionalmente, o
/// número, seguidos de um divisor.
pw.Widget cabecalhoPdf({required String titulo, String? numero}) => pw.Column(
  crossAxisAlignment: pw.CrossAxisAlignment.stretch,
  children: [
    pw.Text(
      'Cesta Básica Lopez',
      style: pw.TextStyle(
        fontSize: 20,
        fontWeight: pw.FontWeight.bold,
        color: CoresPdf.marca,
      ),
    ),
    pw.SizedBox(height: 2),
    pw.Text(
      titulo,
      style: const pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
    ),
    if (numero != null) ...[
      pw.SizedBox(height: 2),
      pw.Text(numero, style: pw.TextStyle(fontSize: 10, color: CoresPdf.cinza)),
    ],
    pw.SizedBox(height: 8),
    pw.Divider(color: CoresPdf.borda, thickness: 1),
  ],
);

/// Título de seção em caixa alta.
pw.Widget secaoPdf(String titulo) => pw.Padding(
  padding: const pw.EdgeInsets.only(top: 14, bottom: 4),
  child: pw.Text(
    titulo.toUpperCase(),
    style: pw.TextStyle(
      fontSize: 9,
      fontWeight: pw.FontWeight.bold,
      color: CoresPdf.marcaEscura,
    ),
  ),
);

/// Linha "rótulo ........ valor" alinhada nas pontas.
pw.Widget linhaPdf(
  String rotulo,
  String valor, {
  bool destaque = false,
}) => pw.Padding(
  padding: const pw.EdgeInsets.symmetric(vertical: 3),
  child: pw.Row(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
    children: [
      pw.Text(rotulo, style: pw.TextStyle(fontSize: 10, color: CoresPdf.cinza)),
      pw.SizedBox(width: 12),
      pw.Flexible(
        child: pw.Text(
          valor,
          textAlign: pw.TextAlign.right,
          style: pw.TextStyle(
            fontSize: destaque ? 15 : 11,
            fontWeight: destaque ? pw.FontWeight.bold : pw.FontWeight.normal,
          ),
        ),
      ),
    ],
  ),
);

/// Divisor, data/hora de emissão e o aviso [aviso] ao pé do documento.
pw.Widget rodapePdf({required String emitidoEm, required String aviso}) =>
    pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: [
        pw.Divider(color: CoresPdf.borda, thickness: 1),
        pw.SizedBox(height: 4),
        pw.Text(
          'Emitido em $emitidoEm',
          style: pw.TextStyle(fontSize: 9, color: CoresPdf.cinza),
        ),
        pw.Text(aviso, style: pw.TextStyle(fontSize: 9, color: CoresPdf.cinza)),
      ],
    );
