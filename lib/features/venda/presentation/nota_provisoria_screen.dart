import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/connection_badge.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/pdf_preview_compartilhavel.dart';
import '../domain/mensagens_whatsapp.dart';
import 'nota_provisoria_providers.dart';

/// Nota provisória de compra e venda (KAN-37): visualiza o PDF e permite
/// salvar ou compartilhar pelo compartilhamento do sistema.
class NotaProvisoriaScreen extends ConsumerWidget {
  const NotaProvisoriaScreen({required this.vendaId, super.key});

  final String vendaId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final nota = ref.watch(notaProvisoriaProvider(vendaId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Nota provisória'),
        actions: const [
          Padding(
            padding: EdgeInsets.only(right: AppSpacing.md),
            child: Center(child: ConnectionBadge()),
          ),
        ],
      ),
      body: nota.when(
        data: (gerado) => PdfPreviewCompartilhavel(
          bytes: gerado.bytes,
          nomeArquivo: gerado.nomeArquivo,
          mensagemErroCompartilhar: 'Não foi possível compartilhar a nota.',
          whatsapp: DadosWhatsapp(
            mensagem: mensagemNota(gerado.nota),
            telefone: gerado.nota.telefone,
          ),
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) {
          debugPrint('Erro ao carregar a nota: $error');
          final mensagem = error is NotaIndisponivel
              ? error.mensagem
              : 'Verifique a conexão e tente novamente.';
          return Center(
            child: EmptyState(
              icone: Icons.error_outline,
              titulo: 'Nota indisponível',
              descricao: mensagem,
            ),
          );
        },
      ),
    );
  }
}
