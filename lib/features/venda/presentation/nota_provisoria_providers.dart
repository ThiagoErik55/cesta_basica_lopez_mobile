import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../cliente/presentation/cliente_providers.dart';
import '../../produto/data/produto_repository.dart';
import '../data/nota_provisoria_pdf.dart';
import '../data/parcela_model.dart';
import '../domain/nota_provisoria.dart';
import 'pos_venda_providers.dart';

/// Nota provisória pronta: os dados, o PDF e o nome do arquivo.
class NotaGerada {
  const NotaGerada({
    required this.nota,
    required this.bytes,
    required this.nomeArquivo,
  });

  final NotaProvisoria nota;
  final Uint8List bytes;
  final String nomeArquivo;
}

/// Falha com mensagem própria para o vendedor (venda sem itens, cliente
/// ausente, falha ao gerar o PDF...).
class NotaIndisponivel implements Exception {
  const NotaIndisponivel(this.mensagem);

  final String mensagem;

  @override
  String toString() => 'NotaIndisponivel: $mensagem';
}

/// Códigos dos produtos de [produtoIds]. O item da venda guarda só o
/// nome, então o código vem do cadastro. A consulta é opcional: produto
/// removido, ausente do cache offline ou que demore mais de 3 segundos
/// fica sem código, e a nota sai do mesmo jeito.
Future<Map<String, String>> _buscarCodigos(
  ProdutoRepository repositorio,
  Set<String> produtoIds,
) async {
  final codigos = <String, String>{};
  await Future.wait([
    for (final id in produtoIds)
      () async {
        try {
          final produto = await repositorio
              .buscarPorId(id)
              .timeout(const Duration(seconds: 3));
          if (produto != null) codigos[id] = produto.codigo;
        } catch (e) {
          debugPrint('Código do produto $id indisponível: $e');
        }
      }(),
  ]);
  return codigos;
}

/// Monta os dados e gera o PDF da nota provisória da venda [vendaId]
/// (KAN-37).
///
/// Lê venda, parcelas e cliente dos listeners do Firestore, então
/// funciona offline com o que já está no cache local, e gera o PDF no
/// aparelho, sem chamada de rede.
///
/// Sem repetição automática (`retry`): as falhas daqui são definitivas
/// (venda sem itens, cliente ausente, PDF que não gera), e o Riverpod 3
/// repetiria com espera crescente, deixando a tela carregando em vez de
/// mostrar o erro.
final notaProvisoriaProvider = FutureProvider.autoDispose
    .family<NotaGerada, String>((ref, vendaId) async {
      final venda = await ref.watch(vendaPorIdProvider(vendaId).future);
      if (venda == null) {
        throw const NotaIndisponivel('Venda não encontrada.');
      }
      final parcelas = venda.ehPromissoria
          ? await ref.watch(parcelasDaVendaProvider(vendaId).future)
          : const <ParcelaModel>[];
      final cliente = await ref.watch(
        clientePorIdProvider(venda.clienteId).future,
      );
      final codigos = await _buscarCodigos(
        ref.read(produtoRepositoryProvider),
        {for (final i in venda.itens) i.produtoId},
      );

      final resultado = montarNotaProvisoria(
        cliente: cliente,
        venda: venda,
        itens: venda.itens,
        parcelas: parcelas,
        codigos: codigos,
      );
      final nota = resultado.nota;
      if (nota == null) {
        throw NotaIndisponivel(resultado.erro ?? 'Nota indisponível.');
      }

      try {
        return NotaGerada(
          nota: nota,
          bytes: await gerarPdfNotaProvisoria(nota),
          nomeArquivo: nomeArquivoNota(nota),
        );
      } catch (e, st) {
        debugPrint('Erro ao gerar o PDF da nota provisória: $e\n$st');
        throw const NotaIndisponivel(
          'Não foi possível gerar o PDF da nota provisória.',
        );
      }
    }, retry: (_, _) => null);
