import '../../../core/domain/enums.dart';

/// Rótulos de exibição das formas de pagamento e tipos de venda.
extension FormaPagamentoRotulo on FormaPagamento {
  String get rotulo => switch (this) {
    FormaPagamento.pix => 'Pix',
    FormaPagamento.credito => 'Crédito',
    FormaPagamento.debito => 'Débito',
    FormaPagamento.valeAlimentacao => 'Vale-alimentação',
    FormaPagamento.dinheiro => 'Dinheiro',
  };
}

extension TipoVendaRotulo on TipoVenda {
  String get rotulo => switch (this) {
    TipoVenda.aVista => 'À vista',
    TipoVenda.parcelado => 'Parcelado',
  };
}

/// Situação de uma compra no histórico do cliente (KAN-33).
enum SituacaoCompra { paga, emAberto, emAtraso, quitada }

extension SituacaoCompraRotulo on SituacaoCompra {
  String get rotulo => switch (this) {
    SituacaoCompra.paga => 'Paga',
    SituacaoCompra.emAberto => 'Em aberto',
    SituacaoCompra.emAtraso => 'Em atraso',
    SituacaoCompra.quitada => 'Quitada',
  };
}
