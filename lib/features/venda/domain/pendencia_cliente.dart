import '../../cliente/data/cliente_model.dart';
import '../../cliente/domain/status_pagamento.dart';

/// Gravidade da pendência do cliente na nova venda (KAN-24).
enum NivelPendencia { nenhuma, atencao, bloqueado }

/// Situação do cliente que o vendedor precisa ver antes de vender.
///
/// Regras adotadas (confirmar com o time / com os sócios):
/// - Bloqueado (RF30): a venda parcelada não é permitida. À vista
///   continua liberada, porque não gera nova dívida.
/// - Em atraso: venda parcelada exige confirmação de aprovação do
///   gerente, como no protótipo. À vista segue normal.
/// - Limite de crédito: se o cliente tem limite (> 0) e a venda
///   parcelada passaria dele, também exige confirmação.
class PendenciaCliente {
  const PendenciaCliente(this.nivel, this.mensagens);

  final NivelPendencia nivel;
  final List<String> mensagens;

  bool get temPendencia => nivel != NivelPendencia.nenhuma;

  bool get permiteParcelado => nivel != NivelPendencia.bloqueado;

  /// Venda parcelada com pendência precisa de confirmação na tela.
  bool get exigeAprovacaoParcelado => nivel == NivelPendencia.atencao;
}

/// Avalia as pendências de [cliente]. [valorVendaParcelada] é o total
/// da venda quando o pagamento escolhido é parcelado (para checar o
/// limite de crédito); `0` quando não se aplica.
PendenciaCliente avaliarPendencia(
  ClienteModel cliente, {
  double valorVendaParcelada = 0,
  DateTime? agora,
}) {
  final status = statusPagamento(cliente, agora: agora);

  if (status == StatusPagamento.bloqueado) {
    return const PendenciaCliente(NivelPendencia.bloqueado, [
      'Cliente bloqueado. Só é possível vender à vista.',
    ]);
  }

  final mensagens = <String>[];
  if (status == StatusPagamento.emAtraso) {
    mensagens.add(
      'Cliente com parcela em atraso. Venda parcelada requer aprovação '
      'do gerente.',
    );
  }

  final limite = cliente.limiteCredito;
  if (limite > 0 &&
      valorVendaParcelada > 0 &&
      cliente.valorEmAberto + valorVendaParcelada > limite) {
    mensagens.add(
      'Esta venda parcelada passa do limite de crédito do cliente.',
    );
  }

  return PendenciaCliente(
    mensagens.isEmpty ? NivelPendencia.nenhuma : NivelPendencia.atencao,
    mensagens,
  );
}
