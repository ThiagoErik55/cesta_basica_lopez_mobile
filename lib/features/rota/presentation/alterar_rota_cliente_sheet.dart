import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/primary_button.dart';
import '../../cliente/data/cliente_model.dart';
import '../../cliente/presentation/cliente_providers.dart';
import '../domain/associacao_rota.dart';
import 'rota_providers.dart';
import 'seletor_rota.dart';

/// Abre a troca de rota de um cliente, a partir do detalhe dele (KAN-46).
Future<void> mostrarAlterarRotaDoCliente(
  BuildContext context,
  ClienteModel cliente,
) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  builder: (_) => AlterarRotaClienteSheet(cliente: cliente),
);

class AlterarRotaClienteSheet extends ConsumerStatefulWidget {
  const AlterarRotaClienteSheet({required this.cliente, super.key});

  final ClienteModel cliente;

  @override
  ConsumerState<AlterarRotaClienteSheet> createState() =>
      _AlterarRotaClienteSheetState();
}

class _AlterarRotaClienteSheetState
    extends ConsumerState<AlterarRotaClienteSheet> {
  late String? _rotaId = widget.cliente.rotaId;

  Future<void> _salvar() async {
    if (ref.read(associarClientesProvider).isLoading) return;
    final rotas = ref.read(rotasAtivasProvider).value;
    final navegador = Navigator.of(context);
    final mensageiro = ScaffoldMessenger.of(context);

    // Sem as rotas carregadas não dá para saber o que é "sem rota": não
    // grava nada.
    if (rotas == null) return;
    final atual = rotaValida(widget.cliente.rotaId, rotas);
    final nova = rotaValida(_rotaId, rotas);
    if (nova == atual) {
      navegador.pop();
      return;
    }

    try {
      final sincronizado = await ref
          .read(associarClientesProvider.notifier)
          .definirRotaDoCliente(widget.cliente.id, nova);
      ref.invalidate(clientePorIdProvider(widget.cliente.id));
      final mensagem = nova == null ? 'Cliente sem rota.' : 'Rota atualizada.';
      navegador.pop();
      mensageiro.showSnackBar(
        SnackBar(
          content: Text(
            sincronizado
                ? mensagem
                : '$mensagem Será sincronizado quando houver conexão.',
          ),
        ),
      );
    } on StateError catch (e) {
      mensageiro.showSnackBar(SnackBar(content: Text(e.message)));
    } catch (e) {
      debugPrint('Erro ao alterar rota do cliente: $e');
      mensageiro.showSnackBar(
        const SnackBar(
          content: Text('Não foi possível alterar a rota. Tente de novo.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final salvando = ref.watch(associarClientesProvider).isLoading;
    final carregada = ref.watch(rotasAtivasProvider).hasValue;

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Rota de ${widget.cliente.nome}',
              style: AppTextStyles.sectionTitle,
            ),
            const SizedBox(height: AppSpacing.md),
            SeletorRota(
              rotaId: _rotaId,
              rotulo: 'Rota',
              onChanged: (v) => setState(() => _rotaId = v),
            ),
            const SizedBox(height: AppSpacing.lg),
            PrimaryButton(
              texto: 'Salvar',
              carregando: salvando,
              onPressed: carregada ? _salvar : null,
            ),
          ],
        ),
      ),
    );
  }
}
