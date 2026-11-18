import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/territory.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/privacy.dart';
import '../../../core/utils/validators.dart';
import '../../../data/models/occurrence.dart';
import '../../../state/occurrences_provider.dart';
import '../../../state/settings_provider.dart';
import '../../widgets/common.dart';

/// Formulário de registro de ocorrência pelo cidadão.
///
/// Validações: campos obrigatórios, tamanho de texto, data (não futura,
/// até 30 dias), número de pessoas (1–10.000) e bloqueio de dados pessoais
/// (CPF, e-mail, telefone) nos textos livres.
class OccurrenceFormScreen extends StatefulWidget {
  const OccurrenceFormScreen({super.key, this.initialCategory});
  final OccurrenceCategory? initialCategory;

  @override
  State<OccurrenceFormScreen> createState() => _OccurrenceFormScreenState();
}

class _OccurrenceFormScreenState extends State<OccurrenceFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _description = TextEditingController();
  final _people = TextEditingController();

  late OccurrenceCategory? _category = widget.initialCategory;
  String? _neighborhood;
  OccurrenceSeverity _severity = OccurrenceSeverity.medium;
  DateTime? _date = DateTime.now();
  bool _shareLocation = false;
  bool _submitting = false;
  AutovalidateMode _autovalidate = AutovalidateMode.disabled;

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    _people.dispose();
    super.dispose();
  }

  Future<void> _pickDate(FormFieldState<DateTime> field) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _date ?? now,
      firstDate: now.subtract(const Duration(days: 30)),
      lastDate: now,
      helpText: 'Quando aconteceu?',
    );
    if (picked != null) {
      setState(() => _date = picked);
      field.didChange(picked);
    }
  }

  Future<void> _submit() async {
    final form = _formKey.currentState!;
    if (!form.validate()) {
      setState(() => _autovalidate = AutovalidateMode.onUserInteraction);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Revise os campos destacados em vermelho.'),
        ),
      );
      return;
    }
    setState(() => _submitting = true);
    final settings = context.read<SettingsProvider>();
    final now = DateTime.now();
    final occurrence = Occurrence(
      id: 'occ_${now.microsecondsSinceEpoch}',
      category: _category!,
      title: _title.text.trim(),
      description: _description.text.trim(),
      neighborhood: _neighborhood!,
      severity: _severity,
      occurredOn: _date!,
      createdAt: now,
      reporterHash: settings.reporterPseudonym,
      syncStatus: SyncStatus.pending,
      // Sem GPS real: usa o centro do território, arredondado (~1 km).
      approxLatitude: _shareLocation
          ? Privacy.coarsen(Territory.latitude)
          : null,
      approxLongitude: _shareLocation
          ? Privacy.coarsen(Territory.longitude)
          : null,
      affectedPeople: int.tryParse(_people.text.trim()),
    );
    final sent = await context.read<OccurrencesProvider>().submit(
      occurrence,
      offline: settings.prefs.simulateOffline,
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          sent
              ? 'Ocorrência enviada. Obrigado por contribuir!'
              : 'Sem conexão: ocorrência salva e será enviada depois.',
        ),
      ),
    );
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final settings = context.watch<SettingsProvider>();
    final locationAllowed = settings.consent?.approximateLocation ?? false;

    return Scaffold(
      appBar: AppBar(title: const Text('Nova ocorrência')),
      body: ResponsiveBody(
        child: Form(
          key: _formKey,
          autovalidateMode: _autovalidate,
          child: ListView(
            padding: AppSpacing.page,
            children: [
              AppCard(
                color: theme.colorScheme.secondaryContainer,
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Row(
                  children: [
                    Icon(
                      Icons.shield_outlined,
                      color: theme.colorScheme.onSecondaryContainer,
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(
                        'Relato anônimo: não informe nome, CPF, telefone, '
                        'e-mail ou endereço. Campos com * são obrigatórios.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSecondaryContainer,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              DropdownButtonFormField<OccurrenceCategory>(
                initialValue: _category,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Categoria *',
                  prefixIcon: Icon(Icons.category_outlined),
                ),
                items: [
                  for (final c in OccurrenceCategory.values)
                    DropdownMenuItem(value: c, child: Text(c.label)),
                ],
                onChanged: (v) => setState(() => _category = v),
                validator: (v) =>
                    v == null ? 'Selecione a categoria da ocorrência.' : null,
              ),
              const SizedBox(height: AppSpacing.lg),
              TextFormField(
                controller: _title,
                maxLength: 60,
                textCapitalization: TextCapitalization.sentences,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: 'Título *',
                  hintText: 'Ex.: Vazamento na calçada da escola',
                ),
                validator: (v) => Validators.textLength(
                  v,
                  field: 'O título',
                  min: 5,
                  max: 60,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              TextFormField(
                controller: _description,
                maxLength: 500,
                maxLines: 4,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Descrição *',
                  hintText: 'O que aconteceu? Desde quando? Há riscos?',
                  alignLabelWithHint: true,
                ),
                validator: (v) => Validators.textLength(
                  v,
                  field: 'A descrição',
                  min: 20,
                  max: 500,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              DropdownButtonFormField<String>(
                initialValue: _neighborhood,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Bairro *',
                  helperText: 'Usamos apenas o bairro, nunca o endereço.',
                  prefixIcon: Icon(Icons.location_city_outlined),
                ),
                items: [
                  for (final n in Territory.neighborhoods)
                    DropdownMenuItem(value: n, child: Text(n)),
                ],
                onChanged: (v) => setState(() => _neighborhood = v),
                validator: (v) => v == null ? 'Selecione o bairro.' : null,
              ),
              const SizedBox(height: AppSpacing.lg),
              FormField<DateTime>(
                initialValue: _date,
                validator: (v) => Validators.occurrenceDate(v, DateTime.now()),
                builder: (field) => InkWell(
                  onTap: () => _pickDate(field),
                  borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                  child: InputDecorator(
                    decoration: InputDecoration(
                      labelText: 'Data da ocorrência *',
                      prefixIcon: const Icon(Icons.event_outlined),
                      errorText: field.errorText,
                    ),
                    child: Text(
                      _date == null ? 'Selecionar' : Fmt.date(_date!),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              Text('Gravidade *', style: theme.textTheme.labelLarge),
              const SizedBox(height: AppSpacing.sm),
              SegmentedButton<OccurrenceSeverity>(
                segments: [
                  for (final s in OccurrenceSeverity.values)
                    ButtonSegment(value: s, label: Text(s.label)),
                ],
                selected: {_severity},
                onSelectionChanged: (v) => setState(() => _severity = v.first),
              ),
              const SizedBox(height: AppSpacing.lg),
              TextFormField(
                controller: _people,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: const InputDecoration(
                  labelText: 'Pessoas afetadas (estimativa, opcional)',
                  prefixIcon: Icon(Icons.groups_outlined),
                ),
                validator: (v) => Validators.optionalInt(
                  v,
                  field: 'O número de pessoas',
                  min: 1,
                  max: 10000,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              SwitchListTile(
                value: _shareLocation && locationAllowed,
                onChanged: locationAllowed
                    ? (v) => setState(() => _shareLocation = v)
                    : null,
                contentPadding: EdgeInsets.zero,
                title: const Text('Anexar localização aproximada (~1 km)'),
                subtitle: Text(
                  locationAllowed
                      ? 'Ajuda a equipe a priorizar a região.'
                      : 'Desativado: você não consentiu o uso de localização. '
                            'Altere em Ajustes › Privacidade.',
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              FilledButton.icon(
                onPressed: _submitting ? null : _submit,
                icon: _submitting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.send_rounded),
                label: Text(
                  _submitting ? 'Enviando...' : 'Registrar ocorrência',
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
            ],
          ),
        ),
      ),
    );
  }
}
