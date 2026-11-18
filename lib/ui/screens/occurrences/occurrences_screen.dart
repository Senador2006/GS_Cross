import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../../core/routes/app_routes.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/utils/formatters.dart';
import '../../../data/models/occurrence.dart';
import '../../../data/models/threshold.dart';
import '../../../state/occurrences_provider.dart';
import '../../../state/settings_provider.dart';
import '../../../state/view_status.dart';
import '../../widgets/common.dart';
import '../../widgets/semantic_style.dart';
import '../../widgets/state_views.dart';

/// Lista de ocorrências registradas neste aparelho (persistidas localmente).
class OccurrencesScreen extends StatelessWidget {
  const OccurrencesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<OccurrencesProvider>();
    final offline = context.select<SettingsProvider, bool>(
      (s) => s.prefs.simulateOffline,
    );

    Future<void> sync() async {
      final sent = await state.syncPending(offline: offline);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            sent > 0
                ? '$sent ${sent == 1 ? 'ocorrência enviada' : 'ocorrências enviadas'}.'
                : 'Ainda sem conexão. Tentaremos novamente depois.',
          ),
        ),
      );
    }

    void openForm() => Navigator.pushNamed(context, AppRoutes.occurrenceNew);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Ocorrências cidadãs'),
        actions: [
          if (state.pendingCount > 0)
            IconButton(
              tooltip: 'Enviar ${state.pendingCount} pendentes',
              onPressed: state.isSyncing ? null : sync,
              icon: state.isSyncing
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.cloud_upload_rounded),
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: openForm,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Relatar'),
      ),
      body: state.status == ViewStatus.empty
          ? EmptyView(
              icon: Icons.campaign_outlined,
              title: 'Nenhuma ocorrência registrada',
              message:
                  'Viu um vazamento, lixo acumulado ou alagamento? '
                  'Relate de forma anônima e ajude a priorizar ações no '
                  'seu bairro.',
              actionLabel: 'Registrar ocorrência',
              onAction: openForm,
            )
          : ResponsiveBody(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg,
                  AppSpacing.lg,
                  AppSpacing.lg,
                  96,
                ),
                children: [
                  if (state.pendingCount > 0)
                    Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.md),
                      child: AppCard(
                        color: Theme.of(context).colorScheme.tertiaryContainer,
                        padding: const EdgeInsets.all(AppSpacing.md),
                        child: Text(
                          '${state.pendingCount} ocorrência(s) salvas no '
                          'aparelho aguardando conexão para envio.',
                        ),
                      ),
                    ),
                  for (final o in state.items)
                    Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                      child: _OccurrenceTile(occurrence: o),
                    ),
                ],
              ),
            ),
    );
  }
}

class _OccurrenceTile extends StatelessWidget {
  const _OccurrenceTile({required this.occurrence});
  final Occurrence occurrence;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final o = occurrence;
    final synced = o.syncStatus == SyncStatus.synced;
    return AppCard(
      onTap: () => Navigator.pushNamed(
        context,
        AppRoutes.occurrence,
        arguments: OccurrenceArgs(o.id),
      ),
      semanticLabel:
          '${o.category.label}: ${o.title}. ${o.neighborhood}, '
          '${Fmt.date(o.occurredOn)}. Gravidade ${o.severity.label}. '
          '${o.syncStatus.label}.',
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: SemanticStyle.domain(
              context,
              o.category.domain,
            ).withValues(alpha: 0.15),
            child: Icon(
              SemanticStyle.domainIcon(o.category.domain),
              color: SemanticStyle.domain(context, o.category.domain),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(o.title, style: theme.textTheme.titleSmall),
                Text(
                  '${o.category.label} · ${o.neighborhood}',
                  style: theme.textTheme.bodySmall,
                ),
                Text(Fmt.date(o.occurredOn), style: theme.textTheme.bodySmall),
              ],
            ),
          ),
          StatusPill(
            label: o.syncStatus.label,
            color: synced
                ? SemanticStyle.level(context, ThresholdLevel.normal)
                : theme.colorScheme.onSurfaceVariant,
            icon: synced ? Icons.cloud_done_rounded : Icons.schedule_rounded,
            dense: true,
          ),
        ],
      ),
    );
  }
}
