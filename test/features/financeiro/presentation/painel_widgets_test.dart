import 'package:cesta_basica_lopez_mobile/core/theme/app_colors.dart';
import 'package:cesta_basica_lopez_mobile/features/financeiro/domain/agregacao_financeira.dart';
import 'package:cesta_basica_lopez_mobile/features/financeiro/domain/periodo.dart';
import 'package:cesta_basica_lopez_mobile/features/financeiro/presentation/painel_financeiro_screen.dart';
import 'package:cesta_basica_lopez_mobile/features/financeiro/presentation/painel_indicadores.dart';
import 'package:cesta_basica_lopez_mobile/features/financeiro/presentation/painel_providers.dart';
import 'package:cesta_basica_lopez_mobile/features/financeiro/presentation/periodo_financeiro_provider.dart';
import 'package:cesta_basica_lopez_mobile/features/financeiro/presentation/seletor_periodo.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

PainelFinanceiro _painel({
  TotaisFinanceiros atual = const TotaisFinanceiros(
    faturamento: 123456,
    custo: 60000,
    despesas: 10000,
    recebido: 5000,
    vendas: 4,
    unidades: 9,
  ),
  TotaisFinanceiros anterior = const TotaisFinanceiros(
    faturamento: 100000,
    despesas: 20000,
    vendas: 2,
  ),
}) {
  final periodo = Periodo.semana(DateTime(2026, 11, 18));
  return PainelFinanceiro(
    periodo: periodo,
    comparacao: ComparacaoPeriodo(atual: atual, anterior: anterior),
    serie: [for (final d in periodo.diasDoPeriodo) PontoDia(d, atual)],
    topProdutos: const [],
    recebidoCompleto: true,
  );
}

Widget _app(Widget filho, {List<Override> overrides = const []}) =>
    ProviderScope(
      overrides: overrides,
      child: MaterialApp(home: Scaffold(body: filho)),
    );

void main() {
  setUpAll(() => initializeDateFormatting('pt_BR'));

  group('cartões', () {
    testWidgets('mostra os dez indicadores com os valores', (tester) async {
      await tester.pumpWidget(
        _app(
          SingleChildScrollView(
            child: PainelIndicadores(
              painel: _painel(),
              recebiveis: const PosicaoRecebiveis(
                aReceber: 80000,
                emAtraso: 25050,
                pagamentos: [],
              ),
            ),
          ),
        ),
      );

      for (final rotulo in [
        'FATURAMENTO',
        'CUSTO DOS PRODUTOS',
        'LUCRO BRUTO',
        'DESPESAS',
        'LUCRO LÍQUIDO',
        'VENDAS',
        'TICKET MÉDIO',
        'RECEBIDO NO PERÍODO',
        'A RECEBER',
        'EM ATRASO',
      ]) {
        expect(find.text(rotulo), findsOneWidget, reason: rotulo);
      }
      expect(find.text('R\$ 1.234,56'), findsOneWidget); // faturamento
      expect(find.text('R\$ 600,00'), findsOneWidget); // custo
      expect(find.text('R\$ 634,56'), findsOneWidget); // lucro bruto
      expect(find.text('R\$ 534,56'), findsOneWidget); // lucro líquido
      expect(find.text('R\$ 308,64'), findsOneWidget); // ticket médio
      expect(find.text('R\$ 800,00'), findsOneWidget); // a receber
      expect(find.text('R\$ 250,50'), findsOneWidget); // em atraso
    });

    testWidgets('promissórias ainda sem dados mostram —', (tester) async {
      await tester.pumpWidget(
        _app(
          SingleChildScrollView(
            child: PainelIndicadores(painel: _painel(), recebiveis: null),
          ),
        ),
      );
      // A receber e Em atraso.
      expect(find.text('—'), findsNWidgets(2));
    });

    testWidgets('lucro líquido negativo usa sinal de menos', (tester) async {
      await tester.pumpWidget(
        _app(
          SingleChildScrollView(
            child: PainelIndicadores(
              painel: _painel(atual: const TotaisFinanceiros(despesas: 5000)),
              recebiveis: null,
            ),
          ),
        ),
      );
      expect(find.text('−R\$ 50,00'), findsWidgets);
    });
  });

  group('variação', () {
    Future<void> montar(WidgetTester tester, double? v, {bool ruim = false}) =>
        tester.pumpWidget(
          _app(VariacaoPercentual(variacao: v, altaEhRuim: ruim)),
        );

    testWidgets('sem base mostra —', (tester) async {
      await montar(tester, null);
      expect(find.textContaining('—'), findsOneWidget);
    });

    testWidgets('alta de faturamento: seta para cima verde', (tester) async {
      await montar(tester, 23.456);
      expect(find.text('+23,5%'), findsOneWidget);
      final icone = tester.widget<Icon>(find.byIcon(Icons.arrow_upward));
      expect(icone.color, AppColors.scoreA);
    });

    testWidgets('queda de faturamento: seta para baixo vermelha', (
      tester,
    ) async {
      await montar(tester, -10);
      expect(find.text('-10,0%'), findsOneWidget);
      final icone = tester.widget<Icon>(find.byIcon(Icons.arrow_downward));
      expect(icone.color, AppColors.statusInadimplente);
    });

    testWidgets('alta de despesas é ruim: seta para cima vermelha', (
      tester,
    ) async {
      await montar(tester, 40, ruim: true);
      final icone = tester.widget<Icon>(find.byIcon(Icons.arrow_upward));
      expect(icone.color, AppColors.statusInadimplente);
    });

    testWidgets('sem mudança fica neutro', (tester) async {
      await montar(tester, 0);
      expect(find.byIcon(Icons.remove), findsOneWidget);
    });
  });

  group('seletor de período', () {
    testWidgets('mostra as quatro opções e o intervalo', (tester) async {
      await tester.pumpWidget(_app(const SeletorPeriodo()));
      for (final t in ['Hoje', 'Semana', 'Mês', 'Personalizado']) {
        expect(find.text(t), findsOneWidget);
      }
      expect(find.textContaining(' a '), findsOneWidget);
    });

    testWidgets('tocar em Hoje e em Mês troca o período', (tester) async {
      await tester.pumpWidget(_app(const SeletorPeriodo()));
      final container = ProviderScope.containerOf(
        tester.element(find.byType(SeletorPeriodo)),
      );

      await tester.tap(find.text('Hoje'));
      await tester.pump();
      expect(container.read(periodoFinanceiroProvider).tipo, TipoPeriodo.hoje);
      expect(container.read(periodoFinanceiroProvider).dias, 1);

      await tester.tap(find.text('Mês'));
      await tester.pump();
      expect(container.read(periodoFinanceiroProvider).tipo, TipoPeriodo.mes);
    });

    testWidgets('Personalizado abre o seletor de intervalo', (tester) async {
      await tester.pumpWidget(_app(const SeletorPeriodo()));
      await tester.tap(find.text('Personalizado'));
      await tester.pumpAndSettle();
      expect(find.text('Escolha o período'), findsOneWidget);
    });
  });

  group('tela', () {
    Widget tela(AsyncValue<PainelFinanceiro> estado) => _app(
      const PainelFinanceiroScreen(),
      overrides: [painelFinanceiroProvider.overrideWith((ref) => estado)],
    );

    testWidgets('carregando mostra o indicador de progresso', (tester) async {
      await tester.pumpWidget(tela(const AsyncLoading()));
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('erro mostra a mensagem, sem spinner', (tester) async {
      await tester.pumpWidget(
        tela(AsyncError(StateError('x'), StackTrace.empty)),
      );
      expect(find.text('Erro ao carregar o painel'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });

    testWidgets('período sem movimento avisa e zera os indicadores', (
      tester,
    ) async {
      await tester.pumpWidget(
        tela(
          AsyncData(
            _painel(
              atual: TotaisFinanceiros.zero,
              anterior: TotaisFinanceiros.zero,
            ),
          ),
        ),
      );
      expect(find.textContaining('Sem vendas nem despesas'), findsOneWidget);
      expect(find.text('R\$ 0,00'), findsWidgets);
    });
  });
}
