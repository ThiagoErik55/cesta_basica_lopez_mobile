import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../../core/domain/enums.dart';
import '../../../core/pdf/pdf_comum.dart';
import '../../../core/utils/formatadores.dart';
import '../domain/nota_provisoria.dart';
import '../domain/rotulos_venda.dart';

/// Gera o PDF da nota provisória de compra e venda (KAN-37): A4, só com
/// as fontes padrão do PDF, então funciona sem rede.
///
/// Recebe a [NotaProvisoria] já montada; não consulta dados nem decide
/// regras. Com muitos itens a nota continua nas páginas seguintes, com o
/// cabeçalho da tabela repetido; totais, condição de pagamento e a linha
/// de assinatura só aparecem no fim.
Future<Uint8List> gerarPdfNotaProvisoria(NotaProvisoria n) async {
  pw.Widget tabela({
    required List<String> cabecalho,
    required List<List<String>> linhas,
    required Map<int, pw.TableColumnWidth> larguras,
    required Map<int, pw.Alignment> alinhamentos,
  }) => pw.TableHelper.fromTextArray(
    headers: cabecalho,
    data: linhas,
    columnWidths: larguras,
    cellAlignments: alinhamentos,
    headerAlignments: alinhamentos,
    headerStyle: pw.TextStyle(
      fontSize: 9,
      fontWeight: pw.FontWeight.bold,
      color: CoresPdf.marcaEscura,
    ),
    cellStyle: const pw.TextStyle(fontSize: 10),
    headerDecoration: pw.BoxDecoration(
      border: pw.Border(
        bottom: pw.BorderSide(color: CoresPdf.marcaEscura, width: 1),
      ),
    ),
    cellDecoration: (_, _, _) => pw.BoxDecoration(
      border: pw.Border(bottom: pw.BorderSide(color: CoresPdf.borda)),
    ),
    cellPadding: const pw.EdgeInsets.symmetric(vertical: 4, horizontal: 3),
  );

  final documento = pw.Document(
    title: 'Nota Provisória ${n.numeroNota}',
    author: 'Cesta Básica Lopez',
  );

  final assinatura = n.assinatura == null
      ? null
      : pw.MemoryImage(n.assinatura!);

  documento.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(32),
      footer: (contexto) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.stretch,
        children: [
          rodapePdf(
            emitidoEm: formatarDataHora(n.emitidoEm),
            aviso: 'Documento provisório, sem valor fiscal.',
          ),
          pw.Align(
            alignment: pw.Alignment.centerRight,
            child: pw.Text(
              'Página ${contexto.pageNumber} de ${contexto.pagesCount}',
              style: pw.TextStyle(fontSize: 9, color: CoresPdf.cinza),
            ),
          ),
        ],
      ),
      build: (_) => [
        cabecalhoPdf(
          titulo: 'Nota Provisória de Compra e Venda',
          numero: 'Nº ${n.numeroNota}',
        ),
        linhaPdf('Data e hora da venda', formatarDataHora(n.dataVenda)),

        secaoPdf('Cliente'),
        linhaPdf('Nome', textoSeguroPdf(n.clienteNome)),
        linhaPdf('CPF', n.cpfMascarado),
        linhaPdf('Telefone', textoSeguroPdf(n.telefone)),
        linhaPdf('Endereço', textoSeguroPdf(n.endereco)),

        secaoPdf('Itens'),
        tabela(
          cabecalho: const [
            'Código',
            'Produto',
            'Qtd.',
            'Preço un.',
            'Subtotal',
          ],
          linhas: [
            for (final i in n.itens)
              [
                textoSeguroPdf(i.codigo),
                textoSeguroPdf(i.nome),
                '${i.quantidade}',
                formatarMoeda(i.precoUnitario),
                formatarMoeda(i.subtotal),
              ],
          ],
          larguras: {
            0: const pw.FixedColumnWidth(60),
            1: const pw.FlexColumnWidth(),
            2: const pw.FixedColumnWidth(36),
            3: const pw.FixedColumnWidth(70),
            4: const pw.FixedColumnWidth(76),
          },
          alinhamentos: {
            0: pw.Alignment.centerLeft,
            1: pw.Alignment.centerLeft,
            2: pw.Alignment.centerRight,
            3: pw.Alignment.centerRight,
            4: pw.Alignment.centerRight,
          },
        ),

        if (n.trocas.isNotEmpty) ...[
          secaoPdf('Trocas'),
          tabela(
            cabecalho: const ['Data', 'Troca', 'Qtd.', 'Diferença'],
            linhas: [
              for (final t in n.trocas)
                [
                  formatarData(t.data),
                  textoSeguroPdf('${t.produtoOriginal} por ${t.produtoNovo}'),
                  '${t.quantidade}',
                  t.diferenca == 0
                      ? '-'
                      : '${t.diferenca < 0 ? '-' : '+'}'
                            '${formatarMoeda(t.diferenca.abs())}',
                ],
            ],
            larguras: {
              0: const pw.FixedColumnWidth(60),
              1: const pw.FlexColumnWidth(),
              2: const pw.FixedColumnWidth(36),
              3: const pw.FixedColumnWidth(76),
            },
            alinhamentos: {
              0: pw.Alignment.centerLeft,
              1: pw.Alignment.centerLeft,
              2: pw.Alignment.centerRight,
              3: pw.Alignment.centerRight,
            },
          ),
          pw.SizedBox(height: 3),
          pw.Text(
            'A diferença da troca (valor abatido ou pago a mais) não está '
            'incluída no total da venda.',
            style: pw.TextStyle(fontSize: 8, color: CoresPdf.cinza),
          ),
        ],

        secaoPdf('Totais'),
        linhaPdf('Subtotal dos itens', formatarMoeda(n.subtotal)),
        if (n.temAjuste)
          linhaPdf(
            'Ajuste de parcela',
            '${n.ajusteParcela < 0 ? '-' : '+'}'
                '${formatarMoeda(n.ajusteParcela.abs())}',
          ),
        linhaPdf('Total da venda', formatarMoeda(n.total), destaque: true),

        secaoPdf('Condição de pagamento'),
        if (n.tipo == TipoVenda.aVista)
          linhaPdf('À vista', n.forma?.rotulo ?? '-')
        else ...[
          linhaPdf('Parcelado em', '${n.parcelas.length} parcelas'),
          pw.SizedBox(height: 4),
          tabela(
            cabecalho: const ['Parcela', 'Vencimento', 'Valor'],
            linhas: [
              for (final p in n.parcelas)
                [
                  '${p.numero}/${n.parcelas.length}',
                  formatarData(p.vencimento),
                  formatarMoeda(p.valor),
                ],
            ],
            larguras: {
              0: const pw.FixedColumnWidth(70),
              1: const pw.FlexColumnWidth(),
              2: const pw.FixedColumnWidth(90),
            },
            alinhamentos: {
              0: pw.Alignment.centerLeft,
              1: pw.Alignment.centerLeft,
              2: pw.Alignment.centerRight,
            },
          ),
        ],

        // A assinatura nunca fica separada do seu rótulo.
        pw.SizedBox(height: 18),
        pw.Center(
          child: pw.SizedBox(
            width: 260,
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.stretch,
              children: [
                pw.SizedBox(
                  height: 36,
                  child: assinatura == null
                      ? null
                      : pw.Center(child: pw.Image(assinatura, height: 36)),
                ),
                pw.Divider(color: CoresPdf.cinza, thickness: 0.8),
                pw.Text(
                  'Assinatura do cliente',
                  textAlign: pw.TextAlign.center,
                  style: pw.TextStyle(fontSize: 9, color: CoresPdf.cinza),
                ),
              ],
            ),
          ),
        ),
      ],
    ),
  );

  return documento.save();
}
