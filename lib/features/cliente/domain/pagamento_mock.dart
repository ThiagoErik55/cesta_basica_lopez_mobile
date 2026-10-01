// ============================================================================
// ⚠️ MODELO PROVISÓRIO (KAN-19) — DADOS FICTÍCIOS
//
// Existe só para a seção Histórico de Pagamentos da tela de detalhes do
// cliente ter o que exibir antes do fluxo de pagamentos. Deve ser
// SUBSTITUÍDO pelos modelos reais de PARCELA/PAGAMENTO quando os
// pagamentos forem gravados (Sprint 4/5) — e toda a seção de histórico
// deve ser revisada nesse momento. Não use fora do histórico do cliente.
// ============================================================================

import '../../../core/domain/enums.dart';

/// Pagamento fictício de uma parcela. Ver aviso no topo do arquivo.
class PagamentoMock {
  const PagamentoMock({
    required this.data,
    required this.valor,
    required this.formaPagamento,
    required this.numeroParcela,
  });

  final DateTime data;
  final double valor;
  final FormaPagamento formaPagamento;
  final int numeroParcela;
}
