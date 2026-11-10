import '../../../core/utils/formatadores.dart';
import '../../../core/utils/whatsapp.dart';
import 'comprovante_pagamento.dart';
import 'nota_provisoria.dart';

/// Mensagens padrão do envio por WhatsApp (KAN-39). Levam só o primeiro
/// nome, valores e datas: nunca CPF, endereço nem saldo em aberto (LGPD).

String _saudacao(String nome) {
  final primeiro = primeiroNome(nome);
  return primeiro == null ? 'Olá!' : 'Olá, $primeiro!';
}

String mensagemComprovante(ComprovantePagamento c) =>
    '${_saudacao(c.clienteNome)} Segue o comprovante do seu pagamento de '
    '${formatarMoeda(c.valorPago)} referente à nota ${c.numeroNota}, '
    'parcela ${c.numeroParcela}/${c.totalParcelas}, '
    'em ${formatarData(c.dataPagamento)}. Obrigado! Cesta Básica Lopez';

String mensagemNota(NotaProvisoria n) =>
    '${_saudacao(n.clienteNome)} Segue a nota provisória ${n.numeroNota} da '
    'sua compra de ${formatarData(n.dataVenda)}, no valor de '
    '${formatarMoeda(n.total)}. Obrigado! Cesta Básica Lopez';
