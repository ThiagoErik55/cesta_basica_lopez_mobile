import 'dart:async';

import 'package:cesta_basica_lopez_mobile/core/domain/enums.dart';
import 'package:cesta_basica_lopez_mobile/features/financeiro/data/despesa_model.dart';
import 'package:cesta_basica_lopez_mobile/features/financeiro/domain/periodo.dart';
import 'package:cesta_basica_lopez_mobile/features/financeiro/presentation/painel_providers.dart';
import 'package:cesta_basica_lopez_mobile/features/financeiro/presentation/periodo_financeiro_provider.dart';
import 'package:cesta_basica_lopez_mobile/features/venda/data/venda_model.dart';
import 'package:cesta_basica_lopez_mobile/features/venda/domain/controle_promissorias.dart';
import 'package:cesta_basica_lopez_mobile/features/venda/presentation/promissorias_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

VendaModel _venda(DateTime data) => VendaModel(
  id: 'v${data.millisecondsSinceEpoch}',
  clienteId: 'c1',
  clienteNome: 'Maria',
  vendedorUid: 'u1',
  numeroNota: 1,
  data: data,
  itens: [
    const ItemVenda(
      id: 'i1',
      produtoId: 'p1',
      nome: 'Cesta',
      quantidade: 1,
      precoUnitario: 100,
      custoUnitario: 60,
    ),
  ],
  valorTotal: 100,
  tipo: TipoVenda.aVista,
  updatedAt: data,
);

DespesaModel _despesa(DateTime data, double valor) => DespesaModel(
  id: 'd${data.millisecondsSinceEpoch}',
  vendedorUid: 'u1',
  descricao: 'Combustível',
  valor: valor,
  data: data,
  updatedAt: data,
);

/// Streams controláveis por intervalo, para ver o que o painel abre.
class _Fontes {
  final intervalosVendas = <IntervaloLeitura>[];
  final intervalosDespesas = <IntervaloLeitura>[];
  final vendas = StreamController<List<VendaModel>>.broadcast();
  final despesas = StreamController<List<DespesaModel>>.broadcast();

  ProviderContainer container({
    AsyncValue<List<ItemPromissoria>> promissorias = const AsyncData([]),
  }) {
    final c = ProviderContainer(
      overrides: [
        vendasDoIntervaloProvider.overrideWith((ref, i) {
          intervalosVendas.add(i);
          return vendas.stream;
        }),
        despesasDoIntervaloProvider.overrideWith((ref, i) {
          intervalosDespesas.add(i);
          return despesas.stream;
        }),
        promissoriasProvider.overrideWith((ref, _) => promissorias),
      ],
    );
    addTearDown(() {
      c.dispose();
      vendas.close();
      despesas.close();
    });
    return c;
  }
}

Future<void> _soltar() async {
  for (var i = 0; i < 5; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

void main() {
  test('sem emissão dos streams o painel segue carregando', () async {
    final f = _Fontes();
    final c = f.container();
    final sub = c.listen(painelFinanceiroProvider, (_, _) {});
    await _soltar();
    expect(sub.read().isLoading, isTrue);
  });

  test('só vendas emitiram: ainda carregando', () async {
    final f = _Fontes();
    final c = f.container();
    final sub = c.listen(painelFinanceiroProvider, (_, _) {});
    await _soltar();
    f.vendas.add([]);
    await _soltar();
    expect(sub.read().isLoading, isTrue);
  });

  test('erro no stream de vendas vira erro do painel', () async {
    final f = _Fontes();
    final c = f.container();
    final sub = c.listen(painelFinanceiroProvider, (_, _) {});
    await _soltar();
    f.despesas.add([]);
    f.vendas.addError(StateError('falhou'));
    await _soltar();
    expect(sub.read().hasError, isTrue);
  });

  test('erro no stream de despesas vira erro do painel', () async {
    final f = _Fontes();
    final c = f.container();
    final sub = c.listen(painelFinanceiroProvider, (_, _) {});
    await _soltar();
    f.vendas.add([]);
    f.despesas.addError(StateError('falhou'));
    await _soltar();
    expect(sub.read().hasError, isTrue);
  });

  test('com vendas e despesas monta o painel do período', () async {
    final f = _Fontes();
    final c = f.container();
    final sub = c.listen(painelFinanceiroProvider, (_, _) {});
    final hoje = DateTime.now();
    await _soltar();
    f.vendas.add([_venda(hoje)]);
    f.despesas.add([_despesa(hoje, 10)]);
    await _soltar();
    final painel = sub.read().requireValue;
    expect(painel.totais.faturamento, 10000);
    expect(painel.totais.lucroLiquido, 3000);
    expect(painel.recebidoCompleto, isTrue);
  });

  test('promissórias com erro não derrubam o painel', () async {
    final f = _Fontes();
    final c = f.container(
      promissorias: AsyncError(StateError('x'), StackTrace.empty),
    );
    final sub = c.listen(painelFinanceiroProvider, (_, _) {});
    await _soltar();
    f.vendas.add([]);
    f.despesas.add([]);
    await _soltar();
    final painel = sub.read().requireValue;
    expect(painel.recebidoCompleto, isFalse);
    expect(c.read(posicaoRecebiveisProvider).hasError, isTrue);
  });

  test('um listener de vendas e um de despesas por período', () async {
    final f = _Fontes();
    final c = f.container();
    c.listen(painelFinanceiroProvider, (_, _) {});
    await _soltar();
    expect(f.intervalosVendas.length, 1);
    expect(f.intervalosDespesas.length, 1);
  });

  test('trocar o período reabre os streams com o novo intervalo', () async {
    final f = _Fontes();
    final c = f.container();
    c.listen(painelFinanceiroProvider, (_, _) {});
    await _soltar();

    c.read(periodoFinanceiroProvider.notifier).selecionar(TipoPeriodo.mes);
    await _soltar();

    final mes = Periodo.mes(DateTime.now());
    expect(c.read(periodoFinanceiroProvider).tipo, TipoPeriodo.mes);
    expect(f.intervalosVendas.last, (de: mes.anterior.inicio, ate: mes.fim));
    expect(f.intervalosDespesas.last, (de: mes.anterior.inicio, ate: mes.fim));
  });

  test('o período personalizado fica limitado e guarda as datas', () {
    final f = _Fontes();
    final c = f.container();
    c
        .read(periodoFinanceiroProvider.notifier)
        .personalizar(DateTime(2026, 1, 1), DateTime(2026, 11, 1));
    final p = c.read(periodoFinanceiroProvider);
    expect(p.tipo, TipoPeriodo.personalizado);
    expect(p.dias, maximoDiasPersonalizado);
  });
}
