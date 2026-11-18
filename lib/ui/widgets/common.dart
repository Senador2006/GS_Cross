import 'package:material_ui/material_ui.dart';

import '../../core/theme/app_tokens.dart';

/// Centraliza o conteúdo e limita a largura em tablets/web (responsividade).
class ResponsiveBody extends StatelessWidget {
  const ResponsiveBody({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.topCenter,
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: AppSpacing.maxContentWidth),
      child: child,
    ),
  );
}

/// Título de seção com ação opcional à direita.
class SectionHeader extends StatelessWidget {
  const SectionHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.actionLabel,
    this.onAction,
  });

  final String title;
  final String? subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.lg, bottom: AppSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Semantics(
                  header: true,
                  child: Text(title, style: theme.textTheme.titleMedium),
                ),
                if (subtitle != null)
                  Text(
                    subtitle!,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
          ),
          if (actionLabel != null)
            TextButton(onPressed: onAction, child: Text(actionLabel!)),
        ],
      ),
    );
  }
}

/// Card padrão do app com padding e cantos da identidade visual.
class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    required this.child,
    this.onTap,
    this.padding = const EdgeInsets.all(AppSpacing.lg),
    this.color,
    this.borderColor,
    this.semanticLabel,
  });

  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;
  final Color? color;
  final Color? borderColor;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final shape = borderColor == null
        ? null
        : RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSpacing.radius),
            side: BorderSide(color: borderColor!, width: 1.5),
          );
    Widget content = Padding(padding: padding, child: child);
    if (onTap != null) {
      content = InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppSpacing.radius),
        child: content,
      );
    }
    final card = Card(
      color: color,
      shape: shape,
      clipBehavior: Clip.antiAlias,
      child: content,
    );
    if (semanticLabel == null) return card;
    return Semantics(
      label: semanticLabel,
      button: onTap != null,
      excludeSemantics: true,
      onTap: onTap,
      child: card,
    );
  }
}

/// "Pílula" com ícone + texto (severidade, status, confiança...).
class StatusPill extends StatelessWidget {
  const StatusPill({
    super.key,
    required this.label,
    required this.color,
    this.icon,
    this.dense = false,
  });

  final String label;
  final Color color;
  final IconData? icon;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.labelMedium
        ?.copyWith(color: color, fontWeight: FontWeight.w700);
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: dense ? AppSpacing.sm : AppSpacing.md,
        vertical: dense ? 2 : AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.6)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 16, color: color),
            const SizedBox(width: AppSpacing.xs),
          ],
          Flexible(child: Text(label, style: style)),
        ],
      ),
    );
  }
}

/// Lista com marcadores (evidências, limitações, ações sugeridas).
class BulletList extends StatelessWidget {
  const BulletList({
    super.key,
    required this.items,
    this.icon = Icons.circle,
    this.iconColor,
    this.iconSize = 8,
  });

  final List<String> items;
  final IconData icon;
  final Color? iconColor;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final item in items)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ExcludeSemantics(
                  child: Padding(
                    padding: EdgeInsets.only(
                      top: iconSize < 12 ? 7 : 1,
                      right: AppSpacing.sm,
                    ),
                    child: Icon(
                      icon,
                      size: iconSize,
                      color: iconColor ?? theme.colorScheme.primary,
                    ),
                  ),
                ),
                Expanded(child: Text(item, style: theme.textTheme.bodyMedium)),
              ],
            ),
          ),
      ],
    );
  }
}

/// Linha "rótulo: valor" para fichas técnicas.
class InfoRow extends StatelessWidget {
  const InfoRow({super.key, required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return MergeSemantics(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 5,
              child: Text(
                label,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              flex: 4,
              child: Text(
                value,
                textAlign: TextAlign.end,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
