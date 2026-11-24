import 'dart:convert';

import 'package:cesta_basica_lopez_mobile/core/domain/enums.dart';
import 'package:cesta_basica_lopez_mobile/features/financeiro/data/despesa_model.dart';
import 'package:cesta_basica_lopez_mobile/features/financeiro/data/relatorio_semanal_pdf.dart';
import 'package:cesta_basica_lopez_mobile/features/financeiro/domain/periodo.dart';
import 'package:cesta_basica_lopez_mobile/features/financeiro/domain/relatorio_linha.dart';
import 'package:cesta_basica_lopez_mobile/features/venda/data/venda_model.dart';
import 'package:flutter_test/flutter_test.dart';

final _quarta = DateTime(2026, 11, 18, 10);
final _semana = Periodo.semana(_quarta);

VendaModel _venda(String id, String clienteId, double preco) => VendaModel(
  id: id,
  clienteId: clienteId,
  clienteNome: 'Cliente $clienteId',
  vendedorUid: 'u1',
  numeroNota: 1,
  data: _quarta,
  itens: [
    ItemVenda(
      id: 'i$id',
      produtoId: 'p1',
      nome: 'Cesta',
      quantidade: 1,
      precoUnitario: preco,
      custoUnitario: preco / 2,
    ),
  ],
  valorTotal: preco,
  tipo: TipoVenda.aVista,
  updatedAt: _quarta,
);

RelatorioSemanal _relatorio({bool comMovimento = true}) =>
    montarRelatorioSemanal(
      semana: _semana,
      vendas: comMovimento
          ? [
              _venda('v1', 'c1', 1234.56),
              _venda('v2', 'c2', 300),
              _venda('v3', 'c3', 80),
            ]
          : const [],
      despesas: comMovimento
          ? [
              DespesaModel(
                id: 'd1',
                vendedorUid: 'u1',
                descricao: 'Combustível',
                valor: 150,
                data: _quarta,
                updatedAt: _quarta,
              ),
            ]
          : const [],
      grupos: const {
        'c1': GrupoLinha.toledo,
        'c2': GrupoLinha.regional,
        'c3': GrupoLinha.semLinha,
      },
      pagamentos: const [],
    );

int _paginas(List<int> bytes) {
  final m = RegExp(r'/Count (\d+)').allMatches(latin1.decode(bytes));
  return m.map((x) => int.parse(x.group(1)!)).fold(0, (a, b) => a > b ? a : b);
}

void main() {
  test('gera bytes de PDF', () async {
    final bytes = await gerarPdfRelatorioSemanal(
      _relatorio(),
      vendedor: 'Joana Silva',
      geradoEm: DateTime(2026, 11, 22, 18, 5),
    );
    expect(bytes, isNotEmpty);
    expect(ascii.decode(bytes.sublist(0, 4)), '%PDF');
  });

  test('cabe em uma página A4 com as três linhas e as despesas', () async {
    final bytes = await gerarPdfRelatorioSemanal(
      _relatorio(),
      vendedor: 'Joana Silva',
      geradoEm: DateTime(2026, 11, 22, 18, 5),
    );
    expect(_paginas(bytes), 1);
  });

  test('semana sem movimento também gera uma página', () async {
    final bytes = await gerarPdfRelatorioSemanal(
      _relatorio(comMovimento: false),
      vendedor: 'joana@exemplo.com',
      geradoEm: DateTime(2026, 11, 22),
    );
    expect(ascii.decode(bytes.sublist(0, 4)), '%PDF');
    expect(_paginas(bytes), 1);
  });

  test('nome do vendedor com emoji e acento não quebra a geração', () async {
    final bytes = await gerarPdfRelatorioSemanal(
      _relatorio(),
      vendedor: 'José 😀 Álvares',
      geradoEm: DateTime(2026, 11, 22),
    );
    expect(ascii.decode(bytes.sublist(0, 4)), '%PDF');
  });

  test(
    'lucro líquido negativo (minus) não usa caractere fora do Latin-1',
    () async {
      final r = montarRelatorioSemanal(
        semana: _semana,
        vendas: const [],
        despesas: [
          DespesaModel(
            id: 'd1',
            vendedorUid: 'u1',
            descricao: 'Conserto',
            valor: 500,
            data: _quarta,
            updatedAt: _quarta,
          ),
        ],
        grupos: const {},
        pagamentos: const [],
      );
      expect(r.lucroLiquido, -50000);
      final bytes = await gerarPdfRelatorioSemanal(
        r,
        vendedor: 'Joana',
        geradoEm: DateTime(2026, 11, 22),
      );
      expect(ascii.decode(bytes.sublist(0, 4)), '%PDF');
    },
  );

  group('nomeArquivoRelatorioSemanal', () {
    test('relatorio-semanal-AAAAMMDD-AAAAMMDD.pdf da segunda ao domingo', () {
      expect(
        nomeArquivoRelatorioSemanal(_semana),
        'relatorio-semanal-20261116-20261122.pdf',
      );
    });

    test('semana na virada de mês e de ano', () {
      expect(
        nomeArquivoRelatorioSemanal(Periodo.semana(DateTime(2026, 12, 31))),
        'relatorio-semanal-20261228-20270103.pdf',
      );
    });

    test('só caracteres seguros no nome', () {
      expect(
        RegExp(r'^[a-z0-9.\-]+$')
            .hasMatch(nomeArquivoRelatorioSemanal(_semana)),
        isTrue,
      );
    });
  });
}
