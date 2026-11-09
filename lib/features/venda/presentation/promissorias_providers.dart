import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/controle_promissorias.dart';
import 'historico_financeiro_providers.dart';
import 'pos_venda_providers.dart';

/// Promissórias para a tela de controle (KAN-34), em tempo real: todas as
/// vendas parceladas, ou só as de [clienteId] quando informado.
///
/// É uma visão derivada de vendas e parcelas, sem coleção própria. Vem de
/// listeners do Firestore, então funciona offline com o que já está no
/// cache local. Sem filtro de situação, busca nem ordem: isso é feito na
/// tela, em memória, pelas funções de `controle_promissorias.dart`.
final promissoriasProvider = Provider.autoDispose
    .family<AsyncValue<List<ItemPromissoria>>, String?>((ref, clienteId) {
      final vendas = clienteId == null
          ? ref.watch(vendasParceladasProvider)
          : ref.watch(vendasDoClienteProvider(clienteId));
      final lista = vendas.value;
      if (lista == null) {
        return vendas.hasError
            ? AsyncValue.error(vendas.error!, vendas.stackTrace!)
            : const AsyncValue.loading();
      }

      final parcelas = parcelasDasVendas(ref, lista);
      final porVenda = parcelas.value;
      if (porVenda == null) {
        return parcelas.hasError
            ? AsyncValue.error(parcelas.error!, parcelas.stackTrace!)
            : const AsyncValue.loading();
      }

      return AsyncValue.data(
        montarItensPromissoria(vendas: lista, parcelasPorVenda: porVenda),
      );
    });
