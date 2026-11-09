import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/parcela_model.dart';
import '../domain/historico_financeiro.dart';
import 'pos_venda_providers.dart';

/// Histórico de compras e pagamentos reais do cliente (KAN-18, KAN-19,
/// KAN-33), em tempo real.
///
/// Junta o stream de vendas do cliente com o de parcelas de cada venda
/// parcelada. Tudo vem de listeners do Firestore, então funciona offline
/// com o que já está no cache local.
final historicoFinanceiroProvider = Provider.autoDispose
    .family<AsyncValue<HistoricoFinanceiro>, String>((ref, clienteId) {
      final vendas = ref.watch(vendasDoClienteProvider(clienteId));
      final lista = vendas.value;
      if (lista == null) {
        return vendas.hasError
            ? AsyncValue.error(vendas.error!, vendas.stackTrace!)
            : const AsyncValue.loading();
      }

      final parcelasPorVenda = <String, List<ParcelaModel>>{};
      for (final venda in lista.where((v) => v.ehPromissoria)) {
        final parcelas = ref.watch(parcelasDaVendaProvider(venda.id));
        final dados = parcelas.value;
        if (dados == null) {
          return parcelas.hasError
              ? AsyncValue.error(parcelas.error!, parcelas.stackTrace!)
              : const AsyncValue.loading();
        }
        parcelasPorVenda[venda.id] = dados;
      }

      return AsyncValue.data(
        montarHistorico(vendas: lista, parcelasPorVenda: parcelasPorVenda),
      );
    });
