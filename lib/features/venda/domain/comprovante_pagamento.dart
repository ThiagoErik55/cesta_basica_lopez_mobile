import 'package:intl/intl.dart';

import '../../../core/domain/enums.dart';
import '../../../core/utils/cpf.dart';
import '../../cliente/data/cliente_model.dart';
import '../data/parcela_model.dart';
import '../data/venda_model.dart';

/// Dados de um comprovante de pagamento (KAN-36), prontos para gerar o
/// PDF. Não é persistido: é montado a partir de um [PagamentoModel] já
/// registrado, da sua parcela, da venda e do cliente.
class ComprovantePagamento {
  const ComprovantePagamento({
    required this.numero,
    required this.clienteNome,
    required this.cpfMascarado,
    required this.telefone,
    required this.numeroNota,
    required this.numeroParcela,
    required this.totalParcelas,
    required this.dataPagamento,
    required this.valorPago,
    required this.forma,
    required this.observacao,
    required this.saldoRestanteParcela,
    required this.saldoEmAbertoVenda,
    required this.parcelaQuitada,
    required this.emitidoEm,
  });

  /// Identificador legível e estável, ex. `2611091530-P2-1`: nota da
  /// venda, número da parcela e ordem do pagamento na parcela.
  final String numero;
  final String clienteNome;

  /// CPF com só os 3 primeiros e os 2 últimos dígitos (LGPD).
  final String cpfMascarado;

  /// Telefone do cliente como cadastrado. Não aparece no PDF; serve para
  /// endereçar o envio por WhatsApp (KAN-39).
  final String telefone;
  final int numeroNota;
  final int numeroParcela;
  final int totalParcelas;
  final DateTime dataPagamento;
  final double valorPago;
  final FormaPagamento forma;
  final String? observacao;

  /// O que faltava pagar na parcela logo depois deste pagamento.
  final double saldoRestanteParcela;

  /// O que faltava pagar na venda toda logo depois deste pagamento.
  final double saldoEmAbertoVenda;

  /// Este pagamento quitou a parcela.
  final bool parcelaQuitada;

  final DateTime emitidoEm;
}

/// Resultado de [montarComprovantePagamento]: ou [erro], ou o
/// [comprovante].
class ResultadoComprovante {
  const ResultadoComprovante.erro(String this.erro) : comprovante = null;
  const ResultadoComprovante.ok(ComprovantePagamento this.comprovante)
    : erro = null;

  final String? erro;
  final ComprovantePagamento? comprovante;

  bool get ok => erro == null;
}

int _centavos(double valor) => (valor * 100).round();

/// Monta o comprovante do pagamento [pagamentoId], feito na parcela
/// [parcelaId] de [venda].
///
/// - O número é `nota-P<parcela>-<ordem>`. A ordem é a posição do
///   pagamento no registro da parcela, que só cresce (cada pagamento
///   entra no fim), então o número de um comprovante não muda quando
///   outros pagamentos são feitos depois.
/// - Os saldos são os **da época**, não os de hoje: na parcela, vale o
///   valor da parcela menos os pagamentos até este inclusive; nas outras
///   parcelas, menos os pagamentos feitos até a data deste. Assim o
///   comprovante de um pagamento antigo continua mostrando o que faltava
///   naquele momento. Usa o valor atual das parcelas, inclusive as
///   alteradas depois (KAN-32).
/// - Parcela marcada como paga sem pagamento registrado conta como
///   quitada.
/// - O CPF sai mascarado.
ResultadoComprovante montarComprovantePagamento({
  required ClienteModel cliente,
  required VendaModel venda,
  required List<ParcelaModel> parcelas,
  required String parcelaId,
  required String pagamentoId,
  DateTime? emitidoEm,
}) {
  final ativas = parcelas.where((p) => !p.deleted).toList()
    ..sort((a, b) => a.numero.compareTo(b.numero));

  final parcela = ativas.where((p) => p.id == parcelaId).firstOrNull;
  if (parcela == null) {
    return const ResultadoComprovante.erro('Parcela não encontrada.');
  }
  final indice = parcela.pagamentos.indexWhere((p) => p.id == pagamentoId);
  if (indice < 0) {
    return const ResultadoComprovante.erro('Pagamento não encontrado.');
  }
  final pagamento = parcela.pagamentos[indice];

  var saldoParcela =
      _centavos(parcela.valor) -
      parcela.pagamentos
          .take(indice + 1)
          .fold<int>(0, (soma, p) => soma + _centavos(p.valor));
  if (saldoParcela < 0) saldoParcela = 0;

  var saldoVenda = saldoParcela;
  for (final outra in ativas) {
    if (outra.id == parcela.id) continue;
    if (outra.pago && outra.pagamentos.isEmpty) continue;
    final pagoAte = outra.pagamentos
        .where((p) => !p.data.isAfter(pagamento.data))
        .fold<int>(0, (soma, p) => soma + _centavos(p.valor));
    final saldo = _centavos(outra.valor) - pagoAte;
    if (saldo > 0) saldoVenda += saldo;
  }

  final texto = pagamento.observacao?.trim();

  return ResultadoComprovante.ok(
    ComprovantePagamento(
      numero: '${venda.numeroNota}-P${parcela.numero}-${indice + 1}',
      clienteNome: cliente.nome,
      cpfMascarado: mascararCpf(cliente.cpf),
      telefone: cliente.telefone,
      numeroNota: venda.numeroNota,
      numeroParcela: parcela.numero,
      totalParcelas: ativas.length,
      dataPagamento: pagamento.data,
      valorPago: pagamento.valor,
      forma: pagamento.forma,
      observacao: texto == null || texto.isEmpty ? null : texto,
      saldoRestanteParcela: saldoParcela / 100,
      saldoEmAbertoVenda: saldoVenda / 100,
      parcelaQuitada: saldoParcela == 0,
      emitidoEm: emitidoEm ?? DateTime.now(),
    ),
  );
}

/// Nome do arquivo do comprovante:
/// `comprovante-<numeroNota>-parcela<N>-<AAAAMMDD>.pdf`, com a data do
/// pagamento.
String nomeArquivoComprovante(ComprovantePagamento c) =>
    'comprovante-${c.numeroNota}-parcela${c.numeroParcela}-'
    '${DateFormat('yyyyMMdd').format(c.dataPagamento)}.pdf';
