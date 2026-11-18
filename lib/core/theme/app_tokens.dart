import 'package:material_ui/material_ui.dart';

/// Paleta da identidade visual "Radar Territorial".
///
/// Verde-petróleo transmite estabilidade institucional; âmbar e vermelho são
/// reservados a alertas. Todas as combinações texto/fundo usadas atingem
/// contraste mínimo WCAG AA (4,5:1); o modo alto contraste atinge AAA (7:1).
class AppColors {
  AppColors._();

  static const brand = Color(0xFF0B5D5E);
  static const brandDark = Color(0xFF063F40);
  static const brandLight = Color(0xFF7FD1CF);
  static const accent = Color(0xFFE0A100);

  // Severidades (texto sobre estas cores sempre branco ou preto, AA).
  static const critical = Color(0xFFB3261E);
  static const warning = Color(0xFF8A5A00);
  static const info = Color(0xFF1F5FA8);
  static const success = Color(0xFF2E7D32);

  // Versões claras para fundos de chips/cards no tema escuro.
  static const criticalOnDark = Color(0xFFFFB4AB);
  static const warningOnDark = Color(0xFFFFC94D);
  static const infoOnDark = Color(0xFFA8C8FF);
  static const successOnDark = Color(0xFF8BD68F);

  // Séries dos gráficos.
  static const chartHistory = Color(0xFF0B5D5E);
  static const chartForecast = Color(0xFFC77700);
  static const chartHistoryDark = Color(0xFF7FD1CF);
  static const chartForecastDark = Color(0xFFFFB74D);

  /// Cor por domínio (dashboards).
  static const domain = <String, Color>{
    'resources': Color(0xFF1F5FA8),
    'climate': Color(0xFFC25E00),
    'waste': Color(0xFF4E7A27),
    'services': Color(0xFF7B3FA0),
  };
}

/// Espaçamentos em múltiplos de 4 (grid de 4 pt).
class AppSpacing {
  AppSpacing._();

  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 12.0;
  static const lg = 16.0;
  static const xl = 24.0;
  static const xxl = 32.0;

  static const radius = 16.0;
  static const radiusSm = 10.0;

  /// Área mínima de toque recomendada (Material / WCAG 2.5.5).
  static const minTouch = 48.0;

  static const page = EdgeInsets.all(lg);

  /// Largura máxima do conteúdo em telas grandes (tablet/web).
  static const maxContentWidth = 960.0;
}
