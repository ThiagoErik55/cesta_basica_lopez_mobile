import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/cliente/presentation/clientes_screen.dart';
import '../../features/estoque/presentation/estoque_screen.dart';
import '../../features/financeiro/presentation/financeiro_screen.dart';
import '../../features/rota/presentation/agenda_screen.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_text_styles.dart';
import 'app_routes.dart';
import 'navigation_provider.dart';

/// Casca de navegação principal do app (KAN-10): bottom navigation com
/// quatro abas de conteúdo, preservadas em memória via [IndexedStack],
/// mais um botão de ação central para Nova Venda.
///
/// Nova Venda não é uma quinta aba: é um fluxo com começo e fim (um
/// pedido é aberto, preenchido e fechado), então o botão central
/// empilha uma rota nova sobre a navegação (Navigator.pushNamed) em vez
/// de virar uma posição do IndexedStack — trocar de aba não deveria
/// abandonar silenciosamente uma venda em andamento.
class MainShell extends ConsumerWidget {
  const MainShell({super.key});

  static const List<Widget> _abas = [
    AgendaScreen(),
    ClientesScreen(),
    EstoqueScreen(),
    FinanceiroScreen(),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final abaAtual = ref.watch(abaSelecionadaProvider);
    final navegacao = ref.read(abaSelecionadaProvider.notifier);

    return Scaffold(
      body: IndexedStack(index: abaAtual, children: _abas),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppColors.primaryDark,
        foregroundColor: AppColors.textoContrastante(AppColors.primaryDark),
        onPressed: () => Navigator.of(context).pushNamed(AppRoutes.novaVenda),
        child: const Icon(Icons.shopping_cart),
      ),
      bottomNavigationBar: BottomAppBar(
        color: AppColors.surface,
        shape: const CircularNotchedRectangle(),
        notchMargin: AppSpacing.xs,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _ItemNavegacao(
              icone: Icons.calendar_today_outlined,
              rotulo: 'Agenda',
              selecionado: abaAtual == 0,
              onTap: () => navegacao.selecionar(0),
            ),
            _ItemNavegacao(
              icone: Icons.people_outline,
              rotulo: 'Clientes',
              selecionado: abaAtual == 1,
              onTap: () => navegacao.selecionar(1),
            ),
            const SizedBox(width: AppSpacing.xl),
            _ItemNavegacao(
              icone: Icons.inventory_2_outlined,
              rotulo: 'Estoque',
              selecionado: abaAtual == 2,
              onTap: () => navegacao.selecionar(2),
            ),
            _ItemNavegacao(
              icone: Icons.attach_money,
              rotulo: 'Financeiro',
              selecionado: abaAtual == 3,
              onTap: () => navegacao.selecionar(3),
            ),
          ],
        ),
      ),
    );
  }
}

class _ItemNavegacao extends StatelessWidget {
  const _ItemNavegacao({
    required this.icone,
    required this.rotulo,
    required this.selecionado,
    required this.onTap,
  });

  final IconData icone;
  final String rotulo;
  final bool selecionado;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cor = selecionado ? AppColors.primary : AppColors.textSecondary;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icone, color: cor),
            const SizedBox(height: AppSpacing.xs),
            Text(rotulo, style: AppTextStyles.caption.copyWith(color: cor)),
          ],
        ),
      ),
    );
  }
}
