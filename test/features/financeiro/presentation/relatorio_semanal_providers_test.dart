import 'dart:async';

import 'package:cesta_basica_lopez_mobile/core/domain/enums.dart';
import 'package:cesta_basica_lopez_mobile/core/providers/firebase_providers.dart';
import 'package:cesta_basica_lopez_mobile/features/cliente/data/cliente_model.dart';
import 'package:cesta_basica_lopez_mobile/features/financeiro/data/despesa_model.dart';
import 'package:cesta_basica_lopez_mobile/features/financeiro/domain/periodo.dart';
import 'package:cesta_basica_lopez_mobile/features/financeiro/domain/relatorio_linha.dart';
import 'package:cesta_basica_lopez_mobile/features/financeiro/presentation/painel_providers.dart';
import 'package:cesta_basica_lopez_mobile/features/financeiro/presentation/relatorio_semanal_providers.dart';
import 'package:cesta_basica_lopez_mobile/features/rota/data/rota_model.dart';
import 'package:cesta_basica_lopez_mobile/features/rota/presentation/rota_providers.dart';
import 'package:cesta_basica_lopez_mobile/features/venda/data/venda_model.dart';
import 'package:cesta_basica_lopez_mobile/features/venda/domain/controle_promissorias.dart';
import 'package:cesta_basica_lopez_mobile/features/venda/presentation/promissorias_providers.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _Usuario extends Fake implements User {
  _Usuario({this.displayName, this.email});

  @override
  final String? displayName;

  @override
  final String? email;
}

VendaModel _venda(DateTime data, String clienteId, double preco) => VendaModel(
  id: 'v${data.millisecondsSinceEpoch}$clienteId',
  clienteId: clienteId,
  clienteNome: 'Cliente $clienteId',
  vendedorUid: 'u1',
  numeroNota: 1,
  data: data,
  itens: [
    ItemVenda(
      id: 'i1',
      produtoId: 'p1',
      nome: 'Cesta',
      quantidade: 1,
      precoUnitario: preco,
      custoUnitario: preco / 2,
    ),
  ],
  valorTotal: preco,
  tipo: TipoVenda.aVista,
  updatedAt: data,
);

RotaModel _rota(String id, LinhaAtendimento linha) => RotaModel(
  id: id,
  codigo: id,
  nome: id,
  linhaAtendimento: linha,
  updatedAt: DateTime(2026),
);

ClienteModel _cliente(String id, String? rotaId) => ClienteModel(
  id: id,
  codigo: id,
  nome: id,
  cpf: '12345678909',
  telefone: '',
  endereco: '',
  rotaId: rotaId,
  updatedAt: DateTime(2026),
);

/// Streams controláveis; guarda o intervalo de cada leitura de vendas e
/// despesas e conta quantos listeners cada fonte abriu.
class _Fontes {
  final intervalosVendas = <IntervaloLeitura>[];
  final intervalosDespesas = <IntervaloLeitura>[];
  var aberturasRotas = 0;
  var aberturasClientes = 0;
  final vendas = StreamController<List<VendaModel>>.broadcast();
  final despesas = StreamController<List<DespesaModel>>.broadcast();
  final rotas = StreamController<List<RotaModel>>.broadcast();
  final clientes = StreamController<List<ClienteModel>>.broadcast();

  ProviderContainer container({
    AsyncValue<List<ItemPromissoria>> promissorias = const AsyncData([]),
    User? usuario,
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
        rotasAtivasProvider.overrideWith((ref) {
          aberturasRotas++;
          return rotas.stream;
        }),
        clientesDasRotasProvider.overrideWith((ref) {
          aberturasClientes++;
          return clientes.stream;
        }),
        promissoriasProvider.overrideWith((ref, _) => promissorias),
        usuarioLogadoProvider.overrideWith((ref) => Stream.value(usuario)),
      ],
    );
    addTearDown(() {
      c.dispose();
      vendas.close();
      despesas.close();
      rotas.close();
      clientes.close();
    });
    return c;
  }

  void emitirTudo({List<VendaModel> v = const []}) {
    vendas.add(v);
    despesas.add(const []);
    rotas.add([_rota('rT', LinhaAtendimento.toledo)]);
    clientes.add([_cliente('c1', 'rT')]);
  }
}

Future<void> _soltar() async {
  for (var i = 0; i < 5; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

void main() {
  group('relatorioSemanalProvider', () {
    test('sem emissão de nenhum stream segue carregando', () async {
      final f = _Fontes();
      final c = f.container();
      final sub = c.listen(relatorioSemanalProvider, (_, _) {});
      await _soltar();
      expect(sub.read().isLoading, isTrue);
    });

    test('falta um dos quatro streams: ainda carregando', () async {
      for (var faltando = 0; faltando < 4; faltando++) {
        final f = _Fontes();
        final c = f.container();
        final sub = c.listen(relatorioSemanalProvider, (_, _) {});
        await _soltar();
        if (faltando != 0) f.vendas.add(const []);
        if (faltando != 1) f.despesas.add(const []);
        if (faltando != 2) f.rotas.add(const []);
        if (faltando != 3) f.clientes.add(const []);
        await _soltar();
        expect(sub.read().isLoading, isTrue, reason: 'faltando $faltando');
      }
    });

    test('erro em vendas, despesas, rotas ou clientes vira erro', () async {
      final erros = <void Function(_Fontes)>[
        (f) => f.vendas.addError(StateError('x')),
        (f) => f.despesas.addError(StateError('x')),
        (f) => f.rotas.addError(StateError('x')),
        (f) => f.clientes.addError(StateError('x')),
      ];
      for (final (i, provoca) in erros.indexed) {
        final f = _Fontes();
        final c = f.container();
        final sub = c.listen(relatorioSemanalProvider, (_, _) {});
        await _soltar();
        provoca(f);
        await _soltar();
        expect(sub.read().hasError, isTrue, reason: 'fonte $i');
      }
    });

    test('com todos os dados, monta o relatório da semana corrente', () async {
      final f = _Fontes();
      final c = f.container();
      final sub = c.listen(relatorioSemanalProvider, (_, _) {});
      await _soltar();
      final semana = c.read(semanaRelatorioProvider);
      f.emitirTudo(
        v: [_venda(semana.inicio.add(const Duration(hours: 10)), 'c1', 100)],
      );
      await _soltar();

      final r = sub.read().requireValue;
      expect(r.semana, semana);
      expect(
        r.linhas
            .firstWhere((l) => l.grupo == GrupoLinha.toledo)
            .totais
            .faturamento,
        10000,
      );
      expect(r.total.faturamento, 10000);
    });

    test('promissórias com erro não derrubam o relatório', () async {
      final f = _Fontes();
      final c = f.container(
        promissorias: AsyncError(StateError('x'), StackTrace.empty),
      );
      final sub = c.listen(relatorioSemanalProvider, (_, _) {});
      await _soltar();
      f.emitirTudo();
      await _soltar();
      final r = sub.read().requireValue;
      expect(r.recebidoCompleto, isFalse);
    });

    test('com promissórias carregadas, o recebido fica completo', () async {
      final f = _Fontes();
      final c = f.container();
      final sub = c.listen(relatorioSemanalProvider, (_, _) {});
      await _soltar();
      f.emitirTudo();
      await _soltar();
      expect(sub.read().requireValue.recebidoCompleto, isTrue);
    });
  });

  group('custo de leitura', () {
    test(
      'um stream de vendas, um de despesas, um de rotas e um de clientes',
      () async {
        final f = _Fontes();
        final c = f.container();
        c.listen(relatorioSemanalProvider, (_, _) {});
        await _soltar();
        f.emitirTudo();
        await _soltar();
        expect(f.intervalosVendas.length, 1);
        expect(f.intervalosDespesas.length, 1);
        expect(f.aberturasRotas, 1);
        expect(f.aberturasClientes, 1);
      },
    );

    test('lê a semana e a anterior numa leitura só', () async {
      final f = _Fontes();
      final c = f.container();
      c.listen(relatorioSemanalProvider, (_, _) {});
      await _soltar();
      final semana = c.read(semanaRelatorioProvider);
      expect(f.intervalosVendas.single, (
        de: semana.anterior.inicio,
        ate: semana.fim,
      ));
      expect(f.intervalosDespesas.single, f.intervalosVendas.single);
    });

    test('mesma chave do painel: o stream é compartilhado', () async {
      final f = _Fontes();
      final c = f.container();
      c.listen(relatorioSemanalProvider, (_, _) {});
      await _soltar();
      final semana = c.read(semanaRelatorioProvider);
      // O painel da mesma semana pede o mesmo intervalo.
      c.listen(
        vendasDoIntervaloProvider((
          de: semana.anterior.inicio,
          ate: semana.fim,
        )),
        (_, _) {},
      );
      await _soltar();
      expect(f.intervalosVendas.length, 1);
    });

    test(
      'trocar de semana abre uma leitura nova para o novo intervalo',
      () async {
        final f = _Fontes();
        final c = f.container();
        c.listen(relatorioSemanalProvider, (_, _) {});
        await _soltar();
        final antes = c.read(semanaRelatorioProvider);
        c.read(semanaRelatorioProvider.notifier).anterior();
        await _soltar();
        final depois = c.read(semanaRelatorioProvider);
        expect(depois.fim, antes.inicio);
        expect(f.intervalosVendas.length, 2);
        expect(f.intervalosVendas.last, (
          de: depois.anterior.inicio,
          ate: depois.fim,
        ));
      },
    );
  });

  group('semanaRelatorioProvider', () {
    test('começa na semana corrente, de segunda a domingo', () {
      final c = ProviderContainer();
      addTearDown(c.dispose);
      final s = c.read(semanaRelatorioProvider);
      expect(s.inicio.weekday, DateTime.monday);
      expect(s.contem(DateTime.now()), isTrue);
      expect(s.dias, 7);
    });

    test('anterior e próxima; próxima na corrente não faz nada', () {
      final c = ProviderContainer();
      addTearDown(c.dispose);
      final n = c.read(semanaRelatorioProvider.notifier);
      final corrente = c.read(semanaRelatorioProvider);
      n.proxima();
      expect(c.read(semanaRelatorioProvider), corrente);
      n.anterior();
      expect(c.read(semanaRelatorioProvider).fim, corrente.inicio);
      n.proxima();
      expect(c.read(semanaRelatorioProvider), corrente);
    });

    test('estaSemana volta para a corrente', () {
      final c = ProviderContainer();
      addTearDown(c.dispose);
      final n = c.read(semanaRelatorioProvider.notifier);
      final corrente = c.read(semanaRelatorioProvider);
      n.anterior();
      n.anterior();
      n.estaSemana();
      expect(c.read(semanaRelatorioProvider), corrente);
    });

    test('escolherData: data antiga vai para a semana dela', () {
      final c = ProviderContainer();
      addTearDown(c.dispose);
      c
          .read(semanaRelatorioProvider.notifier)
          .escolherData(DateTime(2026, 3, 4));
      final s = c.read(semanaRelatorioProvider);
      expect(s.inicio, DateTime(2026, 3, 2));
      expect(s, Periodo.semana(DateTime(2026, 3, 8)));
    });

    test('escolherData: data futura não passa da semana corrente', () {
      final c = ProviderContainer();
      addTearDown(c.dispose);
      final corrente = c.read(semanaRelatorioProvider);
      c
          .read(semanaRelatorioProvider.notifier)
          .escolherData(DateTime.now().add(const Duration(days: 40)));
      expect(c.read(semanaRelatorioProvider), corrente);
    });
  });

  group('vendedorDoRelatorioProvider', () {
    Future<String> vendedor(User? u) async {
      final f = _Fontes();
      final c = f.container(usuario: u);
      c.listen(usuarioLogadoProvider, (_, _) {});
      await _soltar();
      return c.read(vendedorDoRelatorioProvider);
    }

    test('usa o nome', () async {
      expect(
        await vendedor(_Usuario(displayName: ' Joana ', email: 'j@x.com')),
        'Joana',
      );
    });

    test('sem nome, usa o e-mail', () async {
      expect(await vendedor(_Usuario(email: 'j@x.com')), 'j@x.com');
      expect(
        await vendedor(_Usuario(displayName: '  ', email: 'j@x.com')),
        'j@x.com',
      );
    });

    test('sem usuário, mostra um traço', () async {
      expect(await vendedor(null), '—');
    });
  });
}
