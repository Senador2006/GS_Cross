import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../../core/routes/app_routes.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../data/models/app_preferences.dart';
import '../../../state/settings_provider.dart';
import '../../../state/territory_provider.dart';
import '../../widgets/common.dart';

/// Preferências de acessibilidade, perfil e atalhos de configuração.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final prefs = settings.prefs;
    final theme = Theme.of(context);

    void update(AppPreferences p) => settings.updatePreferences(p);

    return Scaffold(
      appBar: AppBar(title: const Text('Ajustes')),
      body: ResponsiveBody(
        child: ListView(
          padding: AppSpacing.page,
          children: [
            const SectionHeader(title: 'Perfil de uso'),
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
              selected: {prefs.role},
              onSelectionChanged: (s) => update(prefs.copyWith(role: s.first)),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Perfil gestor registra decisões sobre alertas e configura '
              'limiares. (Em produção, viria de login institucional.)',
              style: theme.textTheme.bodySmall,
            ),
            const SectionHeader(title: 'Acessibilidade e aparência'),
            AppCard(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.lg,
                    ),
                    child: Text('Tema', style: theme.textTheme.labelLarge),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    child: SegmentedButton<ThemeMode>(
                      segments: const [
                        ButtonSegment(
                          value: ThemeMode.system,
                          icon: Icon(Icons.brightness_auto_rounded),
                          label: Text('Sistema'),
                        ),
                        ButtonSegment(
                          value: ThemeMode.light,
                          icon: Icon(Icons.light_mode_rounded),
                          label: Text('Claro'),
                        ),
                        ButtonSegment(
                          value: ThemeMode.dark,
                          icon: Icon(Icons.dark_mode_rounded),
                          label: Text('Escuro'),
                        ),
                      ],
                      selected: {prefs.themeMode},
                      onSelectionChanged: (s) =>
                          update(prefs.copyWith(themeMode: s.first)),
                    ),
                  ),
                  SwitchListTile(
                    value: prefs.highContrast,
                    onChanged: (v) => update(prefs.copyWith(highContrast: v)),
                    secondary: const Icon(Icons.contrast_rounded),
                    title: const Text('Alto contraste'),
                    subtitle: const Text(
                      'Cores com contraste reforçado e '
                      'bordas mais visíveis.',
                    ),
                  ),
                  SwitchListTile(
                    value: prefs.reduceMotion,
                    onChanged: (v) => update(prefs.copyWith(reduceMotion: v)),
                    secondary: const Icon(Icons.motion_photos_off_outlined),
                    title: const Text('Reduzir animações'),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.lg,
                      AppSpacing.md,
                      AppSpacing.lg,
                      0,
                    ),
                    child: Text(
                      'Tamanho do texto: ${(prefs.textScale * 100).round()}%',
                      style: theme.textTheme.labelLarge,
                    ),
                  ),
                  Slider(
                    value: prefs.textScale,
                    min: 0.9,
                    max: 1.6,
                    divisions: 7,
                    label: '${(prefs.textScale * 100).round()}%',
                    semanticFormatterCallback: (v) =>
                        'Tamanho do texto ${(v * 100).round()} por cento',
                    onChanged: (v) => update(prefs.copyWith(textScale: v)),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.lg,
                      0,
                      AppSpacing.lg,
                      AppSpacing.sm,
                    ),
                    child: Text(
                      'Soma-se ao tamanho de fonte definido no sistema.',
                      style: theme.textTheme.bodySmall,
                    ),
                  ),
                ],
              ),
            ),
            if (settings.isManager) ...[
              const SectionHeader(title: 'Alertas'),
              AppCard(
                padding: EdgeInsets.zero,
                child: ListTile(
                  leading: const Icon(Icons.tune_rounded),
                  title: const Text('Limiares de alerta'),
                  subtitle: const Text('Defina os níveis de atenção e crítico'),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () =>
                      Navigator.pushNamed(context, AppRoutes.thresholds),
                ),
              ),
            ],
            const SectionHeader(title: 'Transparência e privacidade'),
            AppCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.science_outlined),
                    title: const Text('Como as previsões funcionam'),
                    subtitle: const Text('Métricas, limitações e vieses'),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () =>
                        Navigator.pushNamed(context, AppRoutes.transparency),
                  ),
                  const Divider(),
                  ListTile(
                    leading: const Icon(Icons.volunteer_activism_outlined),
                    title: const Text('Benefício social'),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () => Navigator.pushNamed(context, AppRoutes.impact),
                  ),
                  const Divider(),
                  ListTile(
                    leading: const Icon(Icons.privacy_tip_outlined),
                    title: const Text('Privacidade e dados (LGPD)'),
                    subtitle: const Text('Consentimentos e exclusão de dados'),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () =>
                        Navigator.pushNamed(context, AppRoutes.privacy),
                  ),
                ],
              ),
            ),
            const SectionHeader(title: 'Demonstração'),
            AppCard(
              padding: EdgeInsets.zero,
              child: SwitchListTile(
                value: prefs.simulateOffline,
                onChanged: (v) async {
                  await settings.updatePreferences(
                    prefs.copyWith(simulateOffline: v),
                  );
                  if (!context.mounted) return;
                  context.read<TerritoryProvider>().load(offline: v);
                },
                secondary: const Icon(Icons.wifi_off_rounded),
                title: const Text('Simular falta de conexão'),
                subtitle: const Text(
                  'Mostra o modo offline com dados salvos '
                  'e a fila de envio de ocorrências.',
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            Center(
              child: Text(
                'Radar Territorial 1.0 · Global Solution 2026.2 · CitizenTech',
                style: theme.textTheme.bodySmall,
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
          ],
        ),
      ),
    );
  }
}
