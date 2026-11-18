import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../../core/routes/app_routes.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/utils/formatters.dart';
import '../../../domain/analytics/alert_engine.dart';
import '../../../domain/analytics/prediction_engine.dart';
import '../../../state/territory_provider.dart';
import '../../widgets/common.dart';
import '../../widgets/semantic_style.dart';

/// Transparência algorítmica: como o modelo funciona, métricas por
/// indicador, limitações, vieses e quando NÃO confiar nas previsões.
class TransparencyScreen extends StatelessWidget {
  const TransparencyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final territory = context.watch<TerritoryProvider>();
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Como as previsões funcionam')),
      body: ResponsiveBody(
        child: ListView(
          padding: AppSpacing.page,
          children: [
            const SectionHeader(title: 'Método'),
            const AppCard(
              child: BulletList(
                icon: Icons.functions_rounded,
                iconSize: 18,
                items: [
                  'Janela de treino: últimos 28 dias de cada indicador.',
                  'Modelo: tendência linear (mínimos quadrados) + efeito médio '
                      'de cada dia da semana (sazonalidade semanal).',
                  'Previsão de 7 dias com intervalo de ~95% (±1,96 × desvio '
                      'dos resíduos), que se alarga com o horizonte.',
                  'Backtest: o modelo é treinado sem os últimos 7 dias e '
                      'comparado ao observado (erro WAPE).',
                  'Confiança = 55% acurácia do backtest + 25% completude dos '
                      'dados + 20% tamanho da amostra.',
                  'Tudo roda no próprio aparelho: funciona offline e nenhum '
                      'dado sai para um serviço de IA externo.',
                ],
              ),
            ),
            const SectionHeader(title: 'Regras de alerta'),
            AppCard(
              child: BulletList(
                icon: Icons.rule_rounded,
                iconSize: 18,
                items: [
                  'Limiar ultrapassado: valor atual além do limiar de atenção '
                      'ou crítico configurado pelo gestor.',
                  'Previsão de ultrapassagem: algum dia dos próximos 7 '
                      'previsto além do limiar. Com confiança baixa, o alerta '
                      'é rebaixado para "informativo".',
                  'Anomalia: |escore z| ≥ ${Fmt.number(AlertEngine.anomalyZ)} '
                      'em relação aos 14 dias anteriores.',
                  'Tendência: piora ≥ ${Fmt.percent(AlertEngine.trendChange)} '
                      'na média semanal com inclinação consistente.',
                  'Relatos cidadãos: ≥ ${AlertEngine.citizenReportsMin} '
                      'ocorrências da mesma categoria em 7 dias.',
                ],
              ),
            ),
            const SectionHeader(title: 'Quando NÃO confiar na previsão'),
            AppCard(
              child: BulletList(
                icon: Icons.do_not_disturb_alt_rounded,
                iconSize: 18,
                iconColor: theme.colorScheme.error,
                items: [
                  'Menos de ${PredictionEngine.minSamples} dias com dado válido.',
                  'Mais de ${Fmt.percent(PredictionEngine.maxMissingRatio)} '
                      'dos dias sem dado.',
                  'Erro de backtest acima de '
                      '${Fmt.percent(PredictionEngine.maxReliableWape)}.',
                  'Valor atual a mais de '
                      '${Fmt.number(PredictionEngine.regimeChangeZ)} '
                      'desvios-padrão do padrão recente (mudança de regime).',
                  'Fenômenos irregulares por natureza (ex.: chuva diária) — '
                      'consulte a Defesa Civil e o INMET.',
                  'Feriados, greves, obras ou eventos não estão no modelo.',
                ],
              ),
            ),
            const SectionHeader(title: 'Vieses e limitações conhecidos'),
            const AppCard(
              child: BulletList(
                icon: Icons.balance_rounded,
                iconSize: 18,
                items: [
                  'Indicadores de recursos, resíduos e serviços são SINTÉTICOS '
                      '(cenário simulado). Clima vem da Open-Meteo (real).',
                  'Dados agregados do distrito escondem desigualdades entre '
                      'bairros — um bairro pode estar em crise com a média normal.',
                  'Relatos cidadãos sub-representam quem não tem smartphone, '
                      'idosos e áreas com pouca conectividade.',
                  'Limiares padrão são referências de demonstração e devem '
                      'ser calibrados com as equipes técnicas locais.',
                  'Correlação não é causalidade: o app aponta padrões, não '
                      'explica suas causas.',
                ],
              ),
            ),
            const SectionHeader(
              title: 'Métricas por indicador',
              subtitle: 'Toque para ver o detalhe',
            ),
            for (final s in territory.series)
              if (territory.analysisById(s.id) case final a?)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                  child: AppCard(
                    padding: EdgeInsets.zero,
                    child: ListTile(
                      leading: Icon(
                        a.isReliable
                            ? Icons.check_circle_outline_rounded
                            : Icons.warning_amber_rounded,
                        color: SemanticStyle.confidence(context, a.confidence),
                      ),
                      title: Text(s.definition.name),
                      subtitle: Text(
                        'WAPE ${Fmt.percent(a.metrics.mape, decimals: 1)} · '
                        'R² ${Fmt.number(a.metrics.r2, decimals: 2)} · '
                        'n=${a.metrics.sampleSize} · '
                        'faltantes ${Fmt.percent(a.metrics.missingRatio)}',
                      ),
                      trailing: Text(
                        a.confidence.label,
                        style: theme.textTheme.labelLarge?.copyWith(
                          color: SemanticStyle.confidence(
                            context,
                            a.confidence,
                          ),
                        ),
                      ),
                      onTap: () => Navigator.pushNamed(
                        context,
                        AppRoutes.indicator,
                        arguments: IndicatorArgs(s.id),
                      ),
                    ),
                  ),
                ),
            const SizedBox(height: AppSpacing.xl),
          ],
        ),
      ),
    );
  }
}
