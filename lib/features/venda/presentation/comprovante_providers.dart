import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../cliente/presentation/cliente_providers.dart';
import '../data/comprovante_pdf.dart';
import '../domain/comprovante_pagamento.dart';
import 'pos_venda_providers.dart';

/// Identifica o pagamento de um comprovante: venda, parcela e pagamento.
/// Vai como argumento da rota do comprovante.
@immutable
class ComprovanteArgs {
  const ComprovanteArgs({
    required this.vendaId,
    required this.parcelaId,
    required this.pagamentoId,
  });

  final String vendaId;
  final String parcelaId;
  final String pagamentoId;

  @override
  bool operator ==(Object other) =>
      other is ComprovanteArgs &&
      other.vendaId == vendaId &&
      other.parcelaId == parcelaId &&
      other.pagamentoId == pagamentoId;

  @override
  int get hashCode => Object.hash(vendaId, parcelaId, pagamentoId);
}

/// Comprovante pronto: os dados, o PDF e o nome do arquivo.
class ComprovanteGerado {
  const ComprovanteGerado({
    required this.comprovante,
    required this.bytes,
    required this.nomeArquivo,
  });

  final ComprovantePagamento comprovante;
  final Uint8List bytes;
  final String nomeArquivo;
}

/// Falha com mensagem própria para o vendedor (pagamento não encontrado,
/// falha ao gerar o PDF...).
class ComprovanteIndisponivel implements Exception {
  const ComprovanteIndisponivel(this.mensagem);

  final String mensagem;

  @override
  String toString() => 'ComprovanteIndisponivel: $mensagem';
}

/// Monta os dados e gera o PDF do comprovante de [args] (KAN-36).
///
/// Lê venda, parcelas e cliente dos listeners do Firestore, então
/// funciona offline com o que já está no cache local, e gera o PDF no
/// aparelho, sem chamada de rede.
///
/// Sem repetição automática (`retry`): as falhas daqui são definitivas
/// (pagamento inexistente, PDF que não gera), e o Riverpod 3 repetiria
/// com espera crescente, deixando a tela carregando em vez de mostrar o
/// erro.
final comprovanteProvider = FutureProvider.autoDispose
    .family<ComprovanteGerado, ComprovanteArgs>((ref, args) async {
      final venda = await ref.watch(vendaPorIdProvider(args.vendaId).future);
      if (venda == null) {
        throw const ComprovanteIndisponivel('Venda não encontrada.');
      }
      final parcelas = await ref.watch(
        parcelasDaVendaProvider(args.vendaId).future,
      );
      final cliente = await ref.watch(
        clientePorIdProvider(venda.clienteId).future,
      );
      if (cliente == null) {
        throw const ComprovanteIndisponivel('Cliente não encontrado.');
      }

      final resultado = montarComprovantePagamento(
        cliente: cliente,
        venda: venda,
        parcelas: parcelas,
        parcelaId: args.parcelaId,
        pagamentoId: args.pagamentoId,
      );
      final comprovante = resultado.comprovante;
      if (comprovante == null) {
        throw ComprovanteIndisponivel(
          resultado.erro ?? 'Comprovante indisponível.',
        );
      }

      try {
        return ComprovanteGerado(
          comprovante: comprovante,
          bytes: await gerarPdfComprovante(comprovante),
          nomeArquivo: nomeArquivoComprovante(comprovante),
        );
      } catch (e, st) {
        debugPrint('Erro ao gerar o PDF do comprovante: $e\n$st');
        throw const ComprovanteIndisponivel(
          'Não foi possível gerar o PDF do comprovante.',
        );
      }
    }, retry: (_, _) => null);
