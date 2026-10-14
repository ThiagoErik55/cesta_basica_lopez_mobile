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
