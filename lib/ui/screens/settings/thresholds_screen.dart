import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/territory.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/validators.dart';
import '../../../data/models/indicator.dart';
import '../../../data/models/threshold.dart';
import '../../../state/settings_provider.dart';
import '../../widgets/common.dart';
import '../../widgets/semantic_style.dart';

/// Configuração de limiares de alerta por indicador (formulário validado).
class ThresholdsScreen extends StatelessWidget {
  const ThresholdsScreen({super.key, this.focusIndicatorId});
  final String? focusIndicatorId;

  Future<void> _reset(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Restaurar padrões?'),
        content: const Text(
          'Todos os limiares voltarão aos valores de referência.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Restaurar'),
          ),
        ],
      ),
    );
    if (ok == true && context.mounted) {
      await context.read<SettingsProvider>().resetThresholds();
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Limiares de alerta'),
        actions: [
          IconButton(
            tooltip: 'Restaurar padrões',
            onPressed: () => _reset(context),
            icon: const Icon(Icons.settings_backup_restore_rounded),
          ),
        ],
      ),
      body: ResponsiveBody(
        child: ListView(
          padding: AppSpacing.page,
          children: [
            Text(
              'Alterar um limiar recalcula os alertas imediatamente. Os '
              'valores ficam salvos neste aparelho.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            if (!settings.isManager)
              Padding(
                padding: const EdgeInsets.only(top: AppSpacing.md),
                child: AppCard(
                  color: Theme.of(context).colorScheme.errorContainer,
                  child: const Text(
                    'Somente o perfil gestor pode alterar limiares.',
                  ),
                ),
              ),
            for (final domain in TerritoryDomain.values) ...[
              SectionHeader(title: domain.label, subtitle: domain.subtitle),
              for (final def in IndicatorCatalog.byDomain(domain))
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                  child: AppCard(
                    padding: EdgeInsets.zero,
                    child: ExpansionTile(
                      key: PageStorageKey(def.id),
                      initiallyExpanded: def.id == focusIndicatorId,
                      leading: Icon(
                        SemanticStyle.domainIcon(domain),
                        color: SemanticStyle.domain(context, domain),
                      ),
                      title: Text(def.name),
                      subtitle: Text(
                        _summary(settings.thresholdFor(def.id), def),
                      ),
                      childrenPadding: const EdgeInsets.fromLTRB(
                        AppSpacing.lg,
                        0,
                        AppSpacing.lg,
                        AppSpacing.lg,
                      ),
                      children: [
                        _ThresholdEditor(
                          // Recria o editor quando o valor salvo muda
                          // (ex.: "restaurar padrões").
                          key: ValueKey(
                            '${def.id}-${settings.thresholdFor(def.id).toJson()}',
                          ),
                          definition: def,
                          initial: settings.thresholdFor(def.id),
                          enabled: settings.isManager,
                        ),
                      ],
                    ),
                  ),
                ),
            ],
            const SizedBox(height: AppSpacing.xl),
          ],
        ),
      ),
    );
  }

  static String _summary(AlertThreshold t, IndicatorDefinition d) => t.enabled
      ? 'Atenção ${Fmt.number(t.warning, decimals: d.decimals)} · '
            'Crítico ${Fmt.number(t.critical, decimals: d.decimals)} ${d.unit}'
      : 'Alertas desativados';
}

class _ThresholdEditor extends StatefulWidget {
  const _ThresholdEditor({
    super.key,
    required this.definition,
    required this.initial,
    required this.enabled,
  });

  final IndicatorDefinition definition;
  final AlertThreshold initial;
  final bool enabled;

  @override
  State<_ThresholdEditor> createState() => _ThresholdEditorState();
}

class _ThresholdEditorState extends State<_ThresholdEditor> {
  final _formKey = GlobalKey<FormState>();
  late final _warning = TextEditingController(
    text: _fmt(widget.initial.warning),
  );
  late final _critical = TextEditingController(
    text: _fmt(widget.initial.critical),
  );
  late bool _active = widget.initial.enabled;
  bool _saving = false;

  String _fmt(double v) =>
      Fmt.number(v, decimals: widget.definition.decimals).replaceAll('.', '');

  @override
  void dispose() {
    _warning.dispose();
    _critical.dispose();
    super.dispose();
  }

  String? _pairError() => Validators.thresholdPair(
    warning: Validators.parseDecimal(_warning.text),
    critical: Validators.parseDecimal(_critical.text),
    direction: widget.definition.worseDirection,
  );

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    await context.read<SettingsProvider>().saveThreshold(
      AlertThreshold(
        indicatorId: widget.definition.id,
        warning: Validators.parseDecimal(_warning.text)!,
        critical: Validators.parseDecimal(_critical.text)!,
        enabled: _active,
      ),
    );
    if (!mounted) return;
    setState(() => _saving = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Limiares de "${widget.definition.name}" salvos.'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final def = widget.definition;
    final worseText = def.worseDirection == WorseDirection.higher
        ? 'Valores ACIMA do limiar geram alerta.'
        : 'Valores ABAIXO do limiar geram alerta.';
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(worseText, style: Theme.of(context).textTheme.bodySmall),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: _active,
            onChanged: widget.enabled
                ? (v) => setState(() => _active = v)
                : null,
            title: const Text('Gerar alertas para este indicador'),
          ),
          const SizedBox(height: AppSpacing.sm),
          TextFormField(
            controller: _warning,
            enabled: widget.enabled,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: 'Limiar de atenção *',
              suffixText: def.unit,
            ),
            validator: (v) => Validators.thresholdValue(v, def),
          ),
          const SizedBox(height: AppSpacing.md),
          TextFormField(
            controller: _critical,
            enabled: widget.enabled,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: 'Limiar crítico *',
              suffixText: def.unit,
            ),
            validator: (v) => Validators.thresholdValue(v, def) ?? _pairError(),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Referência: atenção ${Fmt.number(def.defaultWarning, decimals: def.decimals)}'
            ' · crítico ${Fmt.number(def.defaultCritical, decimals: def.decimals)} ${def.unit}',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: AppSpacing.md),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton.icon(
              onPressed: widget.enabled && !_saving ? _save : null,
              icon: const Icon(Icons.save_rounded),
              label: const Text('Salvar'),
            ),
          ),
        ],
      ),
    );
  }
}
