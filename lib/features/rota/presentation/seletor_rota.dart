import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/associacao_rota.dart';
import 'rota_providers.dart';

/// Seletor de rota do cliente (KAN-46): "Sem rota" mais as rotas ativas
/// do cadastro (KAN-45). Mostra o `rotaId` do cliente só se ele é de uma
/// rota ativa; texto livre antigo, rota excluída ou inexistente aparecem
/// como "Sem rota".
///
/// Enquanto as rotas carregam, ou se falharem, o campo fica desabilitado
/// (sem spinner infinito) e quem usa o seletor deve manter o `rotaId`
/// original em vez de gravar "sem rota".
class SeletorRota extends ConsumerWidget {
  const SeletorRota({
    required this.rotaId,
    required this.onChanged,
    this.rotulo = 'Rota (opcional)',
    super.key,
  });

  /// `rotaId` atual do cliente (pode ser inválido: vira "Sem rota").
  final String? rotaId;
  final ValueChanged<String?> onChanged;
  final String rotulo;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rotas = ref.watch(rotasAtivasProvider);

    return rotas.when(
      data: (lista) {
        // O repositório já devolve só as ativas; o filtro aqui é defesa.
        final ordenadas = [
          for (final r in lista)
            if (!r.deleted) r,
        ]..sort((a, b) => a.nome.toLowerCase().compareTo(b.nome.toLowerCase()));
        return DropdownButtonFormField<String?>(
          key: ValueKey(rotaValida(rotaId, lista)),
          initialValue: rotaValida(rotaId, lista),
          isExpanded: true,
          decoration: InputDecoration(labelText: rotulo),
          items: [
            const DropdownMenuItem<String?>(
              value: null,
              child: Text('Sem rota'),
            ),
            for (final r in ordenadas)
              DropdownMenuItem<String?>(value: r.id, child: Text(r.nome)),
          ],
          onChanged: onChanged,
        );
      },
      loading: () => InputDecorator(
        decoration: InputDecoration(
          labelText: rotulo,
          helperText: 'Carregando rotas…',
        ),
        child: const Text('—'),
      ),
      error: (_, _) => InputDecorator(
        decoration: InputDecoration(
          labelText: rotulo,
          helperText:
              'Não foi possível carregar as rotas. '
              'A rota atual será mantida.',
        ),
        child: const Text('—'),
      ),
    );
  }
}
