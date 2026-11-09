import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:printing/printing.dart';

import '../../../core/services/compartilhador_pdf.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/connection_badge.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/primary_button.dart';
import 'comprovante_providers.dart';

/// Comprovante de pagamento (RF17, KAN-36): visualiza o PDF e permite
/// salvar ou compartilhar pelo compartilhamento do sistema.
class ComprovantePagamentoScreen extends ConsumerWidget {
  const ComprovantePagamentoScreen({required this.args, super.key});

  final ComprovanteArgs args;

  Future<void> _compartilhar(
    BuildContext context,
    WidgetRef ref,
    ComprovanteGerado gerado,
  ) async {
    final mensageiro = ScaffoldMessenger.of(context);
    try {
      await ref
          .read(compartilhadorPdfProvider)
          .compartilhar(bytes: gerado.bytes, nomeArquivo: gerado.nomeArquivo);
    } catch (e) {
      debugPrint('Erro ao compartilhar o comprovante: $e');
      mensageiro.showSnackBar(
        const SnackBar(
          content: Text('Não foi possível compartilhar o comprovante.'),
        ),
      );
    }
  }

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
        data: (gerado) => Column(
          children: [
            Expanded(
              child: PdfPreview(
                build: (_) async => gerado.bytes,
                pdfFileName: gerado.nomeArquivo,
                // As ações do sistema ficam no botão abaixo, que usa o
                // serviço de compartilhamento reutilizável.
                useActions: false,
                allowSharing: false,
                allowPrinting: false,
                canChangePageFormat: false,
                canChangeOrientation: false,
                canDebug: false,
                loadingWidget: const CircularProgressIndicator(),
                onError: (context, error) => const Center(
                  child: EmptyState(
                    icone: Icons.error_outline,
                    titulo: 'Erro ao exibir o comprovante',
                    descricao:
                        'Tente compartilhar o arquivo pelo botão abaixo.',
                  ),
                ),
              ),
            ),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: PrimaryButton(
                  texto: 'Compartilhar ou salvar PDF',
                  onPressed: () => _compartilhar(context, ref, gerado),
                ),
              ),
            ),
          ],
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
