import '../../../core/domain/enums.dart';
import '../../../core/utils/texto.dart';
import '../../cliente/data/cliente_model.dart';
import '../data/rota_model.dart';

/// Limites do nome da rota (KAN-45), em caracteres, já sem os espaços
/// das pontas.
const int nomeRotaMinimo = 2;
const int nomeRotaMaximo = 60;

/// Dados preenchidos no formulário de rota. `codigo` não entra: é gerado
/// a partir do id (como o código do produto e do cliente).
class DadosCadastraisRota {
  const DadosCadastraisRota({required this.nome, required this.linha});

  final String nome;
  final LinhaAtendimento linha;
}

extension RotuloLinhaAtendimento on LinhaAtendimento {
  String get rotulo => switch (this) {
    LinhaAtendimento.toledo => 'Toledo',
    LinhaAtendimento.regional => 'Regional',
  };
}

/// Nome sem espaços nas pontas e sem espaços repetidos no meio.
String limparNomeRota(String nome) =>
    nome.trim().split(RegExp(r'\s+')).join(' ');

/// Chave de comparação de nomes: sem acento, sem diferenciar maiúsculas
/// e sem espaços repetidos.
String chaveNomeRota(String nome) => normalizarBusca(limparNomeRota(nome));

/// Valida o nome digitado. Devolve a mensagem de erro ou `null` se está
/// ok.
///
/// - Obrigatório, de [nomeRotaMinimo] a [nomeRotaMaximo] caracteres.
/// - Não pode repetir o nome de outra rota **ativa** (rotas excluídas
///   são ignoradas), sem diferenciar acento nem maiúsculas.
/// - [idAtual] é a rota em edição: ela não conta como duplicada de si
///   mesma, então salvar sem mudar o nome (ou mudando só a caixa) passa.
String? validarNomeRota(
  String nome, {
  required Iterable<RotaModel> rotas,
  String? idAtual,
}) {
  final limpo = limparNomeRota(nome);
  if (limpo.isEmpty) return 'Informe o nome da rota.';
  if (limpo.length < nomeRotaMinimo) {
    return 'O nome deve ter pelo menos $nomeRotaMinimo caracteres.';
  }
  if (limpo.length > nomeRotaMaximo) {
    return 'O nome deve ter no máximo $nomeRotaMaximo caracteres.';
  }
  final chave = chaveNomeRota(limpo);
  final duplicada = rotas.any(
    (r) => !r.deleted && r.id != idAtual && chaveNomeRota(r.nome) == chave,
  );
  return duplicada ? 'Já existe uma rota com esse nome.' : null;
}

/// Rota com a quantidade de clientes associados.
class ItemRota {
  const ItemRota({required this.rota, required this.clientes});

  final RotaModel rota;

  /// Clientes ativos com `rotaId` igual ao da rota; `null` quando a lista
  /// de clientes ainda não carregou (ou falhou): a contagem é
  /// desconhecida, e não zero.
  final int? clientes;
}

/// Clientes ativos por rota (`rotaId`), contados em memória a partir de
/// uma única leitura da coleção de clientes. Cliente sem rota (`null` ou
/// vazio) e cliente excluído não contam.
Map<String, int> contarClientesPorRota(Iterable<ClienteModel> clientes) {
  final contagem = <String, int>{};
  for (final c in clientes) {
    final rotaId = c.rotaId;
    if (c.deleted || rotaId == null || rotaId.isEmpty) continue;
    contagem.update(rotaId, (n) => n + 1, ifAbsent: () => 1);
  }
  return contagem;
}

/// Rotas ativas, por nome (sem acento), com a contagem de clientes.
/// [clientes] `null` = ainda sem dados: a contagem fica desconhecida.
List<ItemRota> montarItensRota(
  Iterable<RotaModel> rotas,
  Iterable<ClienteModel>? clientes,
) {
  final contagem = clientes == null ? null : contarClientesPorRota(clientes);
  final itens = [
    for (final r in rotas)
      if (!r.deleted)
        ItemRota(
          rota: r,
          clientes: contagem == null ? null : contagem[r.id] ?? 0,
        ),
  ];
  itens.sort((a, b) {
    final porNome = chaveNomeRota(a.rota.nome)
        .compareTo(chaveNomeRota(b.rota.nome));
    return porNome != 0 ? porNome : a.rota.id.compareTo(b.rota.id);
  });
  return itens;
}

/// Busca por nome (contém), sem acento nem diferença de maiúsculas.
List<ItemRota> filtrarRotas(List<ItemRota> itens, String termo) {
  final busca = normalizarBusca(termo.trim());
  if (busca.isEmpty) return itens;
  return [
    for (final i in itens)
      if (normalizarBusca(i.rota.nome).contains(busca)) i,
  ];
}

/// Nomes dos clientes ativos da rota, em ordem alfabética (sem acento).
List<String> nomesDosClientesDaRota(
  String rotaId,
  Iterable<ClienteModel> clientes,
) {
  final nomes = [
    for (final c in clientes)
      if (!c.deleted && c.rotaId == rotaId) c.nome,
  ];
  nomes.sort((a, b) => normalizarBusca(a).compareTo(normalizarBusca(b)));
  return nomes;
}

/// Regra de exclusão de rota (KAN-45): **bloqueada enquanto houver
/// clientes associados**. É a opção mais segura: excluir e desassociar os
/// clientes em silêncio tiraria da agenda clientes que o vendedor não
/// sabe que perderam a rota, e exigiria alterar documentos de cliente em
/// batch (fora do escopo desta task). O vendedor remove ou muda os
/// clientes de rota antes.
///
/// Devolve a mensagem do bloqueio ou `null` se pode excluir.
/// [clientes] `null` (contagem desconhecida) também bloqueia: sem saber
/// quantos clientes há, não dá para garantir que a rota está vazia.
String? motivoBloqueioExclusaoRota(int? clientes) {
  if (clientes == null) {
    return 'Não foi possível conferir os clientes desta rota. '
        'Tente de novo quando a lista carregar.';
  }
  if (clientes <= 0) return null;
  return clientes == 1
      ? 'Remova ou mude o cliente desta rota antes de excluir.'
      : 'Remova ou mude os $clientes clientes desta rota antes de excluir.';
}

/// "3 clientes", "1 cliente", "Nenhum cliente" ou `null` se desconhecida.
String? textoClientesDaRota(int? clientes) {
  if (clientes == null) return null;
  if (clientes == 0) return 'Nenhum cliente';
  return clientes == 1 ? '1 cliente' : '$clientes clientes';
}
