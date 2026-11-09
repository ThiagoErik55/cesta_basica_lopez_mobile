import '../../../core/utils/formatadores.dart';
import '../../cliente/data/cliente_model.dart';
import '../../cliente/domain/bloqueio_cliente.dart';
import '../../cliente/domain/regra_bloqueio.dart';
import '../../cliente/domain/status_pagamento.dart';
import '../data/parcela_model.dart';

/// Gravidade da pendência do cliente na nova venda (KAN-24).
enum NivelPendencia { nenhuma, atencao, bloqueado }

/// Situação do cliente que o vendedor precisa ver antes de vender, e o
/// que ela permite (KAN-24, KAN-35).
///
/// Regras (a de bloqueio por atraso e por limite vem da [RegraBloqueio],
/// ainda a confirmar com a empresa):
/// - **Bloqueio manual** (`CLIENTE.bloqueado`): nenhuma venda, nem à
///   vista. Foi uma decisão do vendedor e só ele desfaz.
/// - **Bloqueio automático por atraso** (parcela com atraso na tolerância
///   da regra): só a venda parcelada é impedida. A venda à vista segue
///   liberada porque não cria dívida nova e é um jeito de o cliente se
///   regularizar comprando.
/// - **Limite de crédito estourado** (com `bloquearPorLimite` ligado):
///   venda parcelada impedida; à vista liberada, pelo mesmo motivo.
/// - **Atraso dentro da tolerância**: venda parcelada exige confirmação
///   de aprovação do gerente, como no protótipo. À vista segue normal.
class PendenciaCliente {
  const PendenciaCliente(
    this.nivel,
    this.mensagens, {
    this.permiteAVista = true,
    bool? permiteParcelado,
  }) : permiteParcelado = permiteParcelado ?? nivel != NivelPendencia.bloqueado;

  final NivelPendencia nivel;
  final List<String> mensagens;
  final bool permiteAVista;
  final bool permiteParcelado;

  bool get temPendencia => nivel != NivelPendencia.nenhuma;

  /// Venda parcelada com pendência precisa de confirmação na tela.
  bool get exigeAprovacaoParcelado => nivel == NivelPendencia.atencao;
}

/// Avalia as pendências de [cliente] para a nova venda.
///
/// [valorVendaParcelada] é o total da venda quando o pagamento escolhido
/// é parcelado (para checar o limite de crédito); `0` quando não se
/// aplica. [parcelasPendentes] são as parcelas pendentes de todas as
/// vendas do cliente; se ainda não foram carregadas (`null`), a avaliação
/// usa o resumo do próprio cliente.
PendenciaCliente avaliarPendencia(
  ClienteModel cliente, {
  RegraBloqueio regra = regraBloqueioPadrao,
  Iterable<ParcelaModel>? parcelasPendentes,
  double valorVendaParcelada = 0,
  DateTime? agora,
}) {
  final momento = agora ?? DateTime.now();

  if (cliente.bloqueado) {
    return const PendenciaCliente(
      NivelPendencia.bloqueado,
      ['Cliente bloqueado manualmente. Não é possível registrar venda.'],
      permiteAVista: false,
      permiteParcelado: false,
    );
  }

  final bloqueio = parcelasPendentes == null
      ? avaliarBloqueioPeloResumo(
          cliente: cliente,
          agora: momento,
          regra: regra,
          valorNovaVenda: valorVendaParcelada,
        )
      : avaliarBloqueio(
          cliente: cliente,
          parcelasPendentes: parcelasPendentes,
          agora: momento,
          regra: regra,
          valorNovaVenda: valorVendaParcelada,
        );

  if (bloqueio.deveBloquear) {
    return PendenciaCliente(NivelPendencia.bloqueado, [
      mensagemBloqueio(bloqueio, regra),
    ], permiteParcelado: false);
  }

  final mensagens = <String>[];
  if (statusPagamento(cliente, agora: momento) == StatusPagamento.emAtraso) {
    mensagens.add(
      'Cliente com parcela em atraso. Venda parcelada requer aprovação '
      'do gerente.',
    );
  }

  // Com a regra de limite desligada, passar do limite não impede a
  // venda, só pede confirmação (comportamento da KAN-24).
  final limite = cliente.limiteCredito;
  if (!regra.bloquearPorLimite &&
      limite > 0 &&
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

/// Mensagem do bloqueio automático para o vendedor: o motivo, os números
/// e o que ainda é possível fazer.
String mensagemBloqueio(ResultadoBloqueio bloqueio, RegraBloqueio regra) =>
    switch (bloqueio.motivo) {
      MotivoBloqueio.atrasoAcimaDoLimite =>
        'Cliente bloqueado por atraso: ${bloqueio.diasDeAtraso} dias '
            '(bloqueio a partir de ${regra.diasToleranciaAtraso}). '
            'Só é possível vender à vista.',
      MotivoBloqueio.limiteExcedido =>
        'Limite de crédito excedido: limite '
            '${formatarMoeda(bloqueio.limiteCredito)}, em aberto '
            '${formatarMoeda(bloqueio.valorEmAberto)}, excedente '
            '${formatarMoeda(bloqueio.excedenteLimite)}. '
            'Só é possível vender à vista.',
      MotivoBloqueio.nenhum => '',
    };
