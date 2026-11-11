import '../../../core/utils/cpf.dart';
import '../../../core/utils/texto.dart';
import '../../cliente/data/cliente_model.dart';
import '../data/rota_model.dart';

/// Máximo de operações por batch do Firestore usado na associação (o
/// limite do servidor é 500; 450 deixa folga).
const int limiteOperacoesPorLote = 450;

/// Divide [itens] em lotes de no máximo [tamanho] elementos, mantendo a
/// ordem. Lista vazia devolve nenhum lote.
List<List<T>> dividirEmLotes<T>(
  List<T> itens, {
  int tamanho = limiteOperacoesPorLote,
}) {
  assert(tamanho > 0, 'O tamanho do lote deve ser maior que zero.');
  return [
    for (var i = 0; i < itens.length; i += tamanho)
      itens.sublist(i, i + tamanho > itens.length ? itens.length : i + tamanho),
  ];
}

/// Rota "de verdade" do cliente: o `rotaId` só vale se é de uma rota
/// **ativa** em [rotas]. Texto livre (o formulário antigo gravava texto),
/// rota excluída ou inexistente viram `null`, ou seja, "Sem rota".
String? rotaValida(String? rotaId, Iterable<RotaModel> rotas) {
  if (rotaId == null || rotaId.isEmpty) return null;
  for (final r in rotas) {
    if (!r.deleted && r.id == rotaId) return rotaId;
  }
  return null;
}

/// Nome da rota ativa do cliente; `null` se está sem rota (ou aponta para
/// rota excluída/inexistente).
String? nomeDaRota(String? rotaId, Iterable<RotaModel> rotas) {
  final valida = rotaValida(rotaId, rotas);
  if (valida == null) return null;
  return rotas.firstWhere((r) => r.id == valida).nome;
}

/// Onde o cliente está em relação à rota que está sendo editada.
enum SituacaoNaRota { semRota, destaRota, outraRota }

SituacaoNaRota situacaoNaRota(
  ClienteModel cliente, {
  required String rotaId,
  required Iterable<RotaModel> rotas,
}) {
  final valida = rotaValida(cliente.rotaId, rotas);
  if (valida == null) return SituacaoNaRota.semRota;
  return valida == rotaId ? SituacaoNaRota.destaRota : SituacaoNaRota.outraRota;
}

/// Filtros rápidos do sheet de associação.
enum FiltroAssociacao { todos, semRota, destaRota, deOutrasRotas }

extension RotuloFiltroAssociacao on FiltroAssociacao {
  String get rotulo => switch (this) {
    FiltroAssociacao.todos => 'Todos',
    FiltroAssociacao.semRota => 'Sem rota',
    FiltroAssociacao.destaRota => 'Desta rota',
    FiltroAssociacao.deOutrasRotas => 'De outras rotas',
  };
}

/// Clientes ativos que o sheet de associação lista, pelo [filtro] e pela
/// busca, em ordem alfabética (sem acento).
///
/// - Cliente com `deleted` nunca aparece. Bloqueado ou inadimplente
///   aparece normalmente: a rota é só um agrupamento.
/// - [termo]: nome (contém, sem acento nem diferença de maiúsculas) ou
///   CPF parcial. O CPF só é comparado quando o termo não tem letras
///   (assim "ana 12" não casa com qualquer CPF que contenha 12).
List<ClienteModel> filtrarClientesParaAssociacao(
  Iterable<ClienteModel> clientes, {
  required String rotaId,
  required Iterable<RotaModel> rotas,
  FiltroAssociacao filtro = FiltroAssociacao.todos,
  String termo = '',
}) {
  final busca = normalizarBusca(termo.trim());
  final digitos = apenasDigitos(termo);
  final pareceCpf =
      digitos.isNotEmpty && !RegExp(r'[^\d\s.\-/]').hasMatch(termo.trim());

  bool passaNoFiltro(ClienteModel c) {
    final s = situacaoNaRota(c, rotaId: rotaId, rotas: rotas);
    return switch (filtro) {
      FiltroAssociacao.todos => true,
      FiltroAssociacao.semRota => s == SituacaoNaRota.semRota,
      FiltroAssociacao.destaRota => s == SituacaoNaRota.destaRota,
      FiltroAssociacao.deOutrasRotas => s == SituacaoNaRota.outraRota,
    };
  }

  bool passaNaBusca(ClienteModel c) {
    if (busca.isEmpty) return true;
    if (normalizarBusca(c.nome).contains(busca)) return true;
    return pareceCpf && apenasDigitos(c.cpf).contains(digitos);
  }

  final lista = [
    for (final c in clientes)
      if (!c.deleted && passaNoFiltro(c) && passaNaBusca(c)) c,
  ];
  lista.sort((a, b) {
    final porNome = normalizarBusca(a.nome).compareTo(normalizarBusca(b.nome));
    return porNome != 0 ? porNome : a.id.compareTo(b.id);
  });
  return lista;
}

/// O que a seleção do sheet vai mudar na rota (ids de cliente).
class DiffAssociacao {
  const DiffAssociacao({
    this.adicionados = const [],
    this.movidos = const [],
    this.removidos = const [],
    this.inalterados = const [],
  });

  /// Estavam sem rota e passam a ter esta.
  final List<String> adicionados;

  /// Estavam em OUTRA rota e passam para esta.
  final List<String> movidos;

  /// Estavam nesta rota e ficam sem rota.
  final List<String> removidos;

  /// Já estavam como ficaram: não são gravados.
  final List<String> inalterados;

  /// Clientes que entram na rota (de sem rota ou de outra).
  int get associados => adicionados.length + movidos.length;

  bool get semMudancas => associados == 0 && removidos.isEmpty;

  /// `clienteId → novo rotaId` só dos clientes que mudam.
  Map<String, String?> novasRotas(String rotaId) => {
    for (final id in adicionados) id: rotaId,
    for (final id in movidos) id: rotaId,
    for (final id in removidos) id: null,
  };
}

/// Compara o estado atual com a seleção do usuário.
///
/// [marcas] guarda só as escolhas explícitas (`id → marcado`). Cliente
/// sem marca fica como está: quem já era desta rota continua nela, e
/// quem não era, não entra. Assim, um cliente que outro aparelho colocou
/// nesta rota com o sheet aberto não é removido sem querer.
DiffAssociacao calcularDiffAssociacao({
  required Iterable<ClienteModel> clientes,
  required Map<String, bool> marcas,
  required String rotaId,
  required Iterable<RotaModel> rotas,
}) {
  final adicionados = <String>[];
  final movidos = <String>[];
  final removidos = <String>[];
  final inalterados = <String>[];

  for (final c in clientes) {
    if (c.deleted) continue;
    final situacao = situacaoNaRota(c, rotaId: rotaId, rotas: rotas);
    final marcado = marcas[c.id] ?? situacao == SituacaoNaRota.destaRota;
    switch ((situacao, marcado)) {
      case (SituacaoNaRota.semRota, true):
        adicionados.add(c.id);
      case (SituacaoNaRota.outraRota, true):
        movidos.add(c.id);
      case (SituacaoNaRota.destaRota, false):
        removidos.add(c.id);
      default:
        inalterados.add(c.id);
    }
  }
  return DiffAssociacao(
    adicionados: adicionados,
    movidos: movidos,
    removidos: removidos,
    inalterados: inalterados,
  );
}

/// Resumo antes de confirmar: "+3 associados, −1 removido, 1 movido de
/// outra rota". Partes zeradas ficam de fora.
String resumoDaAssociacao(DiffAssociacao d) {
  if (d.semMudancas) return 'Nenhuma alteração.';
  final partes = <String>[];
  if (d.associados > 0) {
    partes.add(
      '+${d.associados} ${d.associados == 1 ? 'associado' : 'associados'}',
    );
  }
  if (d.removidos.isNotEmpty) {
    final n = d.removidos.length;
    partes.add('−$n ${n == 1 ? 'removido' : 'removidos'}');
  }
  if (d.movidos.isNotEmpty) {
    final n = d.movidos.length;
    partes.add('$n ${n == 1 ? 'movido' : 'movidos'} de outra rota');
  }
  return partes.join(', ');
}

/// Aviso da confirmação final quando há clientes vindos de outras rotas;
/// `null` sem movimentos.
String? avisoDeMovidos(DiffAssociacao d) {
  final n = d.movidos.length;
  if (n == 0) return null;
  return n == 1
      ? '1 cliente será movido de outra rota para esta.'
      : '$n clientes serão movidos de outras rotas para esta.';
}

/// Mensagem de sucesso: "3 clientes associados à rota Centro.".
String mensagemAssociacaoConcluida(DiffAssociacao d, String nomeRota) {
  final a = d.associados;
  final r = d.removidos.length;
  String clientes(int n) => n == 1 ? '1 cliente' : '$n clientes';
  if (a > 0 && r == 0) {
    return '${clientes(a)} ${a == 1 ? 'associado' : 'associados'} '
        'à rota $nomeRota.';
  }
  if (a == 0 && r > 0) {
    return '${clientes(r)} ${r == 1 ? 'removido' : 'removidos'} '
        'da rota $nomeRota.';
  }
  return '${clientes(a)} ${a == 1 ? 'associado' : 'associados'} e '
      '${clientes(r)} ${r == 1 ? 'removido' : 'removidos'} na rota $nomeRota.';
}

/// Filtro por rota na listagem de clientes (KAN-46): todas, sem rota ou
/// uma rota específica. Tem igualdade por valor para o `FilterChipBar`
/// reconhecer a opção selecionada.
class FiltroRotaCliente {
  const FiltroRotaCliente.todas() : rotaId = null, semRota = false;
  const FiltroRotaCliente.semRota() : rotaId = null, semRota = true;
  const FiltroRotaCliente.daRota(String this.rotaId) : semRota = false;

  final String? rotaId;
  final bool semRota;

  bool get ativo => semRota || rotaId != null;

  @override
  bool operator ==(Object other) =>
      other is FiltroRotaCliente &&
      other.rotaId == rotaId &&
      other.semRota == semRota;

  @override
  int get hashCode => Object.hash(rotaId, semRota);
}

/// Se [cliente] passa no filtro de rota da listagem. "Sem rota" inclui o
/// cliente que aponta para rota excluída ou inexistente.
///
/// [rotas] `null` (ainda não carregaram): só dá para decidir pelo valor
/// cru de `rotaId`, então "Sem rota" vale para `rotaId` vazio.
bool clientePassaNoFiltroDeRota(
  ClienteModel cliente,
  FiltroRotaCliente filtro,
  Iterable<RotaModel>? rotas,
) {
  if (!filtro.ativo) return true;
  final valida = rotas == null
      ? ((cliente.rotaId ?? '').isEmpty ? null : cliente.rotaId)
      : rotaValida(cliente.rotaId, rotas);
  return filtro.semRota ? valida == null : valida == filtro.rotaId;
}
