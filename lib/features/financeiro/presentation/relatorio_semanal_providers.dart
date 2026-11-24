import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/firebase_providers.dart';
import '../../rota/presentation/rota_providers.dart';
import '../domain/periodo.dart';
import '../domain/relatorio_linha.dart';
import '../domain/semana.dart';
import 'painel_providers.dart';

/// Semana exibida no relatório por linha de atendimento (KAN-53), de
/// segunda a domingo. Começa na semana corrente e nunca passa dela.
final semanaRelatorioProvider =
    NotifierProvider<SemanaRelatorioNotifier, Periodo>(
      SemanaRelatorioNotifier.new,
    );

class SemanaRelatorioNotifier extends Notifier<Periodo> {
  @override
  Periodo build() => Periodo.semana(DateTime.now());

  void anterior() => state = semanaAnteriorA(state);

  /// Vai para a semana seguinte; não faz nada na semana corrente.
  void proxima() {
    final seguinte = semanaSeguinteA(state, DateTime.now());
    if (seguinte != null) state = seguinte;
  }

  void estaSemana() => state = Periodo.semana(DateTime.now());

  /// Semana que contém [data]. Data futura vira a semana corrente.
  void escolherData(DateTime data) =>
      state = semanaDaData(data, DateTime.now());
}

/// Quem está logado, para o "Vendedor:" do relatório e do PDF: o nome,
/// ou o e-mail se não houver nome. Os números do relatório são só desse
/// vendedor (mesmo critério do painel da KAN-52).
final vendedorDoRelatorioProvider = Provider<String>((ref) {
  final usuario = ref.watch(usuarioLogadoProvider).value;
  final nome = usuario?.displayName?.trim();
  if (nome != null && nome.isNotEmpty) return nome;
  return usuario?.email ?? '—';
});

/// Relatório da semana selecionada.
///
/// Não abre leitura nova: usa os mesmos streams de vendas e despesas do
/// painel (a semana e a anterior numa leitura só, com a mesma chave do
/// painel quando ele mostra a mesma semana), as promissórias já
/// reaproveitadas pelo painel, e as rotas e os clientes da agenda (um
/// stream cada, nunca um por cliente ou por venda).
///
/// Carrega enquanto vendas, despesas, rotas ou clientes carregam; erro se
/// um deles falhar (sem rotas e clientes toda venda cairia em "sem
/// linha", o que enganaria). As promissórias não bloqueiam: sem elas, o
/// "recebido" fica em "—".
final relatorioSemanalProvider =
    Provider.autoDispose<AsyncValue<RelatorioSemanal>>((ref) {
      final semana = ref.watch(semanaRelatorioProvider);
      final intervalo = (de: semana.anterior.inicio, ate: semana.fim);
      final vendas = ref.watch(vendasDoIntervaloProvider(intervalo));
      final despesas = ref.watch(despesasDoIntervaloProvider(intervalo));
      final rotas = ref.watch(rotasAtivasProvider);
      final clientes = ref.watch(clientesDasRotasProvider);
      final recebiveis = ref.watch(posicaoRecebiveisProvider);

      for (final fonte in [vendas, despesas, rotas, clientes]) {
        if (fonte.hasError) {
          return AsyncError(fonte.error!, fonte.stackTrace ?? StackTrace.empty);
        }
      }
      final listaVendas = vendas.value;
      final listaDespesas = despesas.value;
      final listaRotas = rotas.value;
      final listaClientes = clientes.value;
      if (listaVendas == null ||
          listaDespesas == null ||
          listaRotas == null ||
          listaClientes == null) {
        return const AsyncLoading();
      }
      return AsyncData(
        montarRelatorioSemanal(
          semana: semana,
          vendas: listaVendas,
          despesas: listaDespesas,
          grupos: grupoDosClientes(listaClientes, listaRotas),
          pagamentos: recebiveis.value?.pagamentosDosClientes,
        ),
      );
    });
