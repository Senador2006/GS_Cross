import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/territory.dart';
import '../../../core/routes/app_routes.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../data/models/app_preferences.dart';
import '../../../state/settings_provider.dart';
import '../../widgets/common.dart';

/// Primeira tela: apresenta o app e coleta consentimento EXPLÍCITO.
/// O uso do app só é liberado após aceitar o tratamento de dados anonimizados.
class ConsentScreen extends StatefulWidget {
  const ConsentScreen({super.key});

  @override
  State<ConsentScreen> createState() => _ConsentScreenState();
}

class _ConsentScreenState extends State<ConsentScreen> {
  // Estado LOCAL da tela (não precisa ser compartilhado).
  bool _dataProcessing = false;
  bool _location = false;
  UserRole _role = UserRole.manager;
  bool _showError = false;
  bool _saving = false;

  Future<void> _continue() async {
    if (!_dataProcessing) {
      setState(() => _showError = true);
      return;
    }
    setState(() => _saving = true);
    await context.read<SettingsProvider>().acceptConsent(
      approximateLocation: _location,
      role: _role,
    );
    if (!mounted) return;
    Navigator.of(context).pushNamedAndRemoveUntil(AppRoutes.home, (_) => false);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Scaffold(
      body: SafeArea(
        child: ResponsiveBody(
          child: ListView(
            padding: AppSpacing.page,
            children: [
              const SizedBox(height: AppSpacing.lg),
              Row(
                children: [
                  CircleAvatar(
                    radius: 28,
                    backgroundColor: scheme.primaryContainer,
                    child: Icon(
                      Icons.radar_rounded,
                      size: 32,
                      color: scheme.onPrimaryContainer,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Semantics(
                          header: true,
                          child: Text(
                            'Radar Territorial',
                            style: theme.textTheme.headlineSmall,
                          ),
                        ),
                        Text(
                          'Inteligência preditiva para ${Territory.name}',
                          style: theme.textTheme.bodyMedium,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.xl),
              Text(
                'Acompanhe indicadores de água, energia, clima, resíduos e '
                'serviços públicos, com previsões e alertas que explicam a '
                'própria evidência, confiança e limitações.',
                style: theme.textTheme.bodyLarge,
              ),
              const SizedBox(height: AppSpacing.lg),
              const BulletList(
                icon: Icons.check_circle_outline_rounded,
                iconSize: 18,
                items: [
                  'Não coletamos nome, CPF, telefone, e-mail ou endereço.',
                  'Relatos são identificados apenas por um pseudônimo '
                      'aleatório gerado neste aparelho.',
                  'A localização, se permitida, é arredondada para ~1 km.',
                  'Você pode revogar o consentimento e apagar todos os dados '
                      'a qualquer momento em Ajustes › Privacidade.',
                  'Os alertas apoiam decisões; quem decide é sempre uma pessoa.',
                ],
              ),
              SectionHeader(title: 'Como você vai usar o app?'),
              SegmentedButton<UserRole>(
                segments: const [
                  ButtonSegment(
                    value: UserRole.manager,
                    icon: Icon(Icons.account_balance_rounded),
                    label: Text('Gestor(a)'),
                  ),
                  ButtonSegment(
                    value: UserRole.citizen,
                    icon: Icon(Icons.person_rounded),
                    label: Text('Cidadão(ã)'),
                  ),
                ],
                selected: {_role},
                onSelectionChanged: (s) => setState(() => _role = s.first),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                _role == UserRole.manager
                    ? 'Gestores registram decisões sobre os alertas.'
                    : 'Cidadãos acompanham indicadores e relatam ocorrências.',
                style: theme.textTheme.bodySmall,
              ),
              SectionHeader(title: 'Consentimento (LGPD)'),
              AppCard(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
                borderColor: _showError && !_dataProcessing
                    ? scheme.error
                    : null,
                child: Column(
                  children: [
                    CheckboxListTile(
                      value: _dataProcessing,
                      onChanged: (v) => setState(() {
                        _dataProcessing = v ?? false;
                        _showError = false;
                      }),
                      title: const Text(
                        'Concordo com o tratamento de dados anonimizados '
                        'para análise territorial (obrigatório)',
                      ),
                      subtitle: const Text(
                        'Relatos e decisões ficam salvos neste aparelho e '
                        'podem ser enviados de forma anônima ao servidor.',
                      ),
                    ),
                    const Divider(),
                    CheckboxListTile(
                      value: _location,
                      onChanged: (v) => setState(() => _location = v ?? false),
                      title: const Text(
                        'Permitir anexar localização aproximada aos relatos '
                        '(opcional)',
                      ),
                      subtitle: const Text(
                        'Coordenadas arredondadas para uma grade de ~1 km.',
                      ),
                    ),
                  ],
                ),
              ),
              if (_showError && !_dataProcessing)
                Padding(
                  padding: const EdgeInsets.only(top: AppSpacing.sm),
                  child: Semantics(
                    liveRegion: true,
                    child: Text(
                      'Para continuar, é necessário aceitar o tratamento de '
                      'dados anonimizados.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: scheme.error,
                      ),
                    ),
                  ),
                ),
              const SizedBox(height: AppSpacing.xl),
              FilledButton.icon(
                onPressed: _saving ? null : _continue,
                icon: const Icon(Icons.arrow_forward_rounded),
                label: const Text('Aceitar e continuar'),
              ),
              const SizedBox(height: AppSpacing.xl),
            ],
          ),
        ),
      ),
    );
  }
}
