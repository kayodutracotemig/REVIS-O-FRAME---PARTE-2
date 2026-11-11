import 'package:flutter/material.dart';
import 'package:device_preview/device_preview.dart';
import 'package:provider/provider.dart';

import 'pages/impressao_page.dart';
import 'providers/impressao_provider.dart';
import 'repositories/impressao_repository.dart';
import 'services/database_service.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  // DevicePreview envolve a aplicação, sem substituir o Provider nem o SQLite.
  runApp(
    DevicePreview(
      enabled: true,
      builder: (context) => ChangeNotifierProvider(
        // Monta as dependências e inicia a consulta antes de apresentar os dados.
        create: (_) =>
            ImpressaoProvider(ImpressaoRepository(DatabaseService()))
              ..iniciar(),
        child: const ImpressaoApp(),
      ),
    ),
  );
}

class ImpressaoApp extends StatelessWidget {
  const ImpressaoApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    title: 'Fila de impressão',
    // Integra locale e builder do preview para alternar aparelhos e tamanhos.
    locale: DevicePreview.locale(context),
    builder: DevicePreview.appBuilder,
    theme: ThemeData(useMaterial3: true, colorSchemeSeed: Colors.indigo),
    home: const ImpressaoPage(),
  );
}
