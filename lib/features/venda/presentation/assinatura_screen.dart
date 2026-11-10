import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/navigation/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/connection_badge.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/primary_button.dart';
import '../data/assinatura_renderer.dart';
import '../domain/assinatura.dart';
import 'pos_venda_providers.dart';

/// Coleta a assinatura do cliente na tela (RF19, KAN-38). Recebe o id da
/// venda; ao confirmar, grava a imagem na venda e volta.
class AssinaturaScreen extends ConsumerStatefulWidget {
  const AssinaturaScreen({required this.vendaId, super.key});

  final String vendaId;

  @override
  ConsumerState<AssinaturaScreen> createState() => _AssinaturaScreenState();
}

class _AssinaturaScreenState extends ConsumerState<AssinaturaScreen> {
  final List<List<Offset>> _tracos = [];
  bool _salvando = false;

  void _limpar() => setState(_tracos.clear);

  Future<void> _confirmar() async {
    if (_salvando || !tracoSuficiente(_tracos)) return;
    final mensageiro = ScaffoldMessenger.of(context);
    final navegador = Navigator.of(context);
    setState(() => _salvando = true);
    try {
      final imagem = await renderizarAssinatura(_tracos);
      final sincronizado = await ref
          .read(posVendaProvider.notifier)
          .salvarAssinatura(widget.vendaId, imagem);
      navegador.pop();
      mensageiro.showSnackBar(
        SnackBar(
          content: Text(
            sincronizado
                ? 'Assinatura registrada.'
                : 'Assinatura salva no aparelho. Será enviada quando houver '
                      'conexão.',
          ),
          duration: const Duration(seconds: 8),
          // A nota é gerada no aparelho, então abre mesmo offline.
          action: SnackBarAction(
            label: 'Ver nota',
            onPressed: () => navegador.pushNamed(
              AppRoutes.notaProvisoria,
              arguments: widget.vendaId,
            ),
          ),
        ),
      );
    } catch (e) {
      // Sem o conteúdo da assinatura no log (LGPD).
      debugPrint('Erro ao salvar a assinatura: ${e.runtimeType}');
      if (!mounted) return;
      setState(() => _salvando = false);
      mensageiro.showSnackBar(
        const SnackBar(
          content: Text('Não foi possível salvar a assinatura. Tente de novo.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final venda = ref.watch(vendaPorIdProvider(widget.vendaId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Assinatura'),
        actions: const [
          Padding(
            padding: EdgeInsets.only(right: AppSpacing.md),
            child: Center(child: ConnectionBadge()),
          ),
        ],
      ),
      body: venda.when(
        data: (v) => v == null
            ? const Center(
                child: EmptyState(
                  icone: Icons.receipt_long_outlined,
                  titulo: 'Venda não encontrada',
                  descricao: 'Ela pode ter sido removida.',
                ),
              )
            : _corpo('Assinatura de ${v.clienteNome} · Nota ${v.numeroNota}'),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) {
          debugPrint('Erro ao carregar venda ${widget.vendaId}: $error');
          return const Center(
            child: EmptyState(
              icone: Icons.error_outline,
              titulo: 'Erro ao carregar venda',
              descricao: 'Verifique a conexão e tente novamente.',
            ),
          );
        },
      ),
    );
  }

  Widget _corpo(String titulo) {
    final pode = tracoSuficiente(_tracos) && !_salvando;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(titulo, style: AppTextStyles.sectionTitle),
            const SizedBox(height: AppSpacing.sm),
            Expanded(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border.all(color: AppColors.border),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Listener(
                    behavior: HitTestBehavior.opaque,
                    onPointerDown: _salvando
                        ? null
                        : (e) => setState(() => _tracos.add([e.localPosition])),
                    onPointerMove: _salvando
                        ? null
                        : (e) {
                            if (_tracos.isEmpty) return;
                            setState(() => _tracos.last.add(e.localPosition));
                          },
                    child: CustomPaint(
                      painter: _AssinaturaPainter(
                        _tracos.map(List<Offset>.of).toList(),
                      ),
                      child: _tracos.isEmpty
                          ? const Center(
                              child: Text(
                                'Assine aqui com o dedo',
                                style: AppTextStyles.caption,
                              ),
                            )
                          : const SizedBox.expand(),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                TextButton(
                  onPressed: _salvando
                      ? null
                      : () => Navigator.of(context).pop(),
                  child: const Text('Cancelar'),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: SecondaryButton(
                    texto: 'Limpar',
                    onPressed: _tracos.isEmpty || _salvando ? null : _limpar,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: PrimaryButton(
                    texto: 'Confirmar',
                    carregando: _salvando,
                    onPressed: pode ? _confirmar : null,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _AssinaturaPainter extends CustomPainter {
  _AssinaturaPainter(this.tracos);

  final List<List<Offset>> tracos;

  @override
  void paint(Canvas canvas, Size size) => desenharTracos(canvas, tracos);

  @override
  bool shouldRepaint(_AssinaturaPainter antigo) => true;
}
