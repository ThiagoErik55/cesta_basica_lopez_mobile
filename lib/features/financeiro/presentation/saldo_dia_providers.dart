import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/firebase_providers.dart';
import '../../../core/utils/stream_com_cache.dart';
import '../../venda/data/venda_model.dart';
import '../../venda/data/venda_repository.dart';
import '../domain/dia.dart';
import '../domain/resumo_dia.dart';
import 'despesa_providers.dart';
import 'dia_financeiro_provider.dart';

/// Vendas do vendedor logado no dia selecionado (KAN-51). O filtro por
/// vendedor é feito em memória sobre as vendas do dia.
final vendasDoDiaProvider = StreamProvider.autoDispose<List<VendaModel>>((
  ref,
) {
  final uid = ref.watch(usuarioLogadoProvider).value?.uid;
  if (uid == null) return Stream.value(const <VendaModel>[]);
  final dia = ref.watch(diaFinanceiroProvider);
  final de = inicioDoDia(dia);
  final ate = inicioDoDiaSeguinte(dia);
  final repositorio = ref.watch(vendaRepositoryProvider);
  // Se o servidor não responde a tempo, cai no cache local (RNF06).
  return comFallbackDeCache<VendaModel>(
    repositorio.observarPorPeriodo(de, ate),
    () => repositorio.periodoEmCache(de, ate),
  ).map((vendas) => vendas.where((v) => v.vendedorUid == uid).toList());
}, retry: (_, _) => null);

/// Resumo do dia selecionado (KAN-51): vendas, lucro, despesas e saldo.
/// Carrega enquanto vendas ou despesas carregam; erro se uma das duas
/// falhar.
final resumoDoDiaProvider = Provider.autoDispose<AsyncValue<ResumoDia>>((ref) {
  final vendas = ref.watch(vendasDoDiaProvider);
  final despesas = ref.watch(despesasDoDiaProvider);

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
    ResumoDia.calcular(vendas: listaVendas, despesas: listaDespesas),
  );
});