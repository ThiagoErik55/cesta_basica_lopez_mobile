import '../data/parcela_model.dart';

/// Como compensar a diferença quando o valor de uma parcela muda.
enum ModoCompensacao {
  /// Reparte a diferença, em partes iguais, entre as outras parcelas
  /// pendentes; o total da venda não muda.
  redistribuir,

  /// Muda só a parcela escolhida; o total da venda muda junto.
  ajustarSomente,
}

/// Uma parcela cujo valor mudou, com o registro para o histórico.
class ParcelaAlterada {
  const ParcelaAlterada({
    required this.parcelaId,
    required this.numero,
    required this.alteracao,
  });

  final String parcelaId;
  final int numero;
  final AlteracaoValorParcela alteracao;
}

/// Resultado de [alterarValorParcela]: ou [erro] preenchido, ou as
/// parcelas alteradas e os totais antes e depois.
class ResultadoAlteracaoParcela {
  const ResultadoAlteracaoParcela.erro(String this.erro)
    : alteradas = const [],
      parcelasResultantes = const [],
      totalAnterior = 0,
      totalNovo = 0;

  const ResultadoAlteracaoParcela.ok({
    required this.alteradas,
    required this.parcelasResultantes,
    required this.totalAnterior,
    required this.totalNovo,
  }) : erro = null;

  final String? erro;

  /// Só as parcelas que mudaram.
  final List<ParcelaAlterada> alteradas;

  /// Todas as parcelas da venda como ficariam, para a prévia.
  final List<ParcelaModel> parcelasResultantes;

  final double totalAnterior;
  final double totalNovo;

  bool get ok => erro == null;

  /// Variação do total da venda, que é também a variação do valor em
  /// aberto do cliente. Zero ao redistribuir.
  double get diferencaTotal => (totalNovo * 100).round() / 100 - totalAnterior;
}

int _centavos(double valor) => (valor * 100).round();

bool _pendente(ParcelaModel p) => !p.pago && !p.deleted;

/// Calcula a alteração do valor da parcela [parcelaId] para [novoValor].
///
/// - Só parcela pendente pode mudar; parcela paga fica intocada.
/// - O valor novo precisa ser maior que zero e maior que o já pago na
///   parcela (um pagamento parcial não pode ficar "sobrando").
/// - [ModoCompensacao.redistribuir]: a diferença é repartida em partes
///   iguais entre as demais parcelas pendentes, com os centavos que não
///   dividem certo na última. Se alguma delas ficaria com valor ≤ 0 (ou
///   ≤ ao já pago), a alteração é recusada. Sem outras pendentes, esse
///   modo não existe.
/// - [ModoCompensacao.ajustarSomente]: só a parcela muda e o total da
///   venda ([valorTotalVenda]) varia pela diferença.
///
/// Tudo em centavos, para a soma não ganhar nem perder dinheiro.
ResultadoAlteracaoParcela alterarValorParcela({
  required List<ParcelaModel> parcelas,
  required String parcelaId,
  required double novoValor,
  required ModoCompensacao modo,
  required double valorTotalVenda,
  String? motivo,
  DateTime? agora,
}) {
  final momento = agora ?? DateTime.now();
  final ativas = parcelas.where((p) => !p.deleted).toList()
    ..sort((a, b) => a.numero.compareTo(b.numero));

  final alvo = ativas.where((p) => p.id == parcelaId).firstOrNull;
  if (alvo == null) {
    return const ResultadoAlteracaoParcela.erro('Parcela não encontrada.');
  }
  if (alvo.pago) {
    return const ResultadoAlteracaoParcela.erro(
      'Parcela paga não pode ser alterada.',
    );
  }

  final atual = _centavos(alvo.valor);
  final novo = _centavos(novoValor);
  if (novo <= 0) {
    return const ResultadoAlteracaoParcela.erro(
      'O valor da parcela deve ser maior que zero.',
    );
  }
  if (novo == atual) {
    return const ResultadoAlteracaoParcela.erro(
      'O valor informado é igual ao atual.',
    );
  }
  if (novo <= _centavos(alvo.totalPago)) {
    return const ResultadoAlteracaoParcela.erro(
      'O valor deve ser maior que o já pago nesta parcela.',
    );
  }

  final novosValores = <String, int>{alvo.id: novo};
  final delta = novo - atual;

  if (modo == ModoCompensacao.redistribuir) {
    final outras = ativas.where((p) => _pendente(p) && p.id != alvo.id);
    if (outras.isEmpty) {
      return const ResultadoAlteracaoParcela.erro(
        'Não há outras parcelas pendentes para redistribuir a diferença.',
      );
    }
    final lista = outras.toList();
    final compensacao = -delta;
    final parte = compensacao ~/ lista.length;
    final resto = compensacao - parte * lista.length;

    for (var i = 0; i < lista.length; i++) {
      final p = lista[i];
      final ajuste = i == lista.length - 1 ? parte + resto : parte;
      final valor = _centavos(p.valor) + ajuste;
      if (valor <= 0 || valor <= _centavos(p.totalPago)) {
        return ResultadoAlteracaoParcela.erro(
          'A redistribuição deixaria a ${p.numero}ª parcela com valor '
          'menor ou igual a zero. Escolha um valor menor ou ajuste só '
          'esta parcela.',
        );
      }
      novosValores[p.id] = valor;
    }
  }

  final alteradas = <ParcelaAlterada>[];
  final resultantes = <ParcelaModel>[];
  for (final p in ativas) {
    final valor = novosValores[p.id];
    if (valor == null) {
      resultantes.add(p);
      continue;
    }
    final alteracao = AlteracaoValorParcela(
      valorAnterior: p.valor,
      valorNovo: valor / 100,
      data: momento,
      motivo: p.id == alvo.id
          ? _motivoLimpo(motivo)
          : 'Compensação da alteração da ${alvo.numero}ª parcela',
    );
    alteradas.add(
      ParcelaAlterada(parcelaId: p.id, numero: p.numero, alteracao: alteracao),
    );
    resultantes.add(
      p.copyWith(valor: valor / 100, alteracoes: [...p.alteracoes, alteracao]),
    );
  }

  final totalAnterior = valorTotalVenda;
  final totalNovo = (_centavos(valorTotalVenda) + _delta(modo, delta)) / 100;

  return ResultadoAlteracaoParcela.ok(
    alteradas: alteradas,
    parcelasResultantes: resultantes,
    totalAnterior: totalAnterior,
    totalNovo: totalNovo,
  );
}

int _delta(ModoCompensacao modo, int delta) =>
    modo == ModoCompensacao.ajustarSomente ? delta : 0;

String? _motivoLimpo(String? motivo) {
  final texto = motivo?.trim();
  return texto == null || texto.isEmpty ? null : texto;
}
