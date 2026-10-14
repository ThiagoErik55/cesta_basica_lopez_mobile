import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/parcela_model.dart';
import '../data/venda_model.dart';
import '../data/venda_repository.dart';

/// Venda por id, em tempo real (tela de detalhes da venda).
final vendaPorIdProvider = StreamProvider.autoDispose
    .family<VendaModel?, String>(
      (ref, id) => ref.watch(vendaRepositoryProvider).observarPorId(id),
    );

/// Parcelas de uma venda parcelada.
final parcelasDaVendaProvider = StreamProvider.autoDispose
    .family<List<ParcelaModel>, String>(
      (ref, vendaId) =>
          ref.watch(vendaRepositoryProvider).observarParcelas(vendaId),
    );

/// Vendas de um cliente, da mais recente para a mais antiga.
final vendasDoClienteProvider = StreamProvider.autoDispose
    .family<List<VendaModel>, String>(
      (ref, clienteId) =>
          ref.watch(vendaRepositoryProvider).observarPorCliente(clienteId),
    );
