import '../../../core/domain/enums.dart';
import '../data/parcela_model.dart';
import '../data/venda_model.dart';
import 'promissoria.dart';
import 'rotulos_venda.dart';

/// Venda no histórico de compras do cliente, com sua situação.
class CompraHistorico {
  const CompraHistorico({required this.venda, required this.situacao});

  final VendaModel venda;
  final SituacaoCompra situacao;
}

/// Pagamento no histórico do cliente, com a parcela e a venda de origem.
class PagamentoHistorico {
  const PagamentoHistorico({
    required this.pagamento,
    required this.parcelaId,
    required this.numeroParcela,
    required this.vendaId,
    required this.numeroNota,
  });

  final PagamentoModel pagamento;
  final String parcelaId;
  final int numeroParcela;
  final String vendaId;
  final int numeroNota;
}

class HistoricoFinanceiro {
  const HistoricoFinanceiro({required this.compras, required this.pagamentos});

  final List<CompraHistorico> compras;
  final List<PagamentoHistorico> pagamentos;
}

/// Monta o histórico financeiro de um cliente a partir das suas
/// [vendas] e das parcelas de cada venda parcelada ([parcelasPorVenda],
/// por id da venda).
///
/// - Compras e pagamentos saem do mais recente para o mais antigo.
/// - Venda à vista conta como paga; a parcelada tem a situação da
///   promissória (quitada, em atraso ou em aberto).
/// - O histórico de pagamentos vem dos pagamentos gravados, sem depender
///   do valor que a parcela tinha quando foram feitos (KAN-32).
/// - Vendas removidas são ignoradas.
HistoricoFinanceiro montarHistorico({
  required List<VendaModel> vendas,
  required Map<String, List<ParcelaModel>> parcelasPorVenda,
}) {
  final ativas = vendas.where((v) => !v.deleted).toList()
    ..sort((a, b) => b.data.compareTo(a.data));

  final compras = <CompraHistorico>[];
  final pagamentos = <PagamentoHistorico>[];

  for (final venda in ativas) {
    final parcelas = (parcelasPorVenda[venda.id] ?? const <ParcelaModel>[])
        .where((p) => !p.deleted)
        .toList();

    compras.add(
      CompraHistorico(venda: venda, situacao: _situacao(venda, parcelas)),
    );

    for (final p in parcelas) {
      for (final pag in p.pagamentos) {
        pagamentos.add(
          PagamentoHistorico(
            pagamento: pag,
            parcelaId: p.id,
            numeroParcela: p.numero,
            vendaId: venda.id,
            numeroNota: venda.numeroNota,
          ),
        );
      }
    }
  }

  pagamentos.sort((a, b) => b.pagamento.data.compareTo(a.pagamento.data));
  return HistoricoFinanceiro(compras: compras, pagamentos: pagamentos);
}

SituacaoCompra _situacao(VendaModel venda, List<ParcelaModel> parcelas) {
  if (venda.tipo == TipoVenda.aVista) return SituacaoCompra.paga;
  if (parcelas.isEmpty) return SituacaoCompra.emAberto;
  return switch (Promissoria(venda: venda, parcelas: parcelas).status) {
    StatusPromissoria.paga => SituacaoCompra.quitada,
    StatusPromissoria.atrasada => SituacaoCompra.emAtraso,
    StatusPromissoria.aberta => SituacaoCompra.emAberto,
  };
}
