import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/connection_badge.dart';
import '../../cliente/data/cliente_repository.dart';
import 'nova_venda_providers.dart';
import 'rodape_venda.dart';
import 'secao_cliente_venda.dart';
import 'secao_produtos_venda.dart';
import 'selecionar_cliente_sheet.dart';

/// Nova venda (RF10), aberta pelo botão central
/// da navegação ou pela tela do cliente.
///
/// - KAN-24: seleção de cliente com alerta de pendência
/// - KAN-25: listagem de produtos e carrinho
///
/// [clienteIdInicial] já deixa o cliente selecionado (vindo dos detalhes
/// do cliente).
class NovaVendaScreen extends ConsumerStatefulWidget {
  const NovaVendaScreen({this.clienteIdInicial, super.key});

  final String? clienteIdInicial;

  @override
  ConsumerState<NovaVendaScreen> createState() => _NovaVendaScreenState();
}

class _NovaVendaScreenState extends ConsumerState<NovaVendaScreen> {
  @override
  void initState() {
    super.initState();
    final id = widget.clienteIdInicial;
    if (id != null) _carregarClienteInicial(id);
  }

  Future<void> _carregarClienteInicial(String id) async {
    final cliente = await ref.read(clienteRepositoryProvider).buscarPorId(id);
    if (!mounted || cliente == null) return;
    ref.read(novaVendaProvider.notifier).selecionarCliente(cliente);
  }

  Future<void> _escolherCliente() async {
    final cliente = await selecionarCliente(context);
    if (!mounted || cliente == null) return;
    ref.read(novaVendaProvider.notifier).selecionarCliente(cliente);
  }

  @override
  Widget build(BuildContext context) {
    final venda = ref.watch(novaVendaProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Nova Venda'),
        actions: const [
          Padding(
            padding: EdgeInsets.only(right: AppSpacing.md),
            child: Center(child: ConnectionBadge()),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          SecaoClienteVenda(venda: venda, onEscolher: _escolherCliente),
          const SizedBox(height: AppSpacing.lg),
          const SecaoProdutosVenda(),
        ],
      ),
      bottomNavigationBar: RodapeVenda(
        total: venda.total,
        unidades: venda.unidades,
      ),
    );
  }
}
