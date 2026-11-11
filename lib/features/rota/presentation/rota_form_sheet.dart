import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/domain/enums.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/primary_button.dart';
import '../data/rota_model.dart';
import '../domain/cadastro_rota.dart';
import 'rota_providers.dart';

/// Abre o formulário de rota (KAN-45). Sem [rota], cadastra uma nova; com
/// [rota], edita essa.
Future<void> mostrarFormularioRota(BuildContext context, {RotaModel? rota}) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => RotaFormSheet(rota: rota),
    );

class RotaFormSheet extends ConsumerStatefulWidget {
  const RotaFormSheet({this.rota, super.key});

  final RotaModel? rota;

  @override
  ConsumerState<RotaFormSheet> createState() => _RotaFormSheetState();
}

class _RotaFormSheetState extends ConsumerState<RotaFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late final _nome = TextEditingController(text: widget.rota?.nome);
  late LinhaAtendimento? _linha = widget.rota?.linhaAtendimento;

  bool get _editando => widget.rota != null;

  @override
  void dispose() {
    _nome.dispose();
    super.dispose();
  }

  Future<void> _salvar() async {
    if (ref.read(salvarRotaProvider).isLoading) return;
    if (!_formKey.currentState!.validate()) return;

    final navegador = Navigator.of(context);
    final mensageiro = ScaffoldMessenger.of(context);
    final notificador = ref.read(salvarRotaProvider.notifier);
    final dados = DadosCadastraisRota(nome: _nome.text, linha: _linha!);
    final mensagem = _editando ? 'Rota atualizada.' : 'Rota cadastrada.';

    try {
      final sincronizado = _editando
          ? await notificador.atualizar(widget.rota!, dados)
          : await notificador.cadastrar(dados);
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
      // Nome inválido ou duplicado por outro aparelho enquanto o
      // formulário estava aberto.
      mensageiro.showSnackBar(SnackBar(content: Text(e.message)));
    } catch (e) {
      debugPrint('Erro ao salvar rota: $e');
      mensageiro.showSnackBar(
        const SnackBar(
          content: Text('Não foi possível salvar a rota. Tente de novo.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final salvando = ref.watch(salvarRotaProvider).isLoading;

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                _editando ? 'Editar rota' : 'Nova rota',
                style: AppTextStyles.sectionTitle,
              ),
              const SizedBox(height: AppSpacing.md),
              TextFormField(
                controller: _nome,
                autofocus: !_editando,
                maxLength: nomeRotaMaximo,
                decoration: const InputDecoration(labelText: 'Nome da rota'),
                textCapitalization: TextCapitalization.words,
                textInputAction: TextInputAction.next,
                validator: (v) => validarNomeRota(
                  v ?? '',
                  rotas: ref.read(rotasAtivasProvider).value ?? const [],
                  idAtual: widget.rota?.id,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              DropdownButtonFormField<LinhaAtendimento>(
                initialValue: _linha,
                decoration: const InputDecoration(
                  labelText: 'Linha de atendimento',
                ),
                items: [
                  for (final l in LinhaAtendimento.values)
                    DropdownMenuItem(value: l, child: Text(l.rotulo)),
                ],
                onChanged: (v) => setState(() => _linha = v),
                validator: (v) =>
                    v == null ? 'Escolha a linha de atendimento.' : null,
              ),
              const SizedBox(height: AppSpacing.lg),
              PrimaryButton(
                texto: _editando ? 'Salvar alterações' : 'Salvar',
                carregando: salvando,
                onPressed: _salvar,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
