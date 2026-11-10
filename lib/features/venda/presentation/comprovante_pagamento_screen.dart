import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/connection_badge.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/pdf_preview_compartilhavel.dart';
import '../domain/mensagens_whatsapp.dart';
import 'comprovante_providers.dart';

/// Comprovante de pagamento (RF17, KAN-36): visualiza o PDF e permite
/// salvar ou compartilhar pelo compartilhamento do sistema.
class ComprovantePagamentoScreen extends ConsumerWidget {
  const ComprovantePagamentoScreen({required this.args, super.key});

  final ComprovanteArgs args;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final comprovante = ref.watch(comprovanteProvider(args));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Comprovante'),
        actions: const [
          Padding(
            padding: EdgeInsets.only(right: AppSpacing.md),
            child: Center(child: ConnectionBadge()),
          ),
        ],
      ),
      body: comprovante.when(
        data: (gerado) => PdfPreviewCompartilhavel(
          bytes: gerado.bytes,
          nomeArquivo: gerado.nomeArquivo,
          mensagemErroCompartilhar:
              'Não foi possível compartilhar o comprovante.',
          whatsapp: DadosWhatsapp(
            mensagem: mensagemComprovante(gerado.comprovante),
            telefone: gerado.comprovante.telefone,
          ),
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) {
          debugPrint('Erro ao carregar o comprovante: $error');
          final mensagem = error is ComprovanteIndisponivel
              ? error.mensagem
              : 'Verifique a conexão e tente novamente.';
          return Center(
            child: EmptyState(
              icone: Icons.error_outline,
              titulo: 'Comprovante indisponível',
              descricao: mensagem,
            ),
          );
        },
      ),
    );
  }
}
