import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/cpf.dart';
import '../../../core/widgets/confirm_dialog.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/filter_chip_bar.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../core/widgets/status_badge.dart';
import '../../cliente/data/cliente_model.dart';
import '../domain/associacao_rota.dart';
import 'rota_providers.dart';

/// Abre a associação de clientes à rota [rotaId] (KAN-46). Liga o
/// `aoAssociarClientes` do detalhe da rota.
Future<void> mostrarAssociarClientes(BuildContext context, String rotaId) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => AssociarClientesSheet(rotaId: rotaId),
    );

/// Lista os clientes ativos com seleção múltipla: marcado = na rota.
/// Marcar um cliente de outra rota o MOVE para esta; desmarcar um
/// cliente desta rota o deixa sem rota.
class AssociarClientesSheet extends ConsumerStatefulWidget {
  const AssociarClientesSheet({required this.rotaId, super.key});

  final String rotaId;

  @override
  ConsumerState<AssociarClientesSheet> createState() =>
      _AssociarClientesSheetState();
}

class _AssociarClientesSheetState extends ConsumerState<AssociarClientesSheet> {
  static const _debounce = Duration(milliseconds: 300);

  final _busca = TextEditingController();
  Timer? _timer;
  String _termo = '';
  FiltroAssociacao _filtro = FiltroAssociacao.todos;

  /// Só as escolhas explícitas do usuário (`id → marcado`); o resto fica
  /// como está. Ver [calcularDiffAssociacao].
  final Map<String, bool> _marcas = {};

  @override
  void dispose() {
    _timer?.cancel();
    _busca.dispose();
    super.dispose();
  }

  void _aoDigitar(String texto) {
    _timer?.cancel();
    _timer = Timer(_debounce, () {
      if (mounted) setState(() => _termo = texto);
    });
  }

  void _limparBusca() {
    _timer?.cancel();
    _busca.clear();
    setState(() => _termo = '');
  }

  Future<void> _salvar({
    required DiffAssociacao diff,
    required String nomeRota,
  }) async {
    if (ref.read(associarClientesProvider).isLoading) return;
    final navegador = Navigator.of(context);
    final mensageiro = ScaffoldMessenger.of(context);

    final aviso = avisoDeMovidos(diff);
    if (aviso != null) {
      final ok = await confirmar(
        context,
        titulo: 'Mover clientes',
        mensagem: '$aviso\n\n${resumoDaAssociacao(diff)}',
        textoConfirmar: 'Confirmar',
      );
      if (!ok || !mounted) return;
    }

    try {
      final sincronizado = await ref
          .read(associarClientesProvider.notifier)
          .aplicar(widget.rotaId, diff);
      final mensagem = mensagemAssociacaoConcluida(diff, nomeRota);
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
      debugPrint('Erro ao associar clientes: $e');
      // O sheet continua aberto, com a seleção, para tentar de novo.
      mensageiro.showSnackBar(
        const SnackBar(
          content: Text('Não foi possível salvar a associação. Tente de novo.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final rotas = ref.watch(rotasAtivasProvider);
    final clientes = ref.watch(clientesDasRotasProvider);
    final salvando = ref.watch(associarClientesProvider).isLoading;

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.9,
      maxChildSize: 0.95,
      builder: (context, scroll) {
        final listaRotas = rotas.value;
        final listaClientes = clientes.value;

        if (rotas.hasError || clientes.hasError) {
          return const Center(
            child: EmptyState(
              icone: Icons.error_outline,
              titulo: 'Erro ao carregar os clientes',
              descricao: 'Verifique a conexão e tente novamente.',
            ),
          );
        }
        if (listaRotas == null || listaClientes == null) {
          return const Center(child: CircularProgressIndicator());
        }
        final nomeRota = nomeDaRota(widget.rotaId, listaRotas);
        if (nomeRota == null) {
          return const Center(
            child: EmptyState(
              icone: Icons.route_outlined,
              titulo: 'Rota não encontrada',
              descricao: 'Ela pode ter sido excluída.',
            ),
          );
        }

        final diff = calcularDiffAssociacao(
          clientes: listaClientes,
          marcas: _marcas,
          rotaId: widget.rotaId,
          rotas: listaRotas,
        );
        final visiveis = filtrarClientesParaAssociacao(
          listaClientes,
          rotaId: widget.rotaId,
          rotas: listaRotas,
          filtro: _filtro,
          termo: _termo,
        );

        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.md,
                AppSpacing.md,
                AppSpacing.md,
                AppSpacing.sm,
              ),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Associar clientes · $nomeRota',
                  style: AppTextStyles.sectionTitle,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
              child: ValueListenableBuilder(
                valueListenable: _busca,
                builder: (context, valor, _) => TextField(
                  controller: _busca,
                  onChanged: _aoDigitar,
                  textInputAction: TextInputAction.search,
                  decoration: InputDecoration(
                    hintText: 'Buscar por nome ou CPF',
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
            const SizedBox(height: AppSpacing.sm),
            FilterChipBar<FiltroAssociacao>(
              opcoes: [
                for (final f in FiltroAssociacao.values)
                  OpcaoFiltro(f.rotulo, f),
              ],
              selecionado: _filtro,
              onSelecionar: (f) =>
                  setState(() => _filtro = f ?? FiltroAssociacao.todos),
            ),
            const SizedBox(height: AppSpacing.sm),
            Expanded(
              child: visiveis.isEmpty
                  ? Center(
                      child: SingleChildScrollView(
                        child: EmptyState(
                          icone: Icons.people_outline,
                          titulo: listaClientes.isEmpty
                              ? 'Nenhum cliente cadastrado'
                              : 'Nenhum cliente encontrado',
                          descricao: listaClientes.isEmpty
                              ? 'Cadastre clientes na aba Clientes.'
                              : 'Ajuste a busca ou o filtro.',
                        ),
                      ),
                    )
                  : ListView.builder(
                      controller: scroll,
                      itemCount: visiveis.length,
                      itemBuilder: (context, i) {
                        final c = visiveis[i];
                        final situacao = situacaoNaRota(
                          c,
                          rotaId: widget.rotaId,
                          rotas: listaRotas,
                        );
                        final marcado =
                            _marcas[c.id] ??
                            situacao == SituacaoNaRota.destaRota;
                        return _LinhaCliente(
                          cliente: c,
                          marcado: marcado,
                          rotuloRota: switch (situacao) {
                            SituacaoNaRota.semRota => null,
                            SituacaoNaRota.destaRota => null,
                            SituacaoNaRota.outraRota => nomeDaRota(
                              c.rotaId,
                              listaRotas,
                            ),
                          },
                          semRota: situacao == SituacaoNaRota.semRota,
                          onChanged: (v) =>
                              setState(() => _marcas[c.id] = v ?? false),
                        );
                      },
                    ),
            ),
            Container(
              decoration: const BoxDecoration(
                color: AppColors.surface,
                border: Border(top: BorderSide(color: AppColors.border)),
              ),
              padding: const EdgeInsets.all(AppSpacing.md),
              child: SafeArea(
                top: false,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      resumoDaAssociacao(diff),
                      style: AppTextStyles.body,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    PrimaryButton(
                      texto: 'Salvar',
                      carregando: salvando,
                      // Sem mudanças não há o que gravar.
                      onPressed: diff.semMudancas
                          ? null
                          : () => _salvar(diff: diff, nomeRota: nomeRota),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _LinhaCliente extends StatelessWidget {
  const _LinhaCliente({
    required this.cliente,
    required this.marcado,
    required this.rotuloRota,
    required this.semRota,
    required this.onChanged,
  });

  final ClienteModel cliente;
  final bool marcado;

  /// Nome da OUTRA rota do cliente, quando houver.
  final String? rotuloRota;
  final bool semRota;
  final ValueChanged<bool?> onChanged;

  @override
  Widget build(BuildContext context) {
    return CheckboxListTile(
      value: marcado,
      onChanged: onChanged,
      controlAffinity: ListTileControlAffinity.leading,
      title: Text(cliente.nome, style: AppTextStyles.cardTitle),
      // CPF mascarado (LGPD): só ajuda a distinguir homônimos.
      subtitle: Text(
        mascararCpf(cliente.cpf),
        style: AppTextStyles.cardSubtitle,
      ),
      secondary: rotuloRota != null
          ? StatusBadge(rotuloRota!, AppColors.statusAtencao)
          : semRota
          ? const StatusBadge('Sem rota', AppColors.textSecondary)
          : null,
    );
  }
}
