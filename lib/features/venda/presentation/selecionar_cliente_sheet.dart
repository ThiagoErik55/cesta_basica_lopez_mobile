import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/cpf.dart';
import '../../../core/widgets/client_card.dart';
import '../../../core/widgets/empty_state.dart';
import '../../cliente/data/cliente_model.dart';
import 'nova_venda_providers.dart';

/// Abre a busca de cliente da nova venda (KAN-24). Retorna o cliente
/// tocado, ou `null` se o vendedor fechar sem escolher.
Future<ClienteModel?> selecionarCliente(BuildContext context) =>
    showModalBottomSheet<ClienteModel>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => const _SelecionarClienteSheet(),
    );

class _SelecionarClienteSheet extends ConsumerStatefulWidget {
  const _SelecionarClienteSheet();

  @override
  ConsumerState<_SelecionarClienteSheet> createState() =>
      _SelecionarClienteSheetState();
}

class _SelecionarClienteSheetState
    extends ConsumerState<_SelecionarClienteSheet> {
  String _termo = '';

  /// Busca por qualquer parte do nome ou pelos dígitos do CPF.
  List<ClienteModel> _filtrar(List<ClienteModel> todos) {
    final termo = _termo.trim().toLowerCase();
    if (termo.isEmpty) return todos;
    final digitos = apenasDigitos(termo);
    return todos.where((c) {
      if (c.nome.toLowerCase().contains(termo)) return true;
      return digitos.isNotEmpty && apenasDigitos(c.cpf).contains(digitos);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final clientes = ref.watch(clientesVendaProvider);

    return Padding(
      // Sobe junto com o teclado.
      padding: EdgeInsets.only(
        bottom: MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.85,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Selecionar cliente',
                    style: AppTextStyles.sectionTitle,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  TextField(
                    autofocus: true,
                    onChanged: (texto) => setState(() => _termo = texto),
                    textInputAction: TextInputAction.search,
                    decoration: const InputDecoration(
                      hintText: 'Buscar por nome ou CPF',
                      prefixIcon: Icon(Icons.search),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: clientes.when(
                data: (todos) {
                  final lista = _filtrar(todos);
                  if (lista.isEmpty) {
                    return const Center(
                      child: EmptyState(
                        icone: Icons.search_off,
                        titulo: 'Nenhum cliente encontrado',
                        descricao: 'Confira o nome ou o CPF digitado.',
                      ),
                    );
                  }
                  return ListView.separated(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.md,
                      0,
                      AppSpacing.md,
                      AppSpacing.md,
                    ),
                    itemCount: lista.length,
                    separatorBuilder: (_, _) =>
                        const SizedBox(height: AppSpacing.sm),
                    itemBuilder: (context, i) => ClientCard(
                      cliente: lista[i],
                      onTap: () => Navigator.of(context).pop(lista[i]),
                    ),
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, _) {
                  debugPrint('Erro ao carregar clientes na venda: $error');
                  return const Center(
                    child: EmptyState(
                      icone: Icons.error_outline,
                      titulo: 'Erro ao carregar clientes',
                      descricao: 'Verifique a conexão e tente novamente.',
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
