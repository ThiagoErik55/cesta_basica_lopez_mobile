import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';

const double _kAlturaBotao = AppSpacing.md * 3;
const double _kLadoIndicador = AppSpacing.md;

/// Botão de ação principal: largura total, altura fixa, com estado de
/// carregamento e desabilitado. Cor e estilo vêm do tema (ver
/// core/theme/app_theme.dart).
class PrimaryButton extends StatelessWidget {
  const PrimaryButton({
    required this.texto,
    required this.onPressed,
    this.carregando = false,
    super.key,
  });

  final String texto;
  final VoidCallback? onPressed;
  final bool carregando;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: _kAlturaBotao,
      child: ElevatedButton(
        onPressed: carregando ? null : onPressed,
        child: carregando
            ? SizedBox(
                width: _kLadoIndicador,
                height: _kLadoIndicador,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    AppColors.textoContrastante(AppColors.primary),
                  ),
                ),
              )
            : Text(texto),
      ),
    );
  }
}

/// Botão de ação secundária, mesmo padrão de largura e altura do
/// [PrimaryButton], com estilo outline vindo do tema.
class SecondaryButton extends StatelessWidget {
  const SecondaryButton({
    required this.texto,
    required this.onPressed,
    this.carregando = false,
    super.key,
  });

  final String texto;
  final VoidCallback? onPressed;
  final bool carregando;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: _kAlturaBotao,
      child: OutlinedButton(
        onPressed: carregando ? null : onPressed,
        child: carregando
            ? const SizedBox(
                width: _kLadoIndicador,
                height: _kLadoIndicador,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    AppColors.primaryDark,
                  ),
                ),
              )
            : Text(texto),
      ),
    );
  }
}
