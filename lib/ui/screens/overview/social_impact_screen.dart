import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/territory.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/utils/formatters.dart';
import '../../../domain/analytics/social_impact.dart';
import '../../../state/alerts_provider.dart';
import '../../widgets/common.dart';
import '../../widgets/state_views.dart';

/// Relaciona o desempenho analítico com indicadores de benefício social.
class SocialImpactScreen extends StatelessWidget {
  const SocialImpactScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final impact = context.watch<AlertsProvider>().impact;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Benefício social')),
      body: impact == null
          ? const EmptyView(
              icon: Icons.hourglass_empty_rounded,
              title: 'Sem dados ainda',
              message: 'Carregue os indicadores na Visão geral.',
            )
          : ResponsiveBody(
              child: ListView(
                padding: AppSpacing.page,
                children: [
                  Text(
                    'Previsões só geram valor quando viram ação. Estes '
                    'números conectam a qualidade dos modelos às decisões '
                    'tomadas e às pessoas alcançadas.',
                    style: theme.textTheme.bodyMedium,
                  ),
                  const SectionHeader(title: 'Impacto para a população'),
                  _Tile(
                    icon: Icons.groups_rounded,
                    value: Fmt.number(impact.peopleCovered, decimals: 0),
                    label:
                        'pessoas vivem em áreas cobertas por alertas com '
                        'ação humana (${Fmt.percent(impact.coverageRatio)} '
                        'da população de ${Territory.name})',
                  ),
                  _Tile(
                    icon: Icons.water_drop_rounded,
                    value: '${Fmt.number(impact.waterSavedM3, decimals: 0)} m³',
                    label:
                        'de água potencialmente economizados — premissa: '
                        '${Fmt.percent(SocialImpactCalculator.avoidableShare)} '
                        'do excedente acima da média, por 7 dias, é evitável '
                        'com ação rápida (estimativa).',
                  ),
                  _Tile(
                    icon: Icons.campaign_rounded,
                    value: '${impact.citizenReports}',
                    label:
                        'relatos cidadãos registrados '
                        '(${impact.citizenReportsSynced} enviados)',
                  ),
                  const SectionHeader(title: 'Decisões humanas'),
                  _Tile(
                    icon: Icons.how_to_reg_rounded,
                    value: '${impact.alertsDecided}/${impact.alertsTotal}',
                    label:
                        'alertas avaliados por gestores '
                        '(${impact.alertsActioned} com ação efetiva)',
                  ),
                  _Tile(
                    icon: Icons.timer_outlined,
                    value: impact.avgResponseTime == null
                        ? '—'
                        : Fmt.duration(impact.avgResponseTime!),
                    label: 'tempo médio entre o alerta e a decisão',
                  ),
                  const SectionHeader(title: 'Desempenho analítico'),
                  _Tile(
                    icon: Icons.analytics_rounded,
                    value: Fmt.percent(impact.meanModelAccuracy),
                    label:
                        'precisão média dos modelos no backtest '
                        '(1 − WAPE)',
                  ),
                  _Tile(
                    icon: Icons.verified_rounded,
                    value: Fmt.percent(impact.highConfidenceShare),
                    label: 'dos alertas ativos têm confiança alta',
                  ),
                  _Tile(
                    icon: Icons.do_not_disturb_on_outlined,
                    value: Fmt.percent(impact.dismissedRate),
                    label:
                        'das decisões descartaram o alerta como falso '
                        'positivo — se subir, revise limiares e modelos',
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    'Estimativas para apoio à gestão; não substituem '
                    'avaliação de impacto formal.',
                    style: theme.textTheme.bodySmall,
                  ),
                  const SizedBox(height: AppSpacing.xl),
                ],
              ),
            ),
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({required this.icon, required this.value, required this.label});
  final IconData icon;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: AppCard(
        semanticLabel: '$value $label',
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: theme.colorScheme.primary, size: 28),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(value, style: theme.textTheme.headlineSmall),
                  Text(label, style: theme.textTheme.bodyMedium),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
