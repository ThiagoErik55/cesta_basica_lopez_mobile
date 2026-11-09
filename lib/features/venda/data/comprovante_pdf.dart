import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatadores.dart';
import '../domain/comprovante_pagamento.dart';
import '../domain/rotulos_venda.dart';

/// Troca por "?" o que as fontes padrão do PDF não desenham (acima de
/// U+00FF, como emoji) e remove quebras de controle. Sem isso, um nome
/// ou observação digitado com um desses caracteres faria a geração
/// lançar exceção.
String _seguro(String texto) {
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

/// Gera o PDF do comprovante de pagamento (KAN-36): uma página A5, só com
/// as fontes padrão do PDF, então funciona sem rede.
///
/// Recebe o [ComprovantePagamento] já montado; não consulta dados nem
/// decide regras. Só usa caracteres Latin-1 (as fontes padrão não têm
/// outros), por isso não há travessão nem reticências nos textos.
Future<Uint8List> gerarPdfComprovante(ComprovantePagamento c) async {
  final marca = PdfColor.fromInt(AppColors.primary.toARGB32());
  final marcaEscura = PdfColor.fromInt(AppColors.primaryDark.toARGB32());
  final cinza = PdfColor.fromInt(AppColors.textSecondary.toARGB32());
  final verde = PdfColor.fromInt(AppColors.scoreA.toARGB32());
  final borda = PdfColor.fromInt(AppColors.border.toARGB32());

  pw.Widget linha(String rotulo, String valor, {bool destaque = false}) =>
      pw.Padding(
        padding: const pw.EdgeInsets.symmetric(vertical: 3),
        child: pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(rotulo, style: pw.TextStyle(fontSize: 10, color: cinza)),
            pw.SizedBox(width: 12),
            pw.Flexible(
              child: pw.Text(
                valor,
                textAlign: pw.TextAlign.right,
                style: pw.TextStyle(
                  fontSize: destaque ? 15 : 11,
                  fontWeight: destaque
                      ? pw.FontWeight.bold
                      : pw.FontWeight.normal,
                ),
              ),
            ),
          ],
        ),
      );

  pw.Widget secao(String titulo) => pw.Padding(
    padding: const pw.EdgeInsets.only(top: 14, bottom: 4),
    child: pw.Text(
      titulo.toUpperCase(),
      style: pw.TextStyle(
        fontSize: 9,
        fontWeight: pw.FontWeight.bold,
        color: marcaEscura,
      ),
    ),
  );

  final documento = pw.Document(
    title: 'Comprovante de Pagamento ${c.numero}',
    author: 'Cesta Básica Lopez',
  );

  documento.addPage(
    pw.Page(
      pageFormat: PdfPageFormat.a5,
      margin: const pw.EdgeInsets.all(28),
      build: (_) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.stretch,
        children: [
          pw.Text(
            'Cesta Básica Lopez',
            style: pw.TextStyle(
              fontSize: 20,
              fontWeight: pw.FontWeight.bold,
              color: marca,
            ),
          ),
          pw.SizedBox(height: 2),
          pw.Text(
            'Comprovante de Pagamento',
            style: const pw.TextStyle(fontSize: 14)
                .copyWith(fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 2),
          pw.Text(
            'Nº ${c.numero}',
            style: pw.TextStyle(fontSize: 10, color: cinza),
          ),
          pw.SizedBox(height: 8),
          pw.Divider(color: borda, thickness: 1),

          secao('Cliente'),
          linha('Nome', _seguro(c.clienteNome)),
          linha('CPF', c.cpfMascarado),

          secao('Pagamento'),
          linha('Venda', 'Nota ${c.numeroNota}'),
          linha('Parcela', '${c.numeroParcela}/${c.totalParcelas}'),
          linha('Data do pagamento', formatarData(c.dataPagamento)),
          linha('Forma de pagamento', c.forma.rotulo),
          if (c.observacao != null) linha('Observação', _seguro(c.observacao!)),
          pw.SizedBox(height: 4),
          linha('Valor pago', formatarMoeda(c.valorPago), destaque: true),

          secao('Situação após o pagamento'),
          if (c.parcelaQuitada)
            pw.Container(
              margin: const pw.EdgeInsets.symmetric(vertical: 3),
              padding: const pw.EdgeInsets.symmetric(vertical: 5),
              alignment: pw.Alignment.center,
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: verde, width: 1.2),
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
              ),
              child: pw.Text(
                'Parcela quitada',
                style: pw.TextStyle(
                  fontSize: 12,
                  fontWeight: pw.FontWeight.bold,
                  color: verde,
                ),
              ),
            )
          else
            linha(
              'Saldo restante da parcela',
              formatarMoeda(c.saldoRestanteParcela),
            ),
          linha(
            'Saldo em aberto da venda',
            formatarMoeda(c.saldoEmAbertoVenda),
          ),

          pw.Spacer(),
          pw.Divider(color: borda, thickness: 1),
          pw.SizedBox(height: 4),
          pw.Text(
            'Emitido em ${formatarDataHora(c.emitidoEm)}',
            style: pw.TextStyle(fontSize: 9, color: cinza),
          ),
          pw.Text(
            'Comprovante sem valor fiscal.',
            style: pw.TextStyle(fontSize: 9, color: cinza),
          ),
        ],
      ),
    ),
  );

  return documento.save();
}
