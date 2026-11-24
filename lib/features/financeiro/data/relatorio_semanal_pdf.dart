import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../../core/pdf/pdf_comum.dart';
import '../../../core/utils/formatadores.dart';
import '../domain/agregacao_financeira.dart';
import '../domain/periodo.dart';
import '../domain/relatorio_linha.dart';

/// Gera o PDF do relatório semanal por linha de atendimento (KAN-53):
/// uma página A4, só com as fontes padrão do PDF (Latin-1), então
/// funciona sem rede. Reaproveita as peças de `pdf_comum.dart`.
///
/// Recebe o [RelatorioSemanal] já montado; não consulta dados nem decide
/// regras. Não leva CPF nem dados de cliente, só totais por linha.
Future<Uint8List> gerarPdfRelatorioSemanal(
  RelatorioSemanal relatorio, {
  required String vendedor,
  required DateTime geradoEm,
}) async {
  final documento = pw.Document(
    title: 'Relatório semanal por linha de atendimento',
    author: 'Cesta Básica Lopez',
  );
  final semana = relatorio.semana;

  documento.addPage(
    pw.Page(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(28),
      build: (_) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.stretch,
        children: [
          cabecalhoPdf(
            titulo: 'Relatório semanal por linha de atendimento',
            numero:
                'Semana de ${formatarData(semana.inicio)} a '
                '${formatarData(semana.ultimoDia)}',
          ),
          pw.SizedBox(height: 4),
          linhaPdf('Vendedor', textoSeguroPdf(vendedor)),
          if (!relatorio.recebidoCompleto)
            pw.Text(
              'Recebido sem os pagamentos de parcelas (nao carregados).',
              style: pw.TextStyle(fontSize: 9, color: CoresPdf.cinza),
            ),
          secaoPdf('Resultado por linha'),
          _tabela(relatorio),
          pw.SizedBox(height: 4),
          pw.Text(
            'Linha pela rota atual do cliente. Cliente sem rota fica em '
            '"Sem linha".',
            style: pw.TextStyle(fontSize: 8, color: CoresPdf.cinza),
          ),
          secaoPdf('Resultado da semana'),
          linhaPdf('Lucro bruto total', _reais(relatorio.total.lucroBruto)),
          linhaPdf(
            'Despesas gerais, nao atribuidas a linha',
            _reais(relatorio.despesasGerais),
          ),
          pw.SizedBox(height: 4),
          linhaPdf(
            'Lucro liquido (lucro bruto - despesas)',
            _reais(relatorio.lucroLiquido),
            destaque: true,
          ),
          pw.Spacer(),
          rodapePdf(
            emitidoEm: formatarDataHora(geradoEm),
            rotuloEmissao: 'Gerado em',
            aviso: 'Documento gerencial, sem valor fiscal',
          ),
        ],
      ),
    ),
  );

  return documento.save();
}

/// Nome do arquivo: `relatorio-semanal-AAAAMMDD-AAAAMMDD.pdf`, da segunda
/// ao domingo da semana.
String nomeArquivoRelatorioSemanal(Periodo semana) =>
    'relatorio-semanal-${_aaaammdd(semana.inicio)}-'
    '${_aaaammdd(semana.ultimoDia)}.pdf';

const _cinzaClaro = PdfColor.fromInt(0xFFEFEFEF);

String _aaaammdd(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}'
    '${d.month.toString().padLeft(2, '0')}'
    '${d.day.toString().padLeft(2, '0')}';

/// As fontes padrão do PDF não têm o "−" (U+2212): usa o hífen.
String _reais(int centavos) => formatarCentavos(centavos).replaceAll('−', '-');

String _percentual(int decimos) =>
    '${(decimos / 10).toStringAsFixed(1).replaceAll('.', ',')}%';

String _margem(double v) => '${v.toStringAsFixed(1).replaceAll('.', ',')}%';

pw.Widget _tabela(RelatorioSemanal r) {
  const cabecalho = [
    'Linha',
    'Vendas',
    'Faturamento',
    'Custo',
    'Lucro bruto',
    'Margem',
    'Ticket',
    'Recebido',
    'Partic.',
  ];
  final recebidoCompleto = r.recebidoCompleto;
  List<String> celulas(
    String rotulo,
    TotaisFinanceiros t,
    double margem,
    int? part,
  ) => [
    textoSeguroPdf(rotulo),
    '${t.vendas}',
    _reais(t.faturamento),
    _reais(t.custo),
    _reais(t.lucroBruto),
    _margem(margem),
    _reais(t.ticketMedio),
    recebidoCompleto ? _reais(t.recebido) : '-',
    part == null ? '100,0%' : _percentual(part),
  ];

  final totalMargem = r.total.faturamento <= 0
      ? 0.0
      : r.total.lucroBruto / r.total.faturamento * 100;
  final linhas = [
    for (final l in r.linhas)
      celulas(l.rotulo, l.totais, l.margem, l.participacaoDecimos),
  ];
  final total = celulas('TOTAL', r.total, totalMargem, null);

  pw.Widget celula(String texto, int coluna, {bool negrito = false}) =>
      pw.Padding(
        padding: const pw.EdgeInsets.symmetric(horizontal: 3, vertical: 4),
        child: pw.Text(
          texto,
          textAlign: coluna == 0 ? pw.TextAlign.left : pw.TextAlign.right,
          style: pw.TextStyle(
            fontSize: 8,
            fontWeight: negrito ? pw.FontWeight.bold : pw.FontWeight.normal,
          ),
        ),
      );

  pw.TableRow linha(
    List<String> valores, {
    bool negrito = false,
    PdfColor? fundo,
  }) => pw.TableRow(
    decoration: pw.BoxDecoration(color: fundo),
    children: [
      for (final (i, v) in valores.indexed) celula(v, i, negrito: negrito),
    ],
  );

  return pw.Table(
    border: pw.TableBorder(
      horizontalInside: pw.BorderSide(color: CoresPdf.borda, width: 0.5),
      bottom: pw.BorderSide(color: CoresPdf.borda),
      top: pw.BorderSide(color: CoresPdf.borda),
    ),
    columnWidths: const {
      0: pw.FlexColumnWidth(1.6),
      1: pw.FlexColumnWidth(1),
      2: pw.FlexColumnWidth(2),
      3: pw.FlexColumnWidth(2),
      4: pw.FlexColumnWidth(2),
      5: pw.FlexColumnWidth(1.3),
      6: pw.FlexColumnWidth(1.8),
      7: pw.FlexColumnWidth(2),
      8: pw.FlexColumnWidth(1.3),
    },
    children: [
      linha(cabecalho, negrito: true, fundo: _cinzaClaro),
      for (final l in linhas) linha(l),
      linha(total, negrito: true, fundo: _cinzaClaro),
    ],
  );
}
