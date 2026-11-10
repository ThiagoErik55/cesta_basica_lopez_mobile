import 'dart:typed_data';

import 'package:intl/intl.dart';

import '../../../core/domain/enums.dart';
import '../../../core/utils/cpf.dart';
import '../../cliente/data/cliente_model.dart';
import '../data/parcela_model.dart';
import '../data/venda_model.dart';

/// Item vendido, como aparece na nota.
class ItemNota {
  const ItemNota({
    required this.codigo,
    required this.nome,
    required this.quantidade,
    required this.precoUnitario,
    required this.subtotal,
  });

  /// Código do produto; vazio quando o cadastro não pôde ser consultado.
  final String codigo;
  final String nome;
  final int quantidade;
  final double precoUnitario;
  final double subtotal;
}

/// Troca registrada na venda. Informativa: a diferença de uma troca não
/// entra no total gravado da venda (ver [montarNotaProvisoria]).
class TrocaNota {
  const TrocaNota({
    required this.produtoOriginal,
    required this.produtoNovo,
    required this.quantidade,
    required this.data,
    required this.diferenca,
  });

  final String produtoOriginal;
  final String produtoNovo;
  final int quantidade;
  final DateTime data;

  /// Positiva: o cliente pagou a diferença. Negativa: foi devolvido ao
  /// cliente (valor abatido).
  final double diferenca;
}

class ParcelaNota {
  const ParcelaNota({
    required this.numero,
    required this.vencimento,
    required this.valor,
  });

  final int numero;
  final DateTime vencimento;
  final double valor;
}

/// Dados da nota provisória de compra e venda (KAN-37), prontos para
/// gerar o PDF. Não é persistida: é montada a partir da venda.
class NotaProvisoria {
  const NotaProvisoria({
    required this.numeroNota,
    required this.dataVenda,
    required this.clienteNome,
    required this.cpfMascarado,
    required this.telefone,
    required this.endereco,
    required this.itens,
    required this.trocas,
    required this.subtotal,
    required this.ajusteParcela,
    required this.total,
    required this.tipo,
    required this.forma,
    required this.parcelas,
    required this.emitidoEm,
    this.assinatura,
  });

  final int numeroNota;
  final DateTime dataVenda;
  final String clienteNome;

  /// CPF com só os 3 primeiros e os 2 últimos dígitos (LGPD).
  final String cpfMascarado;
  final String telefone;
  final String endereco;
  final List<ItemNota> itens;
  final List<TrocaNota> trocas;

  /// Soma dos itens.
  final double subtotal;

  /// Diferença entre o total gravado da venda e a soma dos itens, por
  /// exemplo quando o valor de uma parcela foi alterado (KAN-32). Zero
  /// quando não há divergência.
  final double ajusteParcela;

  /// Total gravado na venda (`VENDA.valorTotal`).
  final double total;
  final TipoVenda tipo;

  /// Forma de pagamento da venda à vista; `null` na parcelada.
  final FormaPagamento? forma;
  final List<ParcelaNota> parcelas;
  final DateTime emitidoEm;

  /// Imagem (PNG/JPEG) da assinatura do cliente, para a KAN-38 preencher.
  /// Sem ela, a nota sai com a linha de assinatura em branco.
  final Uint8List? assinatura;

  bool get temAjuste => ajusteParcela != 0;
}

/// Resultado de [montarNotaProvisoria]: ou [erro], ou a [nota].
class ResultadoNotaProvisoria {
  const ResultadoNotaProvisoria.erro(String this.erro) : nota = null;
  const ResultadoNotaProvisoria.ok(NotaProvisoria this.nota) : erro = null;

  final String? erro;
  final NotaProvisoria? nota;

  bool get ok => erro == null;
}

int _centavos(double valor) => (valor * 100).round();

/// Monta a nota provisória de [venda] (à vista ou parcelada).
///
/// - [itens] são os itens a listar (normalmente `venda.itens`); sem itens
///   a nota não é gerada.
/// - O total exibido é sempre o **gravado na venda**. Se ele diverge da
///   soma dos itens (parcela alterada na KAN-32, por exemplo), a
///   diferença aparece como "Ajuste de parcela" em vez de ser escondida.
///   A venda não tem campo de desconto, então não há linha de desconto.
/// - As trocas ficam numa seção própria e não alteram o total, porque o
///   registro da troca não altera `valorTotal`.
/// - [codigos] mapeia o id do produto ao código (o item da venda guarda
///   só o nome); produto ausente fica sem código.
/// - O vendedor não é exibido: a venda guarda só o uid, sem nome.
/// - [assinatura] fica disponível para a KAN-38.
ResultadoNotaProvisoria montarNotaProvisoria({
  required ClienteModel? cliente,
  required VendaModel? venda,
  required List<ItemVenda> itens,
  required List<ParcelaModel> parcelas,
  Map<String, String> codigos = const {},
  Uint8List? assinatura,
  DateTime? emitidoEm,
}) {
  if (venda == null) {
    return const ResultadoNotaProvisoria.erro('Venda não encontrada.');
  }
  if (cliente == null) {
    return const ResultadoNotaProvisoria.erro('Cliente não encontrado.');
  }
  if (itens.isEmpty) {
    return const ResultadoNotaProvisoria.erro('Venda sem itens.');
  }

  final ativas = parcelas.where((p) => !p.deleted).toList()
    ..sort((a, b) => a.numero.compareTo(b.numero));
  if (venda.ehPromissoria && ativas.isEmpty) {
    return const ResultadoNotaProvisoria.erro(
      'Parcelas da venda não encontradas.',
    );
  }

  final itensNota = [
    for (final i in itens)
      ItemNota(
        codigo: codigos[i.produtoId] ?? '',
        nome: i.nome,
        quantidade: i.quantidade,
        precoUnitario: i.precoUnitario,
        subtotal: _centavos(i.precoUnitario) * i.quantidade / 100,
      ),
  ];

  final subtotalCentavos = itens.fold<int>(
    0,
    (soma, i) => soma + _centavos(i.precoUnitario) * i.quantidade,
  );
  final ajusteCentavos = _centavos(venda.valorTotal) - subtotalCentavos;

  String nomeOriginal(TrocaItem t) {
    for (final i in itens) {
      if (i.id == t.itemOriginalId) return i.nome;
    }
    return 'Produto';
  }

  return ResultadoNotaProvisoria.ok(
    NotaProvisoria(
      numeroNota: venda.numeroNota,
      dataVenda: venda.data,
      clienteNome: cliente.nome,
      cpfMascarado: mascararCpf(cliente.cpf),
      telefone: cliente.telefone,
      endereco: cliente.endereco,
      itens: itensNota,
      trocas: [
        for (final t in venda.trocas)
          TrocaNota(
            produtoOriginal: nomeOriginal(t),
            produtoNovo: t.produtoNovoNome,
            quantidade: t.quantidade,
            data: t.data,
            diferenca: t.diferencaValor,
          ),
      ],
      subtotal: subtotalCentavos / 100,
      ajusteParcela: ajusteCentavos / 100,
      total: venda.valorTotal,
      tipo: venda.tipo,
      forma: venda.formaPagamento,
      parcelas: venda.ehPromissoria
          ? [
              for (final p in ativas)
                ParcelaNota(
                  numero: p.numero,
                  vencimento: p.vencimento,
                  valor: p.valor,
                ),
            ]
          : const [],
      emitidoEm: emitidoEm ?? DateTime.now(),
      assinatura: assinatura,
    ),
  );
}

/// Nome do arquivo da nota: `nota-<numeroNota>-<AAAAMMDD>.pdf`, com a
/// data da venda.
String nomeArquivoNota(NotaProvisoria n) =>
    'nota-${n.numeroNota}-${DateFormat('yyyyMMdd').format(n.dataVenda)}.pdf';
