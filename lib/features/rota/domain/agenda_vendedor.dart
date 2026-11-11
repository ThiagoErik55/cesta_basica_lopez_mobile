import '../../../core/utils/texto.dart';
import '../../cliente/data/cliente_model.dart';
import '../../cliente/domain/bloqueio_cliente.dart';
import '../../cliente/domain/regra_bloqueio.dart';
import '../../venda/data/parcela_model.dart';
import '../../venda/domain/controle_promissorias.dart';
import '../data/rota_model.dart';
import 'associacao_rota.dart';

// Agenda do vendedor por data (KAN-47). Tudo aqui é derivado na leitura:
// nada é gravado. A agenda mostra os clientes ativos da rota escolhida e
// destaca quem tem parcela vencendo ou vencida na data escolhida.

/// Dia de calendário local de [data], sem hora. Datas em UTC (ou vindas
/// do servidor com fuso) são convertidas para o horário local antes de
/// pegar o dia, então uma parcela de "23:30" ou "00:10" cai no dia certo
/// do vendedor e a virada do dia não desloca vencimentos.
DateTime soData(DateTime data) {
  final l = data.toLocal();
  return DateTime(l.year, l.month, l.day);
}

/// Dias de calendário de [a] depois de [b] (negativo se antes), ignorando
/// a hora e o horário de verão.
int diasEntre(DateTime a, DateTime b) {
  final x = soData(a);
  final y = soData(b);
  return DateTime.utc(
    x.year,
    x.month,
    x.day,
  ).difference(DateTime.utc(y.year, y.month, y.day)).inDays;
}

int _centavos(double valor) => (valor * 100).round();

/// Filtros rápidos da agenda.
///
/// - `aCobrar`: parcela vencendo na data ou já vencida nela.
/// - `emAtraso`: parcela vencida **em relação à data escolhida** (não à
///   data de hoje): olhando uma data futura, entram também as que vão
///   estar vencidas até lá.
/// - `bloqueados`: bloqueio manual ou automático (KAN-35).
enum FiltroAgenda { todos, aCobrar, emAtraso, bloqueados }

extension RotuloFiltroAgenda on FiltroAgenda {
  String get rotulo => switch (this) {
    FiltroAgenda.todos => 'Todos',
    FiltroAgenda.aCobrar => 'A cobrar',
    FiltroAgenda.emAtraso => 'Em atraso',
    FiltroAgenda.bloqueados => 'Bloqueados',
  };
}

/// Um cliente na agenda de uma data, com o que a lista mostra.
class ItemAgenda {
  const ItemAgenda({
    required this.cliente,
    required this.rotaId,
    required this.rotaNome,
    required this.situacao,
    required this.vencendoNaData,
    required this.diasVencida,
    required this.aReceber,
    required this.valoresPorParcela,
  });

  final ClienteModel cliente;

  /// Rota **ativa** do cliente; `null` = "Sem rota" (inclui rota
  /// excluída ou inexistente).
  final String? rotaId;
  final String? rotaNome;

  /// Status de pagamento (com o bloqueio automático, KAN-35) e o motivo.
  final SituacaoCliente situacao;

  /// Tem parcela pendente que vence exatamente na data escolhida.
  final bool vencendoNaData;

  /// Dias de atraso da parcela mais atrasada na data escolhida; 0 se não
  /// tem parcela vencida nela.
  final int diasVencida;

  /// Soma do saldo das parcelas pendentes com vencimento até a data
  /// escolhida (as vencidas e as que vencem nela).
  final double aReceber;

  /// `true` quando os números vêm das parcelas; `false` quando as
  /// parcelas não estavam disponíveis e foram estimados pelo resumo do
  /// cliente (`proximoVencimento`), sem [aReceber].
  final bool valoresPorParcela;

  bool get vencida => diasVencida > 0;
  bool get aCobrar => vencendoNaData || vencida;
  bool get bloqueado => situacao.bloqueado;
}

/// Monta a agenda de [data] para a rota [rotaId] (`null` = todas as
/// rotas).
///
/// - Só clientes ativos. Bloqueado ou inadimplente entra: a agenda serve
///   justamente para cobrar.
/// - Rota excluída ou inexistente conta como "sem rota": com [rotaId]
///   específico o cliente não aparece; com todas as rotas, vai para o
///   grupo "Sem rota".
/// - [parcelasPendentesPorCliente] (id do cliente → parcelas pendentes)
///   dá a precisão por parcela; `null` quando ainda não carregaram, caso
///   em que a agenda usa `proximoVencimento` e `valorEmAberto` do cliente
///   (e não calcula [ItemAgenda.aReceber]).
/// - [agora] só define o status de pagamento (que é "de hoje"); o
///   destaque de vencimento usa [data], por dia de calendário local.
List<ItemAgenda> montarAgenda({
  required Iterable<ClienteModel> clientes,
  required Iterable<RotaModel> rotas,
  required DateTime data,
  String? rotaId,
  Map<String, List<ParcelaModel>>? parcelasPendentesPorCliente,
  required RegraBloqueio regra,
  required DateTime agora,
}) {
  final dia = soData(data);
  final itens = <ItemAgenda>[];

  for (final c in clientes) {
    if (c.deleted) continue;
    final rota = rotaValida(c.rotaId, rotas);
    if (rotaId != null && rota != rotaId) continue;

    final porParcela = parcelasPendentesPorCliente != null;
    final pendentes = [
      for (final p
          in parcelasPendentesPorCliente?[c.id] ?? const <ParcelaModel>[])
        if (!p.pago && !p.deleted) p,
    ];

    var vencendo = false;
    var maiorAtraso = 0;
    var receberCentavos = 0;
    if (porParcela) {
      for (final p in pendentes) {
        final dias = diasEntre(dia, p.vencimento);
        if (dias == 0) vencendo = true;
        if (dias > maiorAtraso) maiorAtraso = dias;
        if (dias >= 0) receberCentavos += _centavos(p.saldo);
      }
    } else {
      // Sem as parcelas: o menor vencimento pendente é o do resumo.
      final v = c.proximoVencimento;
      if (v != null && c.temDebito) {
        final dias = diasEntre(dia, v);
        vencendo = dias == 0;
        if (dias > 0) maiorAtraso = dias;
      }
    }

    final situacao = porParcela
        ? situacaoDoCliente(
            c,
            avaliarBloqueio(
              cliente: c,
              parcelasPendentes: pendentes,
              agora: agora,
              regra: regra,
            ),
            agora: agora,
          )
        : situacaoDoClientePeloResumo(c, regra: regra, agora: agora);

    itens.add(
      ItemAgenda(
        cliente: c,
        rotaId: rota,
        rotaNome: nomeDaRota(rota, rotas),
        situacao: situacao,
        vencendoNaData: vencendo,
        diasVencida: maiorAtraso,
        aReceber: receberCentavos / 100,
        valoresPorParcela: porParcela,
      ),
    );
  }
  return itens;
}

/// Parcelas pendentes de cada cliente, agrupadas a partir dos itens de
/// promissória (um único stream de vendas parceladas, o mesmo da tela de
/// Promissórias). Cliente sem parcela pendente não aparece no mapa.
Map<String, List<ParcelaModel>> parcelasPendentesPorCliente(
  Iterable<ItemPromissoria> itens,
) {
  final mapa = <String, List<ParcelaModel>>{};
  for (final i in itens) {
    for (final p in i.promissoria.parcelas) {
      if (p.pago || p.deleted) continue;
      mapa.putIfAbsent(i.venda.clienteId, () => []).add(p);
    }
  }
  return mapa;
}

/// Totais do topo da agenda.
class ResumoAgenda {
  const ResumoAgenda({
    required this.totalClientes,
    required this.vencendoNaData,
    required this.emAtraso,
    required this.aReceber,
    required this.valoresExatos,
  });

  final int totalClientes;

  /// Clientes com parcela vencendo exatamente na data.
  final int vencendoNaData;

  /// Clientes com parcela vencida em relação à data.
  final int emAtraso;

  /// Soma das parcelas pendentes com vencimento até a data, desses
  /// clientes.
  final double aReceber;

  /// `false` se alguma entrada foi estimada sem as parcelas: [aReceber]
  /// está incompleto e a tela mostra "—".
  final bool valoresExatos;
}

/// Resume [itens] (a agenda da data e da rota, antes de busca e filtros).
ResumoAgenda resumirAgenda(Iterable<ItemAgenda> itens) {
  var total = 0;
  var vencendo = 0;
  var atraso = 0;
  var receber = 0;
  var exatos = true;
  for (final i in itens) {
    total++;
    if (i.vencendoNaData) vencendo++;
    if (i.vencida) atraso++;
    receber += _centavos(i.aReceber);
    if (!i.valoresPorParcela) exatos = false;
  }
  return ResumoAgenda(
    totalClientes: total,
    vencendoNaData: vencendo,
    emAtraso: atraso,
    aReceber: receber / 100,
    valoresExatos: exatos,
  );
}

/// Filtro rápido e busca por nome (sem acento, sem diferenciar
/// maiúsculas; contém o termo).
List<ItemAgenda> filtrarAgenda(
  Iterable<ItemAgenda> itens, {
  FiltroAgenda filtro = FiltroAgenda.todos,
  String termo = '',
}) {
  final busca = normalizarBusca(termo.trim());
  return [
    for (final i in itens)
      if (switch (filtro) {
            FiltroAgenda.todos => true,
            FiltroAgenda.aCobrar => i.aCobrar,
            FiltroAgenda.emAtraso => i.vencida,
            FiltroAgenda.bloqueados => i.bloqueado,
          } &&
          (busca.isEmpty || normalizarBusca(i.cliente.nome).contains(busca)))
        i,
  ];
}

/// Ordem padrão: com parcela vencida primeiro (mais dias de atraso antes),
/// depois quem tem parcela vencendo na data, depois os demais por nome.
List<ItemAgenda> ordenarAgenda(Iterable<ItemAgenda> itens) {
  int grupo(ItemAgenda i) => i.vencida
      ? 0
      : i.vencendoNaData
      ? 1
      : 2;

  return itens.toList()..sort((a, b) {
    final porGrupo = grupo(a).compareTo(grupo(b));
    if (porGrupo != 0) return porGrupo;
    if (a.vencida) {
      final porAtraso = b.diasVencida.compareTo(a.diasVencida);
      if (porAtraso != 0) return porAtraso;
    }
    final porNome = normalizarBusca(a.cliente.nome)
        .compareTo(normalizarBusca(b.cliente.nome));
    return porNome != 0 ? porNome : a.cliente.id.compareTo(b.cliente.id);
  });
}

/// Título do grupo dos clientes sem rota.
const String tituloSemRota = 'Sem rota';

/// Um grupo da lista quando todas as rotas estão escolhidas.
class GrupoAgenda {
  const GrupoAgenda({
    required this.rotaId,
    required this.titulo,
    required this.itens,
  });

  /// `null` = grupo "Sem rota".
  final String? rotaId;
  final String titulo;
  final List<ItemAgenda> itens;
}

/// Agrupa por rota: grupos pelo nome da rota (sem acento) e "Sem rota" por
/// último; dentro de cada grupo vale [ordenarAgenda]. Grupo vazio não
/// aparece.
List<GrupoAgenda> agruparAgendaPorRota(Iterable<ItemAgenda> itens) {
  final porRota = <String?, List<ItemAgenda>>{};
  final nomes = <String?, String>{};
  for (final i in itens) {
    porRota.putIfAbsent(i.rotaId, () => []).add(i);
    nomes[i.rotaId] = i.rotaNome ?? tituloSemRota;
  }
  final chaves = porRota.keys.toList()
    ..sort((a, b) {
      if (a == null) return b == null ? 0 : 1;
      if (b == null) return -1;
      final porNome = normalizarBusca(nomes[a]!)
          .compareTo(normalizarBusca(nomes[b]!));
      return porNome != 0 ? porNome : a.compareTo(b);
    });
  return [
    for (final k in chaves)
      GrupoAgenda(
        rotaId: k,
        titulo: nomes[k]!,
        itens: ordenarAgenda(porRota[k]!),
      ),
  ];
}

/// Destaques do cliente na data: "Vencida há 3 dias" e/ou "Vence nesta
/// data". Vazio se não há nada a destacar.
List<String> destaquesDaAgenda(ItemAgenda i) => [
  if (i.vencida)
    'Vencida há ${i.diasVencida} ${i.diasVencida == 1 ? 'dia' : 'dias'}',
  if (i.vencendoNaData) 'Vence nesta data',
];

const _diasDaSemana = [
  'Segunda',
  'Terça',
  'Quarta',
  'Quinta',
  'Sexta',
  'Sábado',
  'Domingo',
];

/// "Sábado, 14/11/2026".
String rotuloDaData(DateTime data) {
  final d = soData(data);
  String dois(int n) => n.toString().padLeft(2, '0');
  return '${_diasDaSemana[d.weekday - 1]}, ${dois(d.day)}/${dois(d.month)}/${d.year}';
}
