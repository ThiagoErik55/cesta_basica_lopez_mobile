import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/connection_badge.dart';
import '../../../core/widgets/empty_state.dart';
import '../domain/cadastro_rota.dart';
import 'detalhe_rota_sheet.dart';
import 'rota_form_sheet.dart';
import 'rota_providers.dart';

/// Cadastro de rotas (KAN-45, RF06): lista em tempo real, com o cache
/// offline, busca por nome, criação, edição e exclusão lógica.
///
/// Só o CRUD. Associar clientes (KAN-46), agenda por data (KAN-47) e
/// recomendação de clientes a visitar (KAN-48) são tarefas à parte.
class RotasScreen extends ConsumerStatefulWidget {
  const RotasScreen({super.key});

  @override
  ConsumerState<RotasScreen> createState() => _RotasScreenState();
}

class _RotasScreenState extends ConsumerState<RotasScreen> {
  static const _debounce = Duration(milliseconds: 300);

  final _busca = TextEditingController();
  Timer? _timer;

  @override
  void dispose() {
    _timer?.cancel();
    _busca.dispose();
    super.dispose();
  }

  void _aoDigitar(String texto) {
    _timer?.cancel();
    _timer = Timer(_debounce, () {
      if (mounted) ref.read(buscaRotaProvider.notifier).buscar(texto);
    });
  }

  void _limparBusca() {
    _timer?.cancel();
    _busca.clear();
    ref.read(buscaRotaProvider.notifier).buscar('');
  }

  @override
  Widget build(BuildContext context) {
    final itens = ref.watch(itensRotaProvider);
    final termo = ref.watch(buscaRotaProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Rotas'),
        actions: const [
          Padding(
            padding: EdgeInsets.only(right: AppSpacing.md),
            child: Center(child: ConnectionBadge()),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'novaRota',
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.textoContrastante(AppColors.primary),
        onPressed: () => mostrarFormularioRota(context),
        icon: const Icon(Icons.add),
        label: const Text('Nova rota'),
      ),
      body: itens.when(
        data: (todas) => _conteudo(todas, termo),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) {
          debugPrint('Erro ao carregar rotas: $error');
          return const Center(
            child: EmptyState(
              icone: Icons.error_outline,
              titulo: 'Erro ao carregar as rotas',
              descricao: 'Verifique a conexão e tente novamente.',
            ),
          );
        },
      ),
    );
  }

  Widget _conteudo(List<ItemRota> todas, String termo) {
    if (todas.isEmpty) {
      return const Center(
        child: EmptyState(
          icone: Icons.route_outlined,
          titulo: 'Nenhuma rota cadastrada',
          descricao: 'Toque em "Nova rota" para cadastrar a primeira.',
        ),
      );
    }

    final itens = filtrarRotas(todas, termo);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: ValueListenableBuilder(
            valueListenable: _busca,
            builder: (context, valor, _) => TextField(
              controller: _busca,
              onChanged: _aoDigitar,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: 'Buscar rota pelo nome',
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
          child: itens.isEmpty
              ? const Center(
                  child: SingleChildScrollView(
                    child: EmptyState(
                      icone: Icons.search_off,
                      titulo: 'Nenhuma rota encontrada',
                      descricao: 'Ajuste a busca.',
                    ),
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.md,
                    0,
                    AppSpacing.md,
                    // Espaço para o botão não cobrir o último card.
                    AppSpacing.xl * 3,
                  ),
                  itemCount: itens.length,
                  separatorBuilder: (_, _) =>
                      const SizedBox(height: AppSpacing.sm),
                  itemBuilder: (context, i) => _CardRota(item: itens[i]),
                ),
        ),
      ],
    );
  }
}

class _CardRota extends StatelessWidget {
  const _CardRota({required this.item});

  final ItemRota item;

  @override
  Widget build(BuildContext context) {
    final rota = item.rota;
    final clientes = textoClientesDaRota(item.clientes);

    return Card(
      child: InkWell(
        onTap: () => mostrarDetalheRota(context, rota.id),
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Row(
            children: [
              const Icon(Icons.route_outlined, color: AppColors.primary),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(rota.nome, style: AppTextStyles.cardTitle),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      '${rota.linhaAtendimento.rotulo} · ${rota.codigo}',
                      style: AppTextStyles.cardSubtitle,
                    ),
                    if (clientes != null) ...[
                      const SizedBox(height: AppSpacing.xs),
                      Text(clientes, style: AppTextStyles.body),
                    ],
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: AppColors.textSecondary),
            ],
          ),
        ),
      ),
    );
  }
}
