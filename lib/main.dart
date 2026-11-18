import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';

import 'app.dart';
import 'data/services/local_storage_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  Intl.defaultLocale = 'pt_BR';
  await initializeDateFormatting('pt_BR');
  final storage = await LocalStorageService.create();
  runApp(RadarTerritorialApp(storage: storage));
}
