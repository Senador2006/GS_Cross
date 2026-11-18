import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../../core/routes/app_routes.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/utils/formatters.dart';
import '../../../state/alerts_provider.dart';
import '../../../state/occurrences_provider.dart';
import '../../../state/settings_provider.dart';
import '../../../state/territory_provider.dart';
import '../../widgets/common.dart';

/// Privacidade (LGPD): consentimentos, dados armazenados, revogação e
/// eliminação de dados.
class PrivacyScreen extends StatelessWidget {
  const PrivacyScreen({super.key});

  Future<bool> _confirm(
    BuildContext context,
    String title,
    String body,
    String action,
  ) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(body),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
              foregroundColor: Theme.of(ctx).colorScheme.onError,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(action),
          ),
        ],
      ),
    );
    return ok == true;
  }

  Future<void> _revoke(BuildContext context) async {
    if (!await _confirm(
      context,
      'Revogar consentimento?',
      'Você voltará à tela inicial e precisará consentir novamente para '
          'usar o app. Seus registros locais são mantidos até que você os '
          'apague.',
      'Revogar',
    )) {
      return;
    }
    if (!context.mounted) return;
    await context.read<SettingsProvider>().revokeConsent();
    if (!context.mounted) return;
    Navigator.of(context)
        .pushNamedAndRemoveUntil(AppRoutes.onboarding, (_) => false);
  }

  Future<void> _erase(BuildContext context) async {
    if (!await _confirm(
      context,
      'Apagar todos os dados?',
      'Ocorrências, decisões, limiares, preferências, cache e '
          'consentimento serão removidos deste aparelho. Esta ação não '
          'pode ser desfeita.',
      'Apagar tudo',
    )) {
      return;
    }
    if (!context.mounted) return;
    await context.read<SettingsProvider>().eraseAllData();
    if (!context.mounted) return;
    context.read<OccurrencesProvider>().clearInMemory();
    context.read<AlertsProvider>().clearInMemory();
    context.read<TerritoryProvider>().clearInMemory();
    Navigator.of(context)
        .pushNamedAndRemoveUntil(AppRoutes.onboarding, (_) => false);
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final occurrences = context.watch<OccurrencesProvider>();
    final consent = settings.consent;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Privacidade e dados')),
      body: ResponsiveBody(
        child: ListView(
          padding: AppSpacing.page,
          children: [
            const SectionHeader(title: 'Seus consentimentos'),
            AppCard(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.verified_user_outlined),
                    title: const Text('Tratamento de dados anonimizados'),
                    subtitle: Text(
                      consent == null
                          ? 'Não concedido'
                          : 'Concedido em ${Fmt.dateTime(consent.acceptedAt)} '
                                '(versão ${consent.version} dos termos)',
                    ),
                  ),
                  SwitchListTile(
                    secondary: const Icon(Icons.location_on_outlined),
                    title: const Text('Localização aproximada nos relatos'),
                    subtitle: const Text('Grade de ~1 km; nunca o endereço.'),
                    value: consent?.approximateLocation ?? false,
                    onChanged: consent == null
                        ? null
                        : (v) => settings.setLocationConsent(v),
                  ),
                ],
              ),
            ),
            const SectionHeader(title: 'O que fica guardado neste aparelho'),
            AppCard(
              child: Column(
                children: [
                  InfoRow(
                    label: 'Ocorrências registradas',
                    value: '${occurrences.items.length}',
                  ),
                  InfoRow(
                    label: 'Seu pseudônimo',
                    value: settings.reporterPseudonym,
                  ),
                  const InfoRow(
                    label: 'Dados pessoais (nome, CPF, contato)',
                    value: 'Nenhum',
                  ),
                  const InfoRow(
                    label: 'Cache de indicadores',
                    value: 'Dados agregados do distrito',
                  ),
                ],
              ),
            ),
            const SectionHeader(title: 'Como protegemos seus dados'),
            const AppCard(
              child: BulletList(
                icon: Icons.lock_outline_rounded,
                iconSize: 18,
                items: [
                  'Minimização: o formulário não tem campos de identificação.',
                  'Bloqueio automático de CPF, e-mail e telefone digitados '
                      'nos textos dos relatos.',
                  'Pseudonimização: o autor é um hash SHA-256 de um sal '
                      'aleatório gerado no aparelho.',
                  'Generalização: bairro em vez de endereço; coordenadas '
                      'arredondadas (~1 km).',
                  'Indicadores são agregados do distrito — nenhum dado '
                      'individual de consumo ou saúde é exibido.',
                  'Direitos do titular (LGPD art. 18): revogar consentimento '
                      'e eliminar dados a qualquer momento, abaixo.',
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            OutlinedButton.icon(
              onPressed: consent == null ? null : () => _revoke(context),
              icon: const Icon(Icons.gpp_maybe_outlined),
              label: const Text('Revogar consentimento'),
            ),
            const SizedBox(height: AppSpacing.md),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: theme.colorScheme.error,
                foregroundColor: theme.colorScheme.onError,
              ),
              onPressed: () => _erase(context),
              icon: const Icon(Icons.delete_forever_rounded),
              label: const Text('Apagar todos os meus dados'),
            ),
            const SizedBox(height: AppSpacing.xl),
          ],
        ),
      ),
    );
  }
}
