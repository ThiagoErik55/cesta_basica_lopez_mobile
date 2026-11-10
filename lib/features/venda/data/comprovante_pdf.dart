import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../../core/pdf/pdf_comum.dart';
import '../../../core/utils/formatadores.dart';
import '../domain/comprovante_pagamento.dart';
import '../domain/rotulos_venda.dart';

/// Gera o PDF do comprovante de pagamento (KAN-36): uma página A5, só com
/// as fontes padrão do PDF, então funciona sem rede.
///
/// Recebe o [ComprovantePagamento] já montado; não consulta dados nem
/// decide regras. Só usa caracteres Latin-1 (as fontes padrão não têm
/// outros), por isso não há travessão nem reticências nos textos.
Future<Uint8List> gerarPdfComprovante(ComprovantePagamento c) async {
  final verde = CoresPdf.verde;

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
          cabecalhoPdf(
            titulo: 'Comprovante de Pagamento',
            numero: 'Nº ${c.numero}',
          ),

          secaoPdf('Cliente'),
          linhaPdf('Nome', textoSeguroPdf(c.clienteNome)),
          linhaPdf('CPF', c.cpfMascarado),

          secaoPdf('Pagamento'),
          linhaPdf('Venda', 'Nota ${c.numeroNota}'),
          linhaPdf('Parcela', '${c.numeroParcela}/${c.totalParcelas}'),
          linhaPdf('Data do pagamento', formatarData(c.dataPagamento)),
          linhaPdf('Forma de pagamento', c.forma.rotulo),
          if (c.observacao != null)
            linhaPdf('Observação', textoSeguroPdf(c.observacao!)),
          pw.SizedBox(height: 4),
          linhaPdf('Valor pago', formatarMoeda(c.valorPago), destaque: true),

          secaoPdf('Situação após o pagamento'),
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
            linhaPdf(
              'Saldo restante da parcela',
              formatarMoeda(c.saldoRestanteParcela),
            ),
          linhaPdf(
            'Saldo em aberto da venda',
            formatarMoeda(c.saldoEmAbertoVenda),
          ),

          pw.Spacer(),
          rodapePdf(
            emitidoEm: formatarDataHora(c.emitidoEm),
            aviso: 'Comprovante sem valor fiscal.',
          ),
        ],
      ),
    ),
  );

  return documento.save();
}
