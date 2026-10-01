// ============================================================================
// ⚠️ PROVISÓRIO (KAN-18, KAN-19) — DADOS FICTÍCIOS
//
// Gera em memória um histórico de compras e pagamentos falso para a tela de
// detalhes do cliente. Nada é lido nem gravado no Firestore. Quando VENDA e
// PAGAMENTO forem gravados de verdade (Sprint 4/5), estes providers devem
// ser substituídos por consultas aos repositórios reais, com a mesma forma
// (lista por clienteId), e este arquivo removido.
// ============================================================================

import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/domain/enums.dart';
import '../domain/compra_mock.dart';
import '../domain/pagamento_mock.dart';

/// Compras fictícias do cliente, da mais recente para a mais antiga.
final comprasMockProvider = Provider.autoDispose
    .family<List<CompraMock>, String>(
      (ref, clienteId) => _gerarCompras(_aleatorio(clienteId, 1)),
    );

/// Pagamentos fictícios do cliente, do mais recente para o mais antigo.
final pagamentosMockProvider = Provider.autoDispose
    .family<List<PagamentoMock>, String>(
      (ref, clienteId) => _gerarPagamentos(_aleatorio(clienteId, 2)),
    );

/// Gerador com semente derivada do id do cliente, para o mesmo cliente
/// ver sempre o mesmo histórico. Não usa String.hashCode, que não tem
/// garantia de ser igual entre execuções. [canal] separa as sequências
/// de compras e pagamentos.
Random _aleatorio(String clienteId, int canal) {
  var semente = canal;
  for (final c in clienteId.codeUnits) {
    // Mantém em 31 bits: na web os inteiros são doubles e perderiam
    // precisão acima de 2^53.
    semente = (semente * 31 + c) & 0x7fffffff;
  }
  return Random(semente);
}

/// Datas contadas a partir de hoje à meia-noite: o histórico não muda
/// entre recarregamentos no mesmo dia.
DateTime get _hoje {
  final agora = DateTime.now();
  return DateTime(agora.year, agora.month, agora.day);
}

const _produtos = [
  ('Cesta Básica Tradicional', 129.90),
  ('Cesta Básica Especial', 189.90),
  ('Arroz 5kg', 27.50),
  ('Feijão 1kg', 8.90),
  ('Óleo de soja 900ml', 7.49),
  ('Café 500g', 18.90),
  ('Açúcar 5kg', 22.90),
];

List<CompraMock> _gerarCompras(Random r) {
  var diasAtras = r.nextInt(10);
  return List.generate(3 + r.nextInt(3), (_) {
    final itens = List.generate(1 + r.nextInt(3), (_) {
      final (produto, preco) = _produtos[r.nextInt(_produtos.length)];
      return ItemCompraMock(
        produto: produto,
        quantidade: 1 + r.nextInt(3),
        valorUnitario: preco,
      );
    });
    final compra = CompraMock(
      data: _hoje.subtract(Duration(days: diasAtras)),
      numeroNota: 1000 + r.nextInt(9000),
      // Soma só para os números do mock serem coerentes entre si.
      valorTotal: itens.fold(0, (t, i) => t + i.quantidade * i.valorUnitario),
      tipo: r.nextBool() ? TipoVenda.aVista : TipoVenda.parcelado,
      itens: itens,
    );
    diasAtras += 20 + r.nextInt(30);
    return compra;
  });
}

List<PagamentoMock> _gerarPagamentos(Random r) {
  final quantidade = 3 + r.nextInt(3);
  final valorParcela = 40 + r.nextInt(16) * 10.0;
  const formas = FormaPagamento.values;
  final primeiro = _hoje.subtract(Duration(days: 30 * quantidade));
  return List.generate(quantidade, (i) {
    final numero = quantidade - i;
    return PagamentoMock(
      data: primeiro.add(Duration(days: 30 * numero - r.nextInt(5))),
      valor: valorParcela,
      formaPagamento: formas[r.nextInt(formas.length)],
      numeroParcela: numero,
    );
  });
}
