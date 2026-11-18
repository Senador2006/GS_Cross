import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/territory.dart';
import '../../../core/routes/app_routes.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/validators.dart';
import '../../../data/models/alert.dart';
import '../../../state/alerts_provider.dart';
import '../../../state/settings_provider.dart';
import '../../widgets/common.dart';
import '../../widgets/insight_widgets.dart';
import '../../widgets/semantic_style.dart';
import '../../widgets/state_views.dart';

/// Detalhe do alerta: evidência, confiança, limitações, ações sugeridas e
/// registro da DECISÃO HUMANA.
class AlertDetailScreen extends StatelessWidget {
  const AlertDetailScreen({super.key, required this.alertId});
  final String alertId;

  @override
  Widget build(BuildContext context) {
    final alerts = context.watch<AlertsProvider>();
    final isManager = context.select<SettingsProvider, bool>(
      (s) => s.isManager,
    );
    final alert = alerts.byId(alertId);

    if (alert == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Alerta')),
        body: const EmptyView(
          icon: Icons.notifications_off_outlined,
          title: 'Alerta não está mais ativo',
          message:
              'Os dados foram atualizados e a condição que gerou este '
              'alerta deixou de existir.',
        ),
      );
    }

    final theme = Theme.of(context);
    final color = SemanticStyle.severity(context, alert.severity);
    final decision = alerts.decisionFor(alert.id);
    final def = IndicatorCatalog.byId(alert.indicatorId);

    return Scaffold(
      appBar: AppBar(title: Text(alert.kind.label)),
      body: ResponsiveBody(
        child: ListView(
          padding: AppSpacing.page,
          children: [
            AppCard(
              borderColor: color,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: AppSpacing.sm,
                    runSpacing: AppSpacing.xs,
                    children: [
                      StatusPill(
                        label: alert.severity.label,
                        color: color,
                        icon: SemanticStyle.severityIcon(alert.severity),
                      ),
                      StatusPill(
                        label: def.domain.label,
                        color: SemanticStyle.domain(context, def.domain),
                        icon: SemanticStyle.domainIcon(def.domain),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Semantics(
                    header: true,
                    child: Text(alert.title, style: theme.textTheme.titleLarge),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(alert.summary, style: theme.textTheme.bodyLarge),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    'Gerado em ${Fmt.dateTime(alert.generatedAt)} · '
                    'População potencialmente afetada: '
                    '${Fmt.number(alert.affectedPopulation, decimals: 0)}',
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            const HumanDecisionNotice(),
            const SectionHeader(
              title: 'Evidências',
              subtitle: 'Dados que fundamentam este alerta',
            ),
            AppCard(
              child: BulletList(
                icon: Icons.query_stats_rounded,
                iconSize: 18,
                items: alert.evidence,
              ),
            ),
            const SectionHeader(title: 'Nível de confiança'),
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ConfidenceMeter(score: alert.confidenceScore),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    _confidenceExplanation(alert),
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            const SectionHeader(
              title: 'Limitações e vieses',
              subtitle: 'Considere antes de decidir',
            ),
            AppCard(
              child: BulletList(
                icon: Icons.warning_amber_rounded,
                iconSize: 18,
                iconColor: SemanticStyle.severity(
                  context,
                  AlertSeverity.warning,
                ),
                items: alert.limitations,
              ),
            ),
            const SectionHeader(
              title: 'Ações sugeridas',
              subtitle: 'Sugestões — nada é executado automaticamente',
            ),
            AppCard(
              child: BulletList(
                icon: Icons.lightbulb_outline_rounded,
                iconSize: 18,
                items: alert.suggestedActions,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            OutlinedButton.icon(
              onPressed: () => Navigator.pushNamed(
                context,
                AppRoutes.indicator,
                arguments: IndicatorArgs(alert.indicatorId),
              ),
              icon: const Icon(Icons.insights_rounded),
              label: Text('Ver indicador: ${def.name}'),
            ),
            const SectionHeader(title: 'Decisão humana'),
            if (decision != null)
              _DecisionRecord(decision: decision, canReopen: isManager),
            if (isManager)
              _DecisionForm(alert: alert, current: decision)
            else if (decision == null)
              const AppCard(
                child: Text(
                  'Aguardando avaliação de um(a) gestor(a) público(a). '
                  'Se você presenciou o problema, registre uma ocorrência.',
                ),
              ),
            const SizedBox(height: AppSpacing.xxl),
          ],
        ),
      ),
    );
  }

  static String _confidenceExplanation(TerritoryAlert a) => switch (a.kind) {
    AlertKind.thresholdBreach =>
      'Baseada na qualidade do dado observado: completude da série e '
          'persistência do valor além do limiar nos últimos dias.',
    AlertKind.predictedBreach || AlertKind.trend =>
      'Combina o erro do modelo no backtest (55%), a completude dos dados '
          '(25%) e o tamanho da amostra (20%).',
    AlertKind.anomaly =>
      'Cresce com a intensidade do desvio e a completude dos dados.',
    AlertKind.citizenReports =>
      'Cresce com o número de relatos; limitada a 80% por serem relatos '
          'não verificados.',
  };
}

class _DecisionRecord extends StatelessWidget {
  const _DecisionRecord({required this.decision, required this.canReopen});
  final AlertDecision decision;
  final bool canReopen;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = SemanticStyle.decision(context, decision.status);
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: AppCard(
        borderColor: color,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            StatusPill(
              label: decision.status.label,
              color: color,
              icon: SemanticStyle.decisionIcon(decision.status),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text('"${decision.note}"', style: theme.textTheme.bodyMedium),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Registrado em ${Fmt.dateTime(decision.decidedAt)} · tempo de '
              'resposta: ${Fmt.duration(decision.responseTime)}',
              style: theme.textTheme.bodySmall,
            ),
            if (canReopen)
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () =>
                      context.read<AlertsProvider>().reopen(decision.alertId),
                  child: const Text('Reabrir avaliação'),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Formulário de decisão: status + justificativa obrigatória.
class _DecisionForm extends StatefulWidget {
  const _DecisionForm({required this.alert, required this.current});
  final TerritoryAlert alert;
  final AlertDecision? current;

  @override
  State<_DecisionForm> createState() => _DecisionFormState();
}

class _DecisionFormState extends State<_DecisionForm> {
  final _formKey = GlobalKey<FormState>();
  final _note = TextEditingController();
  DecisionStatus? _status;

  static const _options = [
    DecisionStatus.acknowledged,
    DecisionStatus.forwarded,
    DecisionStatus.resolved,
    DecisionStatus.dismissed,
  ];

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirmar decisão'),
        content: Text(
          'Registrar "${_status!.label}" para este alerta? A decisão fica '
          'salva no histórico com sua justificativa.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Confirmar'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await context.read<AlertsProvider>().decide(
      widget.alert,
      _status!,
      _note.text,
    );
    if (!mounted) return;
    _note.clear();
    setState(() => _status = null);
    _formKey.currentState!.reset();
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Decisão registrada.')));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AppCard(
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.current == null
                  ? 'Avalie a evidência e registre sua decisão:'
                  : 'Atualizar decisão:',
              style: theme.textTheme.titleSmall,
            ),
            const SizedBox(height: AppSpacing.sm),
            FormField<DecisionStatus>(
              initialValue: _status,
              validator: (v) => v == null ? 'Escolha uma decisão.' : null,
              builder: (field) => Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  RadioGroup<DecisionStatus>(
                    groupValue: _status,
                    onChanged: (v) {
                      setState(() => _status = v);
                      field.didChange(v);
                    },
                    child: Column(
                      children: [
                        for (final o in _options)
                          RadioListTile<DecisionStatus>(
                            value: o,
                            contentPadding: EdgeInsets.zero,
                            title: Text(o.label),
                            secondary: Icon(SemanticStyle.decisionIcon(o)),
                          ),
                      ],
                    ),
                  ),
                  if (field.hasError)
                    Text(
                      field.errorText!,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.error,
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            TextFormField(
              controller: _note,
              maxLines: 3,
              maxLength: 300,
              decoration: const InputDecoration(
                labelText: 'Justificativa da decisão *',
                hintText: 'Ex.: Equipe de vistoria enviada ao setor 3.',
                helperText:
                    'Obrigatória para manter a rastreabilidade. Não '
                    'inclua dados pessoais.',
              ),
              validator: Validators.decisionNote,
            ),
            const SizedBox(height: AppSpacing.md),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _submit,
                icon: const Icon(Icons.how_to_reg_rounded),
                label: const Text('Registrar decisão'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
