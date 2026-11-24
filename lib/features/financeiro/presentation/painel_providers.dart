import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/firebase_providers.dart';
import '../../../core/utils/stream_com_cache.dart';
import '../../venda/data/parcela_model.dart';
import '../../venda/data/venda_model.dart';
import '../../venda/data/venda_repository.dart';
import '../../venda/domain/controle_promissorias.dart';
import '../../venda/presentation/promissorias_providers.dart';
import '../data/despesa_model.dart';
import '../data/despesa_repository.dart';
import '../domain/agregacao_financeira.dart';
import '../domain/periodo.dart';
import '../domain/relatorio_linha.dart';
import 'periodo_financeiro_provider.dart';

/// Intervalo de leitura do painel: o período e o anterior, de uma vez,
/// para a comparação não abrir um segundo stream.
typedef IntervaloLeitura = ({DateTime de, DateTime ate});

IntervaloLeitura _intervalo(Periodo p) => (de: p.anterior.inicio, ate: p.fim);

/// Vendas do vendedor logado no intervalo (KAN-52): um único stream.
/// Se o servidor não responde a tempo, cai no cache local (RNF06). Sem
/// retentativa automática, para o erro não ficar atrás de um spinner.
final vendasDoIntervaloProvider = StreamProvider.autoDispose
    .family<List<VendaModel>, IntervaloLeitura>((ref, intervalo) {
      final uid = ref.watch(usuarioLogadoProvider).value?.uid;
      if (uid == null) return Stream.value(const <VendaModel>[]);
      final repositorio = ref.watch(vendaRepositoryProvider);
      return comFallbackDeCache<VendaModel>(
        repositorio.observarPorPeriodo(intervalo.de, intervalo.ate),
        () => repositorio.periodoEmCache(intervalo.de, intervalo.ate),
      ).map((vendas) => vendas.where((v) => v.vendedorUid == uid).toList());
    }, retry: (_, _) => null);

/// Despesas do vendedor logado no intervalo (KAN-52): um único stream.
final despesasDoIntervaloProvider = StreamProvider.autoDispose
    .family<List<DespesaModel>, IntervaloLeitura>((ref, intervalo) {
      final uid = ref.watch(usuarioLogadoProvider).value?.uid;
      if (uid == null) return Stream.value(const <DespesaModel>[]);
      final repositorio = ref.watch(despesaRepositoryProvider);
      return comFallbackDeCache<DespesaModel>(
        repositorio.observarDoVendedor(
          uid,
          de: intervalo.de,
          ate: intervalo.ate,
        ),
        () => repositorio.doVendedorEmCache(
          uid,
          de: intervalo.de,
          ate: intervalo.ate,
        ),
      );
    }, retry: (_, _) => null);

/// Posição das promissórias do vendedor hoje (KAN-34): o que falta
/// receber e o que já venceu, mais os pagamentos recebidos, para o
/// "Recebido no período". Reaproveita [promissoriasProvider], sem leitura
/// nova. É `null` enquanto carrega ou se falhar: o painel mostra "—".
class PosicaoRecebiveis {
  const PosicaoRecebiveis({
    required this.aReceber,
    required this.emAtraso,
    required this.pagamentos,
    this.pagamentosDosClientes = const [],
  });

  /// Em centavos.
  final int aReceber;
  final int emAtraso;
  final List<PagamentoModel> pagamentos;

  /// Os mesmos pagamentos com o cliente da venda, para o relatório por
  /// linha de atendimento (KAN-53) atribuir cada um à linha do cliente.
  final List<PagamentoDeCliente> pagamentosDosClientes;
}

final posicaoRecebiveisProvider =
    Provider.autoDispose<AsyncValue<PosicaoRecebiveis>>((ref) {
      final uid = ref.watch(usuarioLogadoProvider).value?.uid;
      final itens = ref.watch(promissoriasProvider(null));
      final lista = itens.value;
      if (lista == null) {
        return itens.hasError
            ? AsyncError(itens.error!, itens.stackTrace ?? StackTrace.empty)
            : const AsyncLoading();
      }
      final doVendedor = lista.where((i) => i.venda.vendedorUid == uid);
      final resumo = resumirPromissorias(doVendedor);
      return AsyncData(
        PosicaoRecebiveis(
          aReceber: emCentavos(resumo.totalEmAberto),
          emAtraso: emCentavos(resumo.totalEmAtraso),
          pagamentos: [
            for (final i in doVendedor)
              for (final p in i.promissoria.parcelas.where((p) => !p.deleted))
                ...p.pagamentos,
          ],
          pagamentosDosClientes: [
            for (final i in doVendedor)
              for (final p in i.promissoria.parcelas.where((p) => !p.deleted))
                for (final pg in p.pagamentos)
                  PagamentoDeCliente(
                    clienteId: i.venda.clienteId,
                    pagamento: pg,
                  ),
          ],
        ),
      );
    });

/// Painel do período selecionado. Carrega enquanto vendas ou despesas
/// carregam; erro se uma das duas falhar. As promissórias não bloqueiam:
/// sem elas, "Recebido" e "A receber" ficam em "—".
final painelFinanceiroProvider =
    Provider.autoDispose<AsyncValue<PainelFinanceiro>>((ref) {
      final periodo = ref.watch(periodoFinanceiroProvider);
      final intervalo = _intervalo(periodo);
      final vendas = ref.watch(vendasDoIntervaloProvider(intervalo));
      final despesas = ref.watch(despesasDoIntervaloProvider(intervalo));
      final recebiveis = ref.watch(posicaoRecebiveisProvider);

      if (vendas.hasError) {
        return AsyncError(vendas.error!, vendas.stackTrace ?? StackTrace.empty);
      }
      if (despesas.hasError) {
        return AsyncError(
          despesas.error!,
          despesas.stackTrace ?? StackTrace.empty,
        );
      }
      final listaVendas = vendas.value;
      final listaDespesas = despesas.value;
      if (listaVendas == null || listaDespesas == null) {
        return const AsyncLoading();
      }
      return AsyncData(
        montarPainel(
          periodo: periodo,
          vendas: listaVendas,
          despesas: listaDespesas,
          pagamentos: recebiveis.value?.pagamentos,
        ),
      );
    });
