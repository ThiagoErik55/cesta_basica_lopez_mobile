import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/navigation/app_routes.dart';
import '../../../core/services/discador.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/ligacao.dart';
import '../../cliente/data/cliente_model.dart';

/// Ações rápidas de um cliente na agenda e nas recomendações (KAN-47,
/// KAN-48): Detalhes, Nova venda (com o cliente já selecionado) e Ligar
/// (só com telefone válido). [extras] acrescenta botões próprios da tela,
/// como "Visita realizada" ou "Dispensar hoje".
class AcoesRapidasCliente extends ConsumerWidget {
  const AcoesRapidasCliente({
    required this.cliente,
    this.extras = const [],
    super.key,
  });

  final ClienteModel cliente;
  final List<Widget> extras;

  Future<void> _ligar(BuildContext context, WidgetRef ref, Uri uri) async {
    final mensageiro = ScaffoldMessenger.of(context);
    final ok = await ref.read(discadorProvider).ligar(uri);
    if (!ok) {
      mensageiro.showSnackBar(
        const SnackBar(content: Text('Não foi possível abrir o discador.')),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ligacao = uriDeLigacao(cliente.telefone);

    return Wrap(
      alignment: WrapAlignment.end,
      spacing: AppSpacing.xs,
      children: [
        TextButton.icon(
          onPressed: () =>
              Navigator.of(context)
                  .pushNamed(AppRoutes.detalheCliente, arguments: cliente.id),
          icon: const Icon(Icons.person_outline),
          label: const Text('Detalhes'),
        ),
        TextButton.icon(
          // Abre a nova venda com este cliente já selecionado.
          onPressed: () =>
              Navigator.of(context)
                  .pushNamed(AppRoutes.novaVenda, arguments: cliente.id),
          icon: const Icon(Icons.shopping_cart_outlined),
          label: const Text('Nova venda'),
        ),
        if (ligacao != null)
          TextButton.icon(
            onPressed: () => _ligar(context, ref, ligacao),
            icon: const Icon(Icons.call_outlined),
            label: const Text('Ligar'),
          ),
        ...extras,
      ],
    );
  }
}
