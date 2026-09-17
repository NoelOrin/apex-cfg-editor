import 'dart:io';

import 'package:apex_cfg_editor/core/update/update_service.dart';
import 'package:apex_cfg_editor/core/backup/backup_service.dart';
import 'package:apex_cfg_editor/core/diagnostics/config_diagnostics.dart';
import 'package:apex_cfg_editor/core/io/cfg_file_io.dart';
import 'package:apex_cfg_editor/core/settings/settings_store.dart';
import 'package:apex_cfg_editor/l10n/app_localizations.dart';
import 'package:apex_cfg_editor/ui/locale_preference.dart';
import 'package:apex_cfg_editor/ui/theme/acid_theme.dart';
import 'package:file_picker/file_picker.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

typedef OpenExternalUrl = Future<void> Function(Uri url);

class SettingsPage extends StatefulWidget {
  final UpdateService updateService;
  final SettingsStore? settings;
  final String backupDir;
  final String logDir;
  final String? openFilePath;
  final VoidCallback? onBack;
  final OpenExternalUrl? openUrl;
  final VoidCallback? onSettingsChanged;
  final VoidCallback? onResetSettings;

  const SettingsPage({
    super.key,
    required this.updateService,
    this.settings,
    this.backupDir = '',
    this.logDir = '',
    this.openFilePath,
    this.onBack,
    this.openUrl,
    this.onSettingsChanged,
    this.onResetSettings,
  });

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

enum _UpdateViewState { idle, checking, latest, available, error }

class _SettingsPageState extends State<SettingsPage> {
  _UpdateViewState _updateState = _UpdateViewState.idle;
  UpdateCheckResult? _result;
  late bool _autoDetectOnStartup;
  late String _preferredOpenKind;
  late bool _reopenLastFile;
  late bool _autoCreateMissingTemplate;
  late bool _backupEnabled;
  late int _backupLimit;
  late String _backupDir;
  ConfigDiagnosticsResult? _diagnostics;

  @override
  void initState() {
    super.initState();
    final settings = widget.settings;
    _autoDetectOnStartup = settings?.readAutoDetectOnStartup() ?? true;
    _preferredOpenKind = settings?.readPreferredOpenKind() ?? 'settings';
    _reopenLastFile = settings?.readReopenLastFile() ?? false;
    _autoCreateMissingTemplate =
        settings?.readAutoCreateMissingTemplate() ?? false;
    _backupEnabled = settings?.readBackupEnabled() ?? true;
    _backupLimit =
        settings?.readBackupLimit() ?? SettingsStore.defaultBackupLimit;
    _backupDir = settings?.readBackupDir() ?? widget.backupDir;
  }

  void _saveSetting(void Function(SettingsStore store) write) {
    final settings = widget.settings;
    if (settings == null) return;
    write(settings);
    widget.onSettingsChanged?.call();
  }

  void _runDiagnostics() {
    final configDir = widget.openFilePath == null
        ? ''
        : File(widget.openFilePath!).parent.path;
    setState(() {
      _diagnostics = ConfigDiagnosticsService(
        configDir: configDir,
        backupDir: _backupDir,
        openFilePath: widget.openFilePath,
      ).run();
    });
  }

  Future<void> _resetDefaults() async {
    final l = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => ContentDialog(
        title: Text(l.resetSettingsTitle),
        content: Text(l.resetSettingsBody),
        actions: [
          Button(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(l.resetSettingsConfirm),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    widget.settings?.reset();
    widget.onResetSettings?.call();
    if (!mounted) return;
    setState(() {
      _autoDetectOnStartup = true;
      _preferredOpenKind = 'settings';
      _reopenLastFile = false;
      _autoCreateMissingTemplate = false;
      _backupEnabled = true;
      _backupLimit = SettingsStore.defaultBackupLimit;
      _backupDir = widget.backupDir;
      _diagnostics = null;
    });
  }

  Future<void> _checkForUpdates() async {
    if (_updateState == _UpdateViewState.checking) return;
    setState(() {
      _updateState = _UpdateViewState.checking;
      _result = null;
    });
    try {
      final result = await widget.updateService.checkForUpdates();
      if (!mounted) return;
      setState(() {
        _result = result;
        _updateState = result.hasUpdate
            ? _UpdateViewState.available
            : _UpdateViewState.latest;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _updateState = _UpdateViewState.error);
    }
  }

  Future<void> _openRelease(Uri url) async {
    try {
      await (widget.openUrl ?? openExternalUrl)(url);
    } catch (_) {
      // 外部浏览器失败不影响编辑器，结果仍可再次点击重试。
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final theme =
        FluentTheme.maybeOf(context) ?? buildFluentTheme(Brightness.dark);
    final palette = AcidPalette.of(context);
    final localeScope = LocalePreferenceScope.maybeOf(context);

    return FluentThemeFallback(
      child: Container(
        color: theme.scaffoldBackgroundColor,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(28, 26, 28, 36),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 760),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      if (widget.onBack != null) ...[
                        Tooltip(
                          message: l.back,
                          child: IconButton(
                            icon: const Icon(LucideIcons.arrowLeft),
                            onPressed: widget.onBack,
                          ),
                        ),
                        const SizedBox(width: 10),
                      ],
                      Text(
                        l.settings,
                        style: TextStyle(
                          fontFamily: kFontDisplay,
                          fontSize: 25,
                          fontWeight: FontWeight.w700,
                          color: palette.text,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    l.interfaceSection,
                    style: TextStyle(
                      fontFamily: kFontUi,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.8,
                      color: palette.textMuted,
                    ),
                  ),
                  const SizedBox(height: 10),
                  _buildLanguagePanel(l, palette, localeScope),
                  const SizedBox(height: 24),
                  Text(
                    l.updateSection,
                    style: TextStyle(
                      fontFamily: kFontUi,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.8,
                      color: palette.textMuted,
                    ),
                  ),
                  const SizedBox(height: 10),
                  _buildUpdatePanel(context, l, palette),
                  const SizedBox(height: 24),
                  Text(
                    l.fileBehaviorSection,
                    style: TextStyle(
                      fontFamily: kFontUi,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.8,
                      color: palette.textMuted,
                    ),
                  ),
                  const SizedBox(height: 10),
                  _buildFileBehaviorPanel(l, palette),
                  const SizedBox(height: 24),
                  Text(
                    l.backupSection,
                    style: TextStyle(
                      fontFamily: kFontUi,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.8,
                      color: palette.textMuted,
                    ),
                  ),
                  const SizedBox(height: 10),
                  _buildBackupPanel(l, palette),
                  const SizedBox(height: 24),
                  Text(
                    l.diagnosticsSection,
                    style: TextStyle(
                      fontFamily: kFontUi,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.8,
                      color: palette.textMuted,
                    ),
                  ),
                  const SizedBox(height: 10),
                  _buildDiagnosticsPanel(l, palette),
                  const SizedBox(height: 24),
                  Text(
                    l.appInfoSection,
                    style: TextStyle(
                      fontFamily: kFontUi,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.8,
                      color: palette.textMuted,
                    ),
                  ),
                  const SizedBox(height: 10),
                  _buildApplicationInfoPanel(l, palette),
                  const SizedBox(height: 24),
                  Text(
                    l.resetSection,
                    style: TextStyle(
                      fontFamily: kFontUi,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.8,
                      color: palette.textMuted,
                    ),
                  ),
                  const SizedBox(height: 10),
                  _buildResetPanel(l, palette),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLanguagePanel(
    AppLocalizations l,
    AcidPalette palette,
    LocalePreferenceScope? scope,
  ) {
    final preference = scope?.preference ?? AppLocalePreference.system;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: palette.panel,
        border: Border.all(color: palette.chrome.withValues(alpha: 0.28)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 42,
                height: 42,
                alignment: Alignment.center,
                color: palette.acid,
                child: Icon(
                  LucideIcons.languages,
                  size: 20,
                  color: palette.onAcid,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l.language,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: palette.text,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      l.languageDescription,
                      style: TextStyle(color: palette.textMuted),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          RadioGroup<AppLocalePreference>(
            groupValue: preference,
            onChanged: (value) {
              if (value != null) scope?.onChanged(value);
            },
            child: Wrap(
              spacing: 24,
              runSpacing: 10,
              children: [
                RadioButton<AppLocalePreference>(
                  value: AppLocalePreference.system,
                  content: Text(l.languageSystem),
                  enabled: scope != null,
                ),
                RadioButton<AppLocalePreference>(
                  value: AppLocalePreference.zh,
                  content: Text(l.languageChinese),
                  enabled: scope != null,
                ),
                RadioButton<AppLocalePreference>(
                  value: AppLocalePreference.en,
                  content: Text(l.languageEnglish),
                  enabled: scope != null,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _panel({required Widget child, required AcidPalette palette}) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: palette.panel,
        border: Border.all(color: palette.chrome.withValues(alpha: 0.28)),
      ),
      child: child,
    );
  }

  Widget _infoRow(String label, String value, AcidPalette palette) {
    final l = AppLocalizations.of(context)!;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 170,
            child: Text(label, style: TextStyle(color: palette.textMuted)),
          ),
          Expanded(
            child: Text(
              value.isEmpty ? l.notAvailable : value,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: palette.text),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildApplicationInfoPanel(AppLocalizations l, AcidPalette palette) {
    final configDir = widget.openFilePath == null
        ? ''
        : File(widget.openFilePath!).parent.path;
    return _panel(
      palette: palette,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _infoRow(
            l.buildNumber,
            kAppBuildNumber == '0' ? l.notAvailable : kAppBuildNumber,
            palette,
          ),
          _infoRow(l.repository, kRepositoryUri.toString(), palette),
          _infoRow(l.license, l.mitLicense, palette),
          _infoRow(l.configDirectory, configDir, palette),
          _infoRow(l.backupDirectory, _backupDir, palette),
          _infoRow(l.logDirectory, widget.logDir, palette),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: HyperlinkButton(
              onPressed: () => _openRelease(kRepositoryUri),
              child: Text(l.openInBrowser),
            ),
          ),
        ],
      ),
    );
  }

  Widget _settingSwitch(
    String label,
    bool value,
    ValueChanged<bool> onChanged,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: ToggleSwitch(
        checked: value,
        onChanged: widget.settings == null ? null : onChanged,
        content: Text(label),
      ),
    );
  }

  Widget _buildFileBehaviorPanel(AppLocalizations l, AcidPalette palette) {
    return _panel(
      palette: palette,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _settingSwitch(l.autoDetectOnStartup, _autoDetectOnStartup, (value) {
            setState(() => _autoDetectOnStartup = value);
            _saveSetting((s) => s.writeAutoDetectOnStartup(value));
          }),
          const SizedBox(height: 8),
          Text(l.preferredOpenKind, style: TextStyle(color: palette.textMuted)),
          const SizedBox(height: 6),
          RadioGroup<String>(
            groupValue: _preferredOpenKind,
            onChanged: (value) {
              if (widget.settings == null) return;
              if (value == null) return;
              setState(() => _preferredOpenKind = value);
              _saveSetting((s) => s.writePreferredOpenKind(value));
            },
            child: Wrap(
              spacing: 24,
              runSpacing: 10,
              children: [
                RadioButton<String>(
                  value: 'settings',
                  content: Text(l.preferredSettings),
                  enabled: widget.settings != null,
                ),
                RadioButton<String>(
                  value: 'videoconfig',
                  content: Text(l.preferredVideoconfig),
                  enabled: widget.settings != null,
                ),
                RadioButton<String>(
                  value: 'autoexec',
                  content: Text(l.preferredAutoexec),
                  enabled: widget.settings != null,
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          _settingSwitch(l.reopenLastFile, _reopenLastFile, (value) {
            setState(() => _reopenLastFile = value);
            _saveSetting((s) => s.writeReopenLastFile(value));
          }),
          _settingSwitch(
            l.autoCreateMissingTemplate,
            _autoCreateMissingTemplate,
            (value) {
              setState(() => _autoCreateMissingTemplate = value);
              _saveSetting((s) => s.writeAutoCreateMissingTemplate(value));
            },
          ),
        ],
      ),
    );
  }

  Future<void> _chooseBackupDir() async {
    final selected = await FilePicker.getDirectoryPath(
      initialDirectory: _backupDir.isEmpty ? null : _backupDir,
    );
    if (selected == null || selected.isEmpty || !mounted) return;
    setState(() => _backupDir = selected);
    _saveSetting((s) => s.writeBackupDir(selected));
  }

  Future<void> _openPath(String path) async {
    if (path.isEmpty) return;
    try {
      if (Platform.isWindows) {
        await Process.start('explorer.exe', [path]);
      } else if (Platform.isMacOS) {
        await Process.start('open', [path]);
      } else {
        await Process.start('xdg-open', [path]);
      }
    } catch (_) {}
  }

  Future<void> _cleanBackups() async {
    final l = AppLocalizations.of(context)!;
    final service = BackupService(baseDir: _backupDir);
    final removed = service.pruneAll(_backupLimit);
    if (!mounted) return;
    displayInfoBar(
      context,
      builder: (context, close) => InfoBar(
        title: Text(l.cleanedBackups(removed)),
        severity: InfoBarSeverity.success,
        onClose: close,
      ),
    );
  }

  Widget _buildBackupPanel(AppLocalizations l, AcidPalette palette) {
    return _panel(
      palette: palette,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _settingSwitch(l.enableBackups, _backupEnabled, (value) {
            setState(() => _backupEnabled = value);
            _saveSetting((s) => s.writeBackupEnabled(value));
          }),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(child: Text(l.backupLimit)),
              SizedBox(
                width: 120,
                child: NumberBox<int>(
                  value: _backupLimit,
                  min: SettingsStore.minBackupLimit,
                  max: SettingsStore.maxBackupLimit,
                  smallChange: 1,
                  onChanged: widget.settings == null
                      ? null
                      : (value) {
                          if (value == null) return;
                          setState(() => _backupLimit = value);
                          _saveSetting((s) => s.writeBackupLimit(value));
                        },
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
            decoration: BoxDecoration(
              border: Border.all(color: palette.chrome.withValues(alpha: 0.28)),
            ),
            child: Text(
              _backupDir.isEmpty ? l.notAvailable : _backupDir,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: palette.textMuted),
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              Button(
                onPressed: widget.settings == null ? null : _chooseBackupDir,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(LucideIcons.folder, size: 15),
                    const SizedBox(width: 6),
                    Text(l.chooseDirectory),
                  ],
                ),
              ),
              Button(
                onPressed: _backupDir.isEmpty
                    ? null
                    : () => _openPath(_backupDir),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(LucideIcons.externalLink, size: 15),
                    const SizedBox(width: 6),
                    Text(l.openDirectory),
                  ],
                ),
              ),
              Button(
                onPressed: _backupDir.isEmpty ? null : _cleanBackups,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(LucideIcons.trash2, size: 15),
                    const SizedBox(width: 6),
                    Text(l.cleanOldBackups),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDiagnosticsPanel(AppLocalizations l, AcidPalette palette) {
    final result = _diagnostics;
    return _panel(
      palette: palette,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: Button(
              onPressed: _runDiagnostics,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(LucideIcons.stethoscope, size: 15),
                  const SizedBox(width: 6),
                  Text(l.runDiagnostics),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          if (result == null)
            Text(
              l.diagnosticsNotRun,
              style: TextStyle(color: palette.textMuted),
            )
          else ...[
            _infoRow(
              l.configDirectoryExists,
              result.configDirExists ? l.yes : l.no,
              palette,
            ),
            _infoRow(
              l.configDirectoryWritable,
              result.configDirWritable ? l.yes : l.no,
              palette,
            ),
            _infoRow(
              l.encoding,
              result.encoding == CfgEncoding.utf8
                  ? l.encodingUtf8
                  : result.encoding == CfgEncoding.gbk
                  ? l.encodingGbk
                  : l.encodingUnknown,
              palette,
            ),
            _infoRow(
              l.latestBackup,
              result.latestBackupTime?.toLocal().toString() ?? l.noBackup,
              palette,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildResetPanel(AppLocalizations l, AcidPalette palette) {
    return _panel(
      palette: palette,
      child: Align(
        alignment: AlignmentDirectional.centerStart,
        child: Button(
          onPressed: widget.settings == null ? null : _resetDefaults,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(LucideIcons.rotateCcw, size: 15),
              const SizedBox(width: 6),
              Text(l.resetSettings),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildUpdatePanel(
    BuildContext context,
    AppLocalizations l,
    AcidPalette palette,
  ) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: palette.panel,
        border: Border.all(color: palette.chrome.withValues(alpha: 0.28)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 42,
                height: 42,
                alignment: Alignment.center,
                color: palette.acid,
                child: Icon(
                  LucideIcons.refreshCw,
                  size: 20,
                  color: palette.onAcid,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(l.currentVersion),
                    const SizedBox(height: 3),
                    Text(
                      'v${widget.updateService.currentVersion}',
                      style: TextStyle(
                        fontFamily: kFontDisplay,
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: palette.text,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              FilledButton(
                onPressed: _updateState == _UpdateViewState.checking
                    ? null
                    : _checkForUpdates,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_updateState == _UpdateViewState.checking) ...[
                      const SizedBox(
                        width: 14,
                        height: 14,
                        child: ProgressRing(strokeWidth: 2),
                      ),
                      const SizedBox(width: 8),
                    ] else ...[
                      const Icon(LucideIcons.refreshCw, size: 15),
                      const SizedBox(width: 8),
                    ],
                    Text(l.checkForUpdates),
                  ],
                ),
              ),
            ],
          ),
          if (_updateState != _UpdateViewState.idle) ...[
            const SizedBox(height: 18),
            _buildUpdateStatus(l),
          ],
        ],
      ),
    );
  }

  Widget _buildUpdateStatus(AppLocalizations l) {
    switch (_updateState) {
      case _UpdateViewState.checking:
        return Row(
          children: [
            const SizedBox(
              width: 16,
              height: 16,
              child: ProgressRing(strokeWidth: 2),
            ),
            const SizedBox(width: 10),
            Text(l.checkingForUpdates),
          ],
        );
      case _UpdateViewState.latest:
        return InfoBar(
          title: Text(l.upToDate),
          severity: InfoBarSeverity.success,
        );
      case _UpdateViewState.available:
        final result = _result!;
        return InfoBar(
          title: Text(
            l.newVersionAvailable('v${result.latestRelease.version}'),
          ),
          content: Text(result.latestRelease.name),
          severity: InfoBarSeverity.info,
          action: HyperlinkButton(
            onPressed: () => _openRelease(result.latestRelease.url),
            child: Text(l.viewReleaseNotes),
          ),
        );
      case _UpdateViewState.error:
        return InfoBar(
          title: Text(l.updateCheckFailed),
          content: Text(l.updateCheckFailedHint),
          severity: InfoBarSeverity.error,
        );
      case _UpdateViewState.idle:
        return const SizedBox.shrink();
    }
  }
}

Future<void> openExternalUrl(Uri url) async {
  if (Platform.isWindows) {
    await Process.start('cmd.exe', ['/c', 'start', '', url.toString()]);
  } else if (Platform.isMacOS) {
    await Process.start('open', [url.toString()]);
  } else {
    await Process.start('xdg-open', [url.toString()]);
  }
}
