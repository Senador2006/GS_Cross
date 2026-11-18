import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/territory.dart';
import '../../../core/routes/app_routes.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/utils/formatters.dart';
import '../../../state/occurrences_provider.dart';
import '../../widgets/common.dart';
import '../../widgets/state_views.dart';

class OccurrenceDetailScreen extends StatelessWidget {
  const OccurrenceDetailScreen({super.key, required this.occurrenceId});
  final String occurrenceId;

  Future<void> _delete(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Excluir ocorrência?'),
        content: const Text('O registro será removido deste aparelho.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    await context.read<OccurrencesProvider>().delete(occurrenceId);
    if (context.mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final o = context.watch<OccurrencesProvider>().byId(occurrenceId);
    if (o == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Ocorrência')),
        body: const EmptyView(
          icon: Icons.search_off_rounded,
          title: 'Ocorrência não encontrada',
          message: 'Ela pode ter sido excluída.',
        ),
      );
    }
    final theme = Theme.of(context);
    final related = IndicatorCatalog.byId(o.category.relatedIndicatorId);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Ocorrência'),
        actions: [
          IconButton(
            tooltip: 'Excluir ocorrência',
            onPressed: () => _delete(context),
            icon: const Icon(Icons.delete_outline_rounded),
          ),
        ],
      ),
      body: ResponsiveBody(
        child: ListView(
          padding: AppSpacing.page,
          children: [
            Text(o.title, style: theme.textTheme.titleLarge),
            const SizedBox(height: AppSpacing.sm),
            Text(o.description, style: theme.textTheme.bodyLarge),
            const SizedBox(height: AppSpacing.lg),
            AppCard(
              child: Column(
                children: [
                  InfoRow(label: 'Categoria', value: o.category.label),
                  InfoRow(label: 'Bairro', value: o.neighborhood),
                  InfoRow(label: 'Data', value: Fmt.date(o.occurredOn)),
                  InfoRow(label: 'Gravidade', value: o.severity.label),
                  InfoRow(
                    label: 'Pessoas afetadas',
                    value: o.affectedPeople?.toString() ?? 'Não informado',
                  ),
                  InfoRow(
                    label: 'Localização',
                    value: o.hasLocation
                        ? '${o.approxLatitude}, ${o.approxLongitude} (~1 km)'
                        : 'Não anexada',
                  ),
                  InfoRow(label: 'Envio', value: o.syncStatus.label),
                  InfoRow(label: 'Pseudônimo do autor', value: o.reporterHash),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            OutlinedButton.icon(
              onPressed: () => Navigator.pushNamed(
                context,
                AppRoutes.indicator,
                arguments: IndicatorArgs(related.id),
              ),
              icon: const Icon(Icons.insights_rounded),
              label: Text('Ver indicador relacionado: ${related.name}'),
            ),
          ],
        ),
      ),
    );
  }
}
