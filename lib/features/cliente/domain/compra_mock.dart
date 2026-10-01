// ============================================================================
// ⚠️ MODELO PROVISÓRIO (KAN-18) — DADOS FICTÍCIOS
//
// Existe só para a seção Histórico de Compras da tela de detalhes do cliente
// ter o que exibir antes do fluxo de vendas. Deve ser SUBSTITUÍDO pelo
// VendaModel/ItemVenda reais (features/venda) quando as vendas forem
// gravadas (Sprint 4/5) — e toda a seção de histórico deve ser revisada
// nesse momento. Não use fora do histórico do cliente.
// ============================================================================

import '../../../core/domain/enums.dart';

/// Compra fictícia de um cliente. Ver aviso no topo do arquivo.
class CompraMock {
  const CompraMock({
    required this.data,
    required this.numeroNota,
    required this.valorTotal,
    required this.tipo,
    required this.itens,
  });

  final DateTime data;
  final int numeroNota;
  final double valorTotal;
  final TipoVenda tipo;
  final List<ItemCompraMock> itens;
}

/// Item de uma [CompraMock]. Ver aviso no topo do arquivo.
class ItemCompraMock {
  const ItemCompraMock({
    required this.produto,
    required this.quantidade,
    required this.valorUnitario,
  });

  final String produto;
  final int quantidade;
  final double valorUnitario;
}
