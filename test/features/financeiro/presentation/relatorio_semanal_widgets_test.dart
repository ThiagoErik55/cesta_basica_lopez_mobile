import 'dart:typed_data';

import 'package:cesta_basica_lopez_mobile/core/domain/enums.dart';
import 'package:cesta_basica_lopez_mobile/core/services/compartilhador_pdf.dart';
import 'package:cesta_basica_lopez_mobile/features/financeiro/domain/periodo.dart';
import 'package:cesta_basica_lopez_mobile/features/financeiro/domain/relatorio_linha.dart';
import 'package:cesta_basica_lopez_mobile/features/financeiro/domain/semana.dart';
import 'package:cesta_basica_lopez_mobile/features/financeiro/presentation/relatorio_semanal_providers.dart';
import 'package:cesta_basica_lopez_mobile/features/financeiro/presentation/relatorio_semanal_screen.dart';
import 'package:cesta_basica_lopez_mobile/features/financeiro/presentation/relatorio_tabela.dart';
import 'package:cesta_basica_lopez_mobile/features/financeiro/presentation/seletor_semana.dart';
import 'package:cesta_basica_lopez_mobile/features/venda/data/venda_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

final _semana = Periodo.semana(DateTime.now());
final _meioDaSemana = DateTime(
  _semana.inicio.year,
  _semana.inicio.month,
  _semana.inicio.day + 2,
  10,
);

VendaModel _venda(String id, String clienteId, double preco) => VendaModel(
  id: id,
  clienteId: clienteId,
  clienteNome: 'Cliente $clienteId',
  vendedorUid: 'u1',
  numeroNota: 1,
  data: _meioDaSemana,
  itens: [
    ItemVenda(
      id: 'i$id',
      produtoId: 'p1',
      nome: 'Cesta Básica',
      quantidade: 1,
      precoUnitario: preco,
      custoUnitario: preco / 2,
    ),
  ],
  valorTotal: preco,
  tipo: TipoVenda.aVista,
  updatedAt: _meioDaSemana,
);

RelatorioSemanal _relatorio({bool vazio = false}) => montarRelatorioSemanal(
  semana: _semana,
  vendas: vazio
      ? const []
      : [_venda('v1', 'c1', 1000), _venda('v2', 'c2', 250.5)],
  despesas: const [],
  grupos: const {'c1': GrupoLinha.toledo, 'c2': GrupoLinha.regional},
  pagamentos: const [],
);

class _CompartilhadorFalso implements CompartilhadorPdf {
  final nomes = <String>[];
  final tamanhos = <int>[];
  Object? falha;

  @override
  Future<void> compartilhar({
    required Uint8List bytes,
    required String nomeArquivo,
    String? mensagem,
  }) async {
    if (falha != null) throw falha!;
    nomes.add(nomeArquivo);
    tamanhos.add(bytes.length);
  }
}

Widget _app(Widget filho, {List<Override> overrides = const []}) =>
    ProviderScope(
      overrides: overrides,
      child: MaterialApp(home: filho),
    );

Widget _tela(
  AsyncValue<RelatorioSemanal> estado, {
  _CompartilhadorFalso? compartilhador,
}) => _app(
  const RelatorioSemanalScreen(),
  overrides: [
    relatorioSemanalProvider.overrideWith((ref) => estado),
    vendedorDoRelatorioProvider.overrideWith((ref) => 'Joana Silva'),
    if (compartilhador != null)
      compartilhadorPdfProvider.overrideWithValue(compartilhador),
  ],
);

void main() {
  setUpAll(() => initializeDateFormatting('pt_BR'));

  group('RelatorioTabela', () {
    Future<void> montar(
      WidgetTester tester,
      RelatorioSemanal r, {
      void Function(LinhaRelatorio)? aoAbrir,
    }) async {
      tester.view.physicalSize = const Size(1600, 1200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        _app(
          Scaffold(
            body: SingleChildScrollView(
              child: RelatorioTabela(
                relatorio: r,
                aoAbrirLinha: aoAbrir ?? (_) {},
              ),
            ),
          ),
        ),
      );
    }

    testWidgets('mostra as colunas, as linhas por faturamento e o TOTAL', (
      tester,
    ) async {
      await montar(tester, _relatorio());
      for (final coluna in [
        'Linha',
        'Vendas',
        'Faturamento',
        'Custo',
        'Lucro bruto',
        'Margem',
        'Ticket médio',
        'Recebido',
        'Particip.',
      ]) {
        expect(find.text(coluna), findsOneWidget, reason: coluna);
      }
      expect(find.text('Toledo'), findsOneWidget);
      expect(find.text('Regional'), findsOneWidget);
      expect(find.text('TOTAL'), findsOneWidget);
      // Toledo (R$ 1.000,00) vem antes de Regional (R$ 250,50).
      expect(
        tester.getTopLeft(find.text('Toledo')).dy,
        lessThan(tester.getTopLeft(find.text('Regional')).dy),
      );
      expect(
        tester.getTopLeft(find.text('Regional')).dy,
        lessThan(tester.getTopLeft(find.text('TOTAL')).dy),
      );
    });

    testWidgets('valores em reais, margem e participação', (tester) async {
      await montar(tester, _relatorio());
      // Toledo: faturamento, ticket médio e recebido (à vista) = R$ 1.000,00.
      expect(find.text('R\$ 1.000,00'), findsNWidgets(3));
      expect(find.text('R\$ 500,00'), findsNWidgets(2)); // custo e lucro
      expect(find.text('R\$ 250,50'), findsNWidgets(3)); // Regional
      expect(find.text('R\$ 125,25'), findsNWidgets(2)); // custo e lucro
      // Total: faturamento e recebido; custo, lucro e ticket médio.
      expect(find.text('R\$ 1.250,50'), findsNWidgets(2));
      expect(find.text('R\$ 625,25'), findsNWidgets(3));
      expect(find.text('50,0%'), findsWidgets); // margem
      expect(find.text('80,0%'), findsOneWidget); // participação Toledo
      expect(find.text('20,0%'), findsOneWidget); // participação Regional
      expect(find.text('100,0%'), findsOneWidget); // total
    });

    testWidgets('sem semana anterior, a variação mostra —', (tester) async {
      await montar(tester, _relatorio());
      // Duas linhas e o total, cada um com duas variações.
      expect(find.text('—'), findsNWidgets(6));
    });

    testWidgets('semana sem movimento: tabela zerada, sem NaN', (tester) async {
      await montar(tester, _relatorio(vazio: true));
      expect(find.text('Toledo'), findsOneWidget);
      expect(find.text('R\$ 0,00'), findsWidgets);
      expect(find.textContaining('NaN'), findsNothing);
      expect(find.text('0,0%'), findsWidgets);
    });

    testWidgets('tocar numa linha abre o detalhe dela; o total não', (
      tester,
    ) async {
      final abertas = <GrupoLinha>[];
      await montar(tester, _relatorio(), aoAbrir: (l) => abertas.add(l.grupo));
      await tester.tap(find.text('TOTAL'));
      expect(abertas, isEmpty);
      await tester.tap(find.text('Regional'));
      expect(abertas, [GrupoLinha.regional]);
    });
  });

  group('SeletorSemana', () {
    Future<ProviderContainer> montar(WidgetTester tester) async {
      await tester.pumpWidget(_app(const Scaffold(body: SeletorSemana())));
      return ProviderScope.containerOf(
        tester.element(find.byType(SeletorSemana)),
      );
    }

    testWidgets('começa em "Esta semana", com próxima desabilitada', (
      tester,
    ) async {
      await montar(tester);
      expect(find.text('Esta semana'), findsNWidgets(2)); // legenda e botão
      expect(
        tester
            .widget<IconButton>(
              find.widgetWithIcon(IconButton, Icons.chevron_right),
            )
            .onPressed,
        isNull,
      );
      expect(
        tester
            .widget<TextButton>(find.widgetWithText(TextButton, 'Esta semana'))
            .onPressed,
        isNull,
      );
    });

    testWidgets('anterior, próxima e Esta semana navegam', (tester) async {
      final c = await montar(tester);
      final corrente = c.read(semanaRelatorioProvider);

      await tester.tap(find.byTooltip('Semana anterior'));
      await tester.pump();
      expect(c.read(semanaRelatorioProvider), semanaAnteriorA(corrente));
      expect(find.text('Segunda a domingo'), findsOneWidget);

      await tester.tap(find.byTooltip('Próxima semana'));
      await tester.pump();
      expect(c.read(semanaRelatorioProvider), corrente);

      await tester.tap(find.byTooltip('Semana anterior'));
      await tester.tap(find.byTooltip('Semana anterior'));
      await tester.pump();
      await tester.tap(find.widgetWithText(TextButton, 'Esta semana'));
      await tester.pump();
      expect(c.read(semanaRelatorioProvider), corrente);
    });

    testWidgets('mostra o intervalo de segunda a domingo', (tester) async {
      await montar(tester);
      final s = _semana;
      String d(DateTime x) =>
          '${x.day.toString().padLeft(2, '0')}/${x.month.toString().padLeft(2, '0')}/${x.year}';
      expect(find.text('${d(s.inicio)} a ${d(s.ultimoDia)}'), findsOneWidget);
    });

    testWidgets('o calendário abre e escolhe a semana da data', (tester) async {
      final c = await montar(tester);
      await tester.tap(find.byTooltip('Escolher a semana de uma data'));
      await tester.pumpAndSettle();
      expect(find.text('Escolha um dia da semana'), findsOneWidget);

      // Escolhe o dia 1 do mês corrente (nunca é futuro).
      final hoje = DateTime.now();
      await tester.tap(find.text('1').first);
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      final escolhida = c.read(semanaRelatorioProvider);
      expect(escolhida.contem(DateTime(hoje.year, hoje.month, 1)), isTrue);
      expect(escolhida.inicio.weekday, DateTime.monday);
    });
  });

  group('RelatorioSemanalScreen', () {
    testWidgets('carregando mostra o indicador, sem tabela', (tester) async {
      await tester.pumpWidget(_tela(const AsyncLoading()));
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.byType(RelatorioTabela), findsNothing);
    });

    testWidgets('erro mostra a mensagem, sem spinner', (tester) async {
      await tester.pumpWidget(
        _tela(AsyncError(StateError('x'), StackTrace.empty)),
      );
      expect(find.text('Erro ao carregar o relatório'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });

    testWidgets('dados: vendedor, tabela, despesas gerais e lucro líquido', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1200, 3000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(_tela(AsyncData(_relatorio())));
      expect(find.text('Vendedor: Joana Silva'), findsOneWidget);
      expect(find.byType(RelatorioTabela), findsOneWidget);
      expect(find.text('DESPESAS GERAIS'), findsOneWidget);
      expect(find.text('Não atribuídas a linha'), findsOneWidget);
      expect(find.text('LUCRO LÍQUIDO'), findsOneWidget);
      expect(find.textContaining('rota atual do cliente'), findsOneWidget);
      expect(find.text('Compartilhar PDF'), findsOneWidget);
    });

    testWidgets('semana vazia avisa e mostra a tabela zerada', (tester) async {
      tester.view.physicalSize = const Size(1200, 3000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(_tela(AsyncData(_relatorio(vazio: true))));
      expect(
        find.textContaining('Sem vendas, recebimentos nem despesas'),
        findsOneWidget,
      );
      expect(find.byType(RelatorioTabela), findsOneWidget);
    });

    testWidgets('botão de PDF desabilitado enquanto carrega', (tester) async {
      await tester.pumpWidget(_tela(const AsyncLoading()));
      final botao = tester.widget<ElevatedButton>(
        find.widgetWithText(ElevatedButton, 'Compartilhar PDF'),
      );
      expect(botao.onPressed, isNull);
    });

    testWidgets('Compartilhar PDF gera o arquivo e chama o compartilhador', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1200, 3000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final comp = _CompartilhadorFalso();
      await tester.pumpWidget(
        _tela(AsyncData(_relatorio()), compartilhador: comp),
      );

      await tester.runAsync(() async {
        await tester.tap(find.text('Compartilhar PDF'));
        await Future<void>.delayed(const Duration(milliseconds: 500));
      });
      await tester.pump();

      expect(comp.nomes, hasLength(1));
      expect(
        comp.nomes.single,
        matches(RegExp(r'^relatorio-semanal-\d{8}-\d{8}\.pdf$')),
      );
      expect(comp.tamanhos.single, greaterThan(1000));
    });

    testWidgets('falha ao compartilhar mostra aviso e libera o botão', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1200, 3000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final comp = _CompartilhadorFalso()..falha = StateError('sem app');
      await tester.pumpWidget(
        _tela(AsyncData(_relatorio()), compartilhador: comp),
      );

      await tester.runAsync(() async {
        await tester.tap(find.text('Compartilhar PDF'));
        await Future<void>.delayed(const Duration(milliseconds: 500));
      });
      await tester.pump();

      expect(
        find.text('Não foi possível gerar o PDF do relatório.'),
        findsOneWidget,
      );
      final botao = tester.widget<ElevatedButton>(
        find.widgetWithText(ElevatedButton, 'Compartilhar PDF'),
      );
      expect(botao.onPressed, isNotNull);
    });

    testWidgets(
      'detalhe da linha: vendas por dia, produtos e clientes, sem CPF',
      (tester) async {
        tester.view.physicalSize = const Size(1600, 3000);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        await tester.pumpWidget(_tela(AsyncData(_relatorio())));

        await tester.tap(
          find.descendant(
            of: find.byType(DataTable),
            matching: find.text('Toledo'),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Vendas por dia'), findsOneWidget);
        expect(find.text('Mais vendidos'), findsWidgets);
        expect(find.text('Clientes que mais compraram'), findsOneWidget);
        expect(find.text('Cliente c1'), findsOneWidget);
        expect(find.text('Cesta Básica'), findsOneWidget);
        expect(find.text('Cliente c2'), findsNothing); // é da Regional
        expect(find.textContaining('123.456'), findsNothing);
        expect(find.textContaining('CPF'), findsNothing);
      },
    );
  });
}
