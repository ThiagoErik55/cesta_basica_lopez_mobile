import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/parcela_model.dart';
import '../data/venda_model.dart';
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

      final parcelas = parcelasDasVendas(ref, lista);
      final porVenda = parcelas.value;
      if (porVenda == null) {
        return parcelas.hasError
            ? AsyncValue.error(parcelas.error!, parcelas.stackTrace!)
            : const AsyncValue.loading();
      }

      return AsyncValue.data(
        montarHistorico(vendas: lista, parcelasPorVenda: porVenda),
      );
    });

/// Parcelas de cada venda parcelada de [vendas], por id da venda, em
/// tempo real. É `loading` enquanto alguma venda ainda não carregou as
/// suas parcelas, e `error` se alguma falhar. Usado pelo histórico do
/// cliente (KAN-33) e pelo controle de promissórias (KAN-34).
AsyncValue<Map<String, List<ParcelaModel>>> parcelasDasVendas(
  Ref ref,
  List<VendaModel> vendas,
) {
  final porVenda = <String, List<ParcelaModel>>{};
  for (final venda in vendas.where((v) => v.ehPromissoria)) {
    final parcelas = ref.watch(parcelasDaVendaProvider(venda.id));
    final dados = parcelas.value;
    if (dados == null) {
      return parcelas.hasError
          ? AsyncValue.error(parcelas.error!, parcelas.stackTrace!)
          : const AsyncValue.loading();
    }
    porVenda[venda.id] = dados;
  }
  return AsyncValue.data(porVenda);
}
