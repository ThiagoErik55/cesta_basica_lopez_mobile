import '../../../core/utils/texto.dart';
import 'agenda_vendedor.dart';
import 'regra_recomendacao.dart';

// Recomendação de clientes a visitar (KAN-48). Tudo derivado na leitura a
// partir da agenda (KAN-47): nada é gravado. Persistir "visita feita" ou
// "dispensado" dependeria da entidade VISITA (hoje sem uso) ou de campo
// novo, o que esta task não cria.

/// Por que o cliente está sendo recomendado (o fator que mais pesa).
enum MotivoVisita {
  /// Parcela vencida: visita de cobrança.
  cobrancaEmAtraso,

  /// Parcela vencendo exatamente na data da agenda.
  venceNaData,

  /// Muito tempo sem comprar: visita para vender.
  reativacao,

  /// Ainda não comprou nada.
  clienteNovo,

  /// Cliente bloqueado com cobrança pendente. Só se cobra: ver
  /// [pontuarVisita].
  bloqueadoCobrar,
}

extension RotuloMotivoVisita on MotivoVisita {
  /// Texto curto do selo.
  String get rotulo => switch (this) {
    MotivoVisita.cobrancaEmAtraso => 'Em atraso',
    MotivoVisita.venceNaData => 'Vence na data',
    MotivoVisita.reativacao => 'Reativar',
    MotivoVisita.clienteNovo => 'Sem compras',
    MotivoVisita.bloqueadoCobrar => 'Bloqueado: cobrar',
  };
}

/// Um cliente recomendado, com a pontuação e o motivo.
class Recomendacao {
  const Recomendacao({
    required this.item,
    required this.pontos,
    required this.motivo,
    required this.textoMotivo,
  });

  final ItemAgenda item;

  /// Prioridade: maior = visitar antes. Sempre positiva (cliente com
  /// pontuação zero não é recomendado).
  final double pontos;
  final MotivoVisita motivo;

  /// Linha curta do motivo: "Parcela vencida há 12 dias".
  final String textoMotivo;

  String get clienteId => item.cliente.id;
}

double _limitar(double valor, double maximo) => valor > maximo ? maximo : valor;

/// Pontua [item] pela [regra]; `null` se não há motivo para visitar
/// (pontuação zero): quitado, sem atraso e que comprou recentemente.
///
/// Fatores (somam):
/// - **Atraso**: base + dias (até o teto) + saldo vencido (até o teto),
///   vezes o multiplicador de cobrança do score.
/// - **Vence na data**: peso fixo, vezes o multiplicador de cobrança.
/// - **Inatividade**: base + dias além do limite (até o teto), vezes o
///   multiplicador de reativação do score. Conta os dias até [data].
/// - **Nunca comprou**: peso fixo e baixo, sem score.
///
/// **Cliente bloqueado** (manual ou automático) entra só pela cobrança:
/// atraso e vencimento contam, inatividade e "nunca comprou" não. Não
/// faz sentido mandar o vendedor ao cliente para vender se o sistema
/// bloqueia a venda; mas cobrar continua necessário, e é justamente o
/// que desbloqueia o cliente. Bloqueado sem nada a cobrar fica de fora.
/// O motivo vira "Bloqueado: cobrar".
///
/// [data] é o dia da agenda e [hoje] só decide o texto ("Vence hoje" ou
/// "Vence nesta data").
Recomendacao? pontuarVisita(
  ItemAgenda item, {
  required RegraRecomendacao regra,
  required DateTime data,
  required DateTime hoje,
}) {
  final c = item.cliente;
  final cobranca = regra.cobrancaDo(c.score);

  var pontosAtraso = 0.0;
  if (item.vencida) {
    final dias = item.diasVencida > regra.diasAtrasoMaximo
        ? regra.diasAtrasoMaximo
        : item.diasVencida;
    final saldo = _limitar(item.saldoVencido, regra.saldoVencidoMaximo);
    pontosAtraso =
        (regra.pesoAtrasoBase +
            dias * regra.pesoAtrasoPorDia +
            saldo / 100 * regra.pesoSaldoVencidoPor100) *
        cobranca;
  }

  final pontosVence = item.vencendoNaData
      ? regra.pesoVenceNaData * cobranca
      : 0.0;

  var pontosReativacao = 0.0;
  var pontosNovo = 0.0;
  var diasSemComprar = 0;
  if (!item.bloqueado) {
    final ultima = c.ultimaCompra;
    if (ultima == null) {
      pontosNovo = regra.pesoNuncaComprou;
    } else {
      diasSemComprar = diasEntre(data, ultima);
      if (diasSemComprar >= regra.diasInatividade) {
        final alem =
            (diasSemComprar > regra.diasInatividadeMaximo
                ? regra.diasInatividadeMaximo
                : diasSemComprar) -
            regra.diasInatividade;
        pontosReativacao =
            (regra.pesoInatividadeBase + alem * regra.pesoInatividadePorDia) *
            regra.reativacaoDo(c.score);
      }
    }
  }

  final total = pontosAtraso + pontosVence + pontosReativacao + pontosNovo;
  if (total <= 0) return null;

  // Motivo principal: o fator que mais pesa. Empate: cobrar vem antes de
  // vender (atraso, vence, reativação, novo).
  var motivo = MotivoVisita.cobrancaEmAtraso;
  var maior = pontosAtraso;
  for (final (m, p) in [
    (MotivoVisita.venceNaData, pontosVence),
    (MotivoVisita.reativacao, pontosReativacao),
    (MotivoVisita.clienteNovo, pontosNovo),
  ]) {
    if (p > maior) {
      motivo = m;
      maior = p;
    }
  }

  final venceHoje = diasEntre(data, hoje) == 0;
  final textoVence = venceHoje ? 'Vence hoje' : 'Vence nesta data';
  final textoAtraso =
      'Parcela vencida há ${item.diasVencida} '
      '${item.diasVencida == 1 ? 'dia' : 'dias'}';

  final texto = switch (motivo) {
    MotivoVisita.cobrancaEmAtraso => textoAtraso,
    MotivoVisita.venceNaData => textoVence,
    MotivoVisita.reativacao =>
      'Sem comprar há $diasSemComprar ${diasSemComprar == 1 ? 'dia' : 'dias'}',
    MotivoVisita.clienteNovo => 'Ainda não comprou',
    MotivoVisita.bloqueadoCobrar => '',
  };

  if (item.bloqueado) {
    // Só cobrança pode ter pontuado: o motivo é atraso ou vence.
    final detalhe = motivo == MotivoVisita.venceNaData
        ? textoVence
        : textoAtraso;
    return Recomendacao(
      item: item,
      pontos: total,
      motivo: MotivoVisita.bloqueadoCobrar,
      textoMotivo: 'Bloqueado: cobrar · ${detalhe.toLowerCase()}',
    );
  }

  return Recomendacao(
    item: item,
    pontos: total,
    motivo: motivo,
    textoMotivo: texto,
  );
}

/// Recomendações de [itens] (a agenda da data e da rota): todos os que
/// têm pontuação, do mais prioritário ao menos, sem os [dispensados].
/// Empate de pontos desempata por nome (sem acento) e depois pelo id.
///
/// Com [itens] de uma rota específica só aparecem clientes dela; com
/// todas as rotas, de todas: quem filtra a rota é a montagem da agenda.
List<Recomendacao> recomendarVisitas(
  Iterable<ItemAgenda> itens, {
  required RegraRecomendacao regra,
  required DateTime data,
  required DateTime hoje,
  Set<String> dispensados = const {},
}) {
  final lista = <Recomendacao>[];
  for (final i in itens) {
    if (dispensados.contains(i.cliente.id)) continue;
    final r = pontuarVisita(i, regra: regra, data: data, hoje: hoje);
    if (r != null) lista.add(r);
  }
  lista.sort((a, b) {
    final porPontos = b.pontos.compareTo(a.pontos);
    if (porPontos != 0) return porPontos;
    final porNome = normalizarBusca(a.item.cliente.nome)
        .compareTo(normalizarBusca(b.item.cliente.nome));
    return porNome != 0 ? porNome : a.clienteId.compareTo(b.clienteId);
  });
  return lista;
}

/// Os melhores [RegraRecomendacao.quantidade] de [recomendacoes] (já
/// ordenadas).
List<Recomendacao> melhoresRecomendacoes(
  List<Recomendacao> recomendacoes,
  RegraRecomendacao regra,
) => recomendacoes.length <= regra.quantidade
    ? recomendacoes
    : recomendacoes.sublist(0, regra.quantidade);

/// Filtro por motivo (`null` = todos) e busca por nome (sem acento, sem
/// diferenciar maiúsculas) da lista completa.
List<Recomendacao> filtrarRecomendacoes(
  Iterable<Recomendacao> recomendacoes, {
  MotivoVisita? motivo,
  String termo = '',
}) {
  final busca = normalizarBusca(termo.trim());
  return [
    for (final r in recomendacoes)
      if ((motivo == null || r.motivo == motivo) &&
          (busca.isEmpty ||
              normalizarBusca(r.item.cliente.nome).contains(busca)))
        r,
  ];
}

/// Motivos que aparecem em [recomendacoes], na ordem do enum, para os
/// chips de filtro.
List<MotivoVisita> motivosPresentes(Iterable<Recomendacao> recomendacoes) {
  final presentes = {for (final r in recomendacoes) r.motivo};
  return [
    for (final m in MotivoVisita.values)
      if (presentes.contains(m)) m,
  ];
}
