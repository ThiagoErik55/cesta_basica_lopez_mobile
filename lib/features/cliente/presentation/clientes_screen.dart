import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/navigation/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/client_card.dart';
import '../../../core/widgets/connection_badge.dart';
import '../../../core/widgets/empty_state.dart';
import '../../auth/presentation/logout_button.dart';
import 'cliente_providers.dart';

/// Aba de listagem e busca de clientes (RF01, RF02). A busca é por
/// prefixo do nome (limitação do Firestore, ver campo nomeBusca no
/// modelo lógico) e só dispara depois de uma pausa na digitação.
class ClientesScreen extends ConsumerStatefulWidget {
  const ClientesScreen({super.key});

  @override
  ConsumerState<ClientesScreen> createState() => _ClientesScreenState();
}

class _ClientesScreenState extends ConsumerState<ClientesScreen> {
  static const _debounce = Duration(milliseconds: 300);

  final _busca = TextEditingController();
  Timer? _timer;
  String _termo = '';

  @override
  void dispose() {
    _timer?.cancel();
    _busca.dispose();
    super.dispose();
  }

  void _aoDigitar(String texto) {
    _timer?.cancel();
    _timer = Timer(_debounce, () {
      if (mounted) setState(() => _termo = texto.trim());
    });
  }

  void _limparBusca() {
    _timer?.cancel();
    _busca.clear();
    setState(() => _termo = '');
  }

  @override
  Widget build(BuildContext context) {
    final clientes = ref.watch(clientesProvider(_termo));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Clientes'),
        actions: const [
          LogoutButton(),
          Padding(
            padding: EdgeInsets.only(right: AppSpacing.md),
            child: Center(child: ConnectionBadge()),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: 'novoCliente',
        tooltip: 'Novo cliente',
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.textoContrastante(AppColors.primary),
        onPressed: () =>
            Navigator.of(context).pushNamed(AppRoutes.cadastroCliente),
        child: const Icon(Icons.person_add_alt_1),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              AppSpacing.sm,
              AppSpacing.md,
              AppSpacing.sm,
            ),
            child: ValueListenableBuilder(
              valueListenable: _busca,
              builder: (context, valor, _) => TextField(
                controller: _busca,
                onChanged: _aoDigitar,
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  hintText: 'Buscar pelo nome',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: valor.text.isEmpty
                      ? null
                      : IconButton(
                          tooltip: 'Limpar busca',
                          icon: const Icon(Icons.close),
                          onPressed: _limparBusca,
                        ),
                ),
              ),
            ),
          ),
          Expanded(
            child: clientes.when(
              // Mantém a lista anterior visível enquanto o novo termo
              // carrega, em vez de piscar um indicador a cada busca.
              skipLoadingOnReload: true,
              data: (lista) => lista.isEmpty
                  ? _vazio()
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(
                        AppSpacing.md,
                        AppSpacing.sm,
                        AppSpacing.md,
                        // Espaço para o FAB não cobrir o último card.
                        AppSpacing.xl * 3,
                      ),
                      itemCount: lista.length,
                      separatorBuilder: (_, _) =>
                          const SizedBox(height: AppSpacing.sm),
                      itemBuilder: (context, i) => ClientCard(
                        cliente: lista[i],
                        onTap: () => Navigator.of(context).pushNamed(
                          AppRoutes.detalheCliente,
                          arguments: lista[i].id,
                        ),
                      ),
                    ),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, stackTrace) {
                // O erro do Firestore (ex. índice ausente, com o link para
                // criá-lo) só aparece no log — a tela mostra uma mensagem
                // genérica.
                debugPrint('Erro ao carregar clientes: $error');
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
    );
  }

  Widget _vazio() {
    return Center(
      child: SingleChildScrollView(
        child: _termo.isEmpty
            ? const EmptyState(
                icone: Icons.people_outline,
                titulo: 'Nenhum cliente cadastrado',
                descricao: 'Toque em + para cadastrar o primeiro cliente.',
              )
            : EmptyState(
                icone: Icons.search_off,
                titulo: 'Nenhum cliente encontrado',
                descricao: 'Nenhum nome começa com "$_termo".',
              ),
      ),
    );
  }
}
