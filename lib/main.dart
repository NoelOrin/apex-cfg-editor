import 'package:apex_cfg_editor/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

void main() => runApp(const ApexCfgEditorApp());

class ApexCfgEditorApp extends StatelessWidget {
  const ApexCfgEditorApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      onGenerateTitle: (c) => AppLocalizations.of(c)!.appTitle,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFE2483D), // Apex 红
          brightness: Brightness.dark,
        ),
        fontFamilyFallback: const ['Menlo', 'Consolas', 'monospace'],
      ),
      home: Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 无障碍语义 + lucide 图标冒烟（图标一律 lucide_icons）。
              Semantics(
                label: 'Apex CFG Editor',
                child: const Icon(
                  LucideIcons.fileText,
                  size: 48,
                  color: Color(0xFFE2483D), // Apex 红
                ),
              ),
              const SizedBox(height: 16),
              const Text('Apex CFG Editor'),
            ],
          ),
        ),
      ),
    );
  }
}
