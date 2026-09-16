import '../../../core/domain/enums.dart';
import '../data/parcela_model.dart';
import '../data/venda_model.dart';

/// Visão derivada de uma venda parcelada (RF20).
/// Não é persistida: construída a partir da venda e suas parcelas.
class Promissoria {
  final VendaModel venda;
  final List<ParcelaModel> parcelas;

  const Promissoria({required this.venda, required this.parcelas});

  int get numeroNota => venda.numeroNota;

  String get clienteNome => venda.clienteNome;

  String? get assinatura => venda.assinaturaBase64;

  double get valorOriginal => venda.valorTotal;

  double get saldo =>
      parcelas.where((p) => !p.pago).fold(0, (soma, p) => soma + p.saldo);

  StatusPromissoria get status {
    if (parcelas.every((p) => p.pago)) return StatusPromissoria.paga;
    if (parcelas.any((p) => p.atrasada)) return StatusPromissoria.atrasada;
    return StatusPromissoria.aberta;
  }

  /// Histórico da dívida: todos os pagamentos em ordem cronológica.
  List<PagamentoModel> get historico {
    final todos = parcelas.expand((p) => p.pagamentos).toList()
      ..sort((a, b) => a.data.compareTo(b.data));
    return todos;
  }

  DateTime? get proximoVencimento {
    final abertas = parcelas.where((p) => !p.pago).toList()
      ..sort((a, b) => a.vencimento.compareTo(b.vencimento));
    return abertas.isEmpty ? null : abertas.first.vencimento;
  }

  int get parcelasAtrasadas => parcelas.where((p) => p.atrasada).length;
}
