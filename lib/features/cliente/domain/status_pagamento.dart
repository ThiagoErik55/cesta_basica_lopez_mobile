import '../data/cliente_model.dart';

/// Situação de pagamento do cliente (KAN-16). Derivada dos campos do
/// [ClienteModel] a cada leitura — nunca persistida.
enum StatusPagamento { emDia, emAtraso, bloqueado }

extension StatusPagamentoRotulo on StatusPagamento {
  String get rotulo => switch (this) {
    StatusPagamento.emDia => 'Em dia',
    StatusPagamento.emAtraso => 'Em atraso',
    StatusPagamento.bloqueado => 'Bloqueado',
  };
}

/// Calcula o status de pagamento de [cliente] em [agora] (padrão: o
/// instante atual).
///
/// - Bloqueado: `bloqueado == true`, com prioridade sobre os demais. O
///   campo só é lido aqui; quem o escreve é a regra de bloqueio (RF30).
/// - Em atraso: vencimento já passou **e** ainda há valor em aberto. Sem
///   débito o cliente está em dia mesmo com um `proximoVencimento`
///   antigo — mesma regra de [ClienteModel.emAtraso].
/// - Em dia: todos os demais casos.
StatusPagamento statusPagamento(ClienteModel cliente, {DateTime? agora}) {
  if (cliente.bloqueado) return StatusPagamento.bloqueado;

  final vencimento = cliente.proximoVencimento;
  final referencia = agora ?? DateTime.now();
  if (vencimento != null &&
      vencimento.isBefore(referencia) &&
      cliente.temDebito) {
    return StatusPagamento.emAtraso;
  }
  return StatusPagamento.emDia;
}
