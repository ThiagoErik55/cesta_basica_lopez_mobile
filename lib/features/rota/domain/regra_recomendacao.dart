import '../../../core/domain/enums.dart';

// Regra de recomendação de clientes a visitar (KAN-48).
//
// Os números ficam TODOS aqui, em constantes nomeadas: a pontuação em
// `recomendacao_visita.dart` só combina o que vem de uma [RegraRecomendacao],
// sem número fixo. A empresa ainda não definiu o que prioriza uma visita,
// então estes são valores iniciais de trabalho, fáceis de trocar.
//
// Ideia dos pesos (pontos): cobrar vem antes de vender. Um cliente com
// parcela vencida ou vencendo na data pontua mais do que qualquer cliente
// só inativo, mesmo um score A muito tempo sem comprar. Reativar vem
// depois, e "nunca comprou" é a menor prioridade.

/// Quantos clientes aparecem no bloco do topo da agenda.
const int padraoQuantidadeRecomendados = 5;

// --- Atraso (parcela vencida na data da agenda) --------------------------

/// Pontos de quem tem qualquer parcela vencida.
const double padraoPesoAtrasoBase = 40;

/// Pontos por dia de atraso da parcela mais atrasada.
const double padraoPesoAtrasoPorDia = 1;

/// A partir de quantos dias de atraso o peso por dia deixa de crescer.
const int padraoDiasAtrasoMaximo = 60;

/// Pontos por R$ 100,00 de saldo vencido.
const double padraoPesoSaldoVencidoPor100 = 2;

/// A partir de quanto saldo vencido (R$) o peso deixa de crescer.
const double padraoSaldoVencidoMaximo = 1500;

// --- Vence na data da agenda ---------------------------------------------

/// Pontos de quem tem parcela vencendo exatamente na data.
const double padraoPesoVenceNaData = 35;

// --- Inatividade (dias desde a última compra) ----------------------------

/// Dias sem comprar a partir dos quais o cliente entra como "reativação".
const int padraoDiasInatividade = 30;

/// Pontos de quem passou do limite de inatividade.
const double padraoPesoInatividadeBase = 10;

/// Pontos por dia além do limite.
const double padraoPesoInatividadePorDia = 0.1;

/// Dias sem comprar a partir dos quais o peso deixa de crescer.
const int padraoDiasInatividadeMaximo = 150;

// --- Cliente que nunca comprou -------------------------------------------

/// Pontos fixos (e baixos) de quem ainda não tem nenhuma compra.
const double padraoPesoNuncaComprou = 12;

// --- Score do cliente ----------------------------------------------------
// Multiplicadores por score (A, B, C, D). Reativação favorece A e B (vale
// mais reconquistar um bom cliente); cobrança favorece C e D (o risco é
// maior). Cliente que nunca comprou não tem score confiável: não usa.

const Map<ScoreCliente, double> padraoMultiplicadorReativacao = {
  ScoreCliente.a: 1.3,
  ScoreCliente.b: 1.15,
  ScoreCliente.c: 0.75,
  ScoreCliente.d: 0.5,
};

const Map<ScoreCliente, double> padraoMultiplicadorCobranca = {
  ScoreCliente.a: 1,
  ScoreCliente.b: 1,
  ScoreCliente.c: 1.25,
  ScoreCliente.d: 1.5,
};

/// Pesos e limites da recomendação. Imutável: para mudar a regra, basta
/// fornecer outra instância em `regraRecomendacaoProvider`.
class RegraRecomendacao {
  const RegraRecomendacao({
    this.quantidade = padraoQuantidadeRecomendados,
    this.pesoAtrasoBase = padraoPesoAtrasoBase,
    this.pesoAtrasoPorDia = padraoPesoAtrasoPorDia,
    this.diasAtrasoMaximo = padraoDiasAtrasoMaximo,
    this.pesoSaldoVencidoPor100 = padraoPesoSaldoVencidoPor100,
    this.saldoVencidoMaximo = padraoSaldoVencidoMaximo,
    this.pesoVenceNaData = padraoPesoVenceNaData,
    this.diasInatividade = padraoDiasInatividade,
    this.pesoInatividadeBase = padraoPesoInatividadeBase,
    this.pesoInatividadePorDia = padraoPesoInatividadePorDia,
    this.diasInatividadeMaximo = padraoDiasInatividadeMaximo,
    this.pesoNuncaComprou = padraoPesoNuncaComprou,
    this.multiplicadorReativacao = padraoMultiplicadorReativacao,
    this.multiplicadorCobranca = padraoMultiplicadorCobranca,
  }) : assert(quantidade > 0, 'a quantidade deve ser positiva'),
       assert(diasInatividade > 0, 'o limite de inatividade deve ser positivo');

  /// Tamanho do bloco do topo da agenda.
  final int quantidade;

  final double pesoAtrasoBase;
  final double pesoAtrasoPorDia;
  final int diasAtrasoMaximo;
  final double pesoSaldoVencidoPor100;
  final double saldoVencidoMaximo;

  final double pesoVenceNaData;

  final int diasInatividade;
  final double pesoInatividadeBase;
  final double pesoInatividadePorDia;
  final int diasInatividadeMaximo;

  final double pesoNuncaComprou;

  final Map<ScoreCliente, double> multiplicadorReativacao;
  final Map<ScoreCliente, double> multiplicadorCobranca;

  /// Multiplicador do score na reativação (1 se o score não está no mapa).
  double reativacaoDo(ScoreCliente s) => multiplicadorReativacao[s] ?? 1;

  /// Multiplicador do score na cobrança (1 se o score não está no mapa).
  double cobrancaDo(ScoreCliente s) => multiplicadorCobranca[s] ?? 1;

  RegraRecomendacao copyWith({
    int? quantidade,
    double? pesoAtrasoBase,
    double? pesoAtrasoPorDia,
    int? diasAtrasoMaximo,
    double? pesoSaldoVencidoPor100,
    double? saldoVencidoMaximo,
    double? pesoVenceNaData,
    int? diasInatividade,
    double? pesoInatividadeBase,
    double? pesoInatividadePorDia,
    int? diasInatividadeMaximo,
    double? pesoNuncaComprou,
    Map<ScoreCliente, double>? multiplicadorReativacao,
    Map<ScoreCliente, double>? multiplicadorCobranca,
  }) => RegraRecomendacao(
    quantidade: quantidade ?? this.quantidade,
    pesoAtrasoBase: pesoAtrasoBase ?? this.pesoAtrasoBase,
    pesoAtrasoPorDia: pesoAtrasoPorDia ?? this.pesoAtrasoPorDia,
    diasAtrasoMaximo: diasAtrasoMaximo ?? this.diasAtrasoMaximo,
    pesoSaldoVencidoPor100:
        pesoSaldoVencidoPor100 ?? this.pesoSaldoVencidoPor100,
    saldoVencidoMaximo: saldoVencidoMaximo ?? this.saldoVencidoMaximo,
    pesoVenceNaData: pesoVenceNaData ?? this.pesoVenceNaData,
    diasInatividade: diasInatividade ?? this.diasInatividade,
    pesoInatividadeBase: pesoInatividadeBase ?? this.pesoInatividadeBase,
    pesoInatividadePorDia: pesoInatividadePorDia ?? this.pesoInatividadePorDia,
    diasInatividadeMaximo: diasInatividadeMaximo ?? this.diasInatividadeMaximo,
    pesoNuncaComprou: pesoNuncaComprou ?? this.pesoNuncaComprou,
    multiplicadorReativacao:
        multiplicadorReativacao ?? this.multiplicadorReativacao,
    multiplicadorCobranca: multiplicadorCobranca ?? this.multiplicadorCobranca,
  );
}

/// A regra em vigor quando nada diferente foi configurado.
const RegraRecomendacao regraRecomendacaoPadrao = RegraRecomendacao();
