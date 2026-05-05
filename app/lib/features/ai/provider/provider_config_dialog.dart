import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../design/tokens.dart';
import '../state/conversation_provider.dart';
import '../state/provider_config_provider.dart';
import 'provider_registry.dart';

/// Dialog to configure API key, model, and options for one AI provider.
Future<void> showProviderConfigDialog(
  BuildContext context,
  AiProvider provider,
) async {
  await showDialog<void>(
    context: context,
    builder: (_) => _ProviderConfigDialog(provider: provider),
  );
}

class _ProviderConfigDialog extends ConsumerStatefulWidget {
  final AiProvider provider;
  const _ProviderConfigDialog({required this.provider});

  @override
  ConsumerState<_ProviderConfigDialog> createState() =>
      _ProviderConfigDialogState();
}

class _ProviderConfigDialogState extends ConsumerState<_ProviderConfigDialog> {
  late final TextEditingController _apiKeyCtrl;
  late final TextEditingController _baseUrlCtrl;
  late String _selectedModel;
  late int _contextLines;
  bool _obscureKey = true;

  @override
  void initState() {
    super.initState();
    final config = ref.read(providerConfigProvider).configs[widget.provider] ??
        AiProviderConfig(
          provider: widget.provider,
          model: kDefaultModel[widget.provider]!,
        );
    _apiKeyCtrl = TextEditingController(text: config.apiKey ?? '');
    _baseUrlCtrl = TextEditingController(
      text: config.baseUrl ?? (widget.provider == AiProvider.ollama ? 'http://localhost:11434' : ''),
    );
    _selectedModel = config.model;
    _contextLines = config.contextLines;
  }

  @override
  void dispose() {
    _apiKeyCtrl.dispose();
    _baseUrlCtrl.dispose();
    super.dispose();
  }

  void _save() {
    final config = AiProviderConfig(
      provider: widget.provider,
      model: _selectedModel,
      apiKey: _apiKeyCtrl.text.trim().isEmpty ? null : _apiKeyCtrl.text.trim(),
      baseUrl: _baseUrlCtrl.text.trim().isEmpty ? null : _baseUrlCtrl.text.trim(),
      contextLines: _contextLines,
    );
    ref.read(providerConfigProvider.notifier).updateConfig(config);
    Navigator.of(context).pop();
  }

  Future<void> _verify() async {
    final key = _apiKeyCtrl.text.trim();
    if (key.isEmpty) return;
    await ref
        .read(providerConfigProvider.notifier)
        .verifyApiKey(widget.provider, key);
  }

  @override
  Widget build(BuildContext context) {
    final meta = metaFor(widget.provider);
    final configState = ref.watch(providerConfigProvider);

    return AlertDialog(
      backgroundColor: TermexColors.backgroundSecondary,
      title: Text(
        '配置 ${meta.label}',
        style: TextStyle(fontSize: 15, color: TermexColors.textPrimary),
      ),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                meta.description,
                style:
                    TextStyle(fontSize: 12, color: TermexColors.textSecondary),
              ),
              const SizedBox(height: 16),

              // API key
              if (meta.requiresApiKey) ...[
                _Label('API Key'),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _apiKeyCtrl,
                        obscureText: _obscureKey,
                        decoration: _inputDecoration(
                          hint: '${meta.label} API key',
                          suffix: GestureDetector(
                            onTap: () =>
                                setState(() => _obscureKey = !_obscureKey),
                            child: Icon(
                              _obscureKey
                                  ? Icons.visibility_off
                                  : Icons.visibility,
                              size: 16,
                              color: TermexColors.textSecondary,
                            ),
                          ),
                        ),
                        style: _inputStyle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    _VerifyButton(
                      isVerifying: configState.isVerifying,
                      onTap: _verify,
                    ),
                  ],
                ),
                if (configState.verifyError != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      configState.verifyError!,
                      style: TextStyle(
                          fontSize: 11, color: TermexColors.danger),
                    ),
                  ),
                const SizedBox(height: 12),
              ],

              // Base URL
              if (meta.requiresBaseUrl) ...[
                _Label('Base URL'),
                TextField(
                  controller: _baseUrlCtrl,
                  decoration: _inputDecoration(hint: 'http://localhost:11434'),
                  style: _inputStyle,
                ),
                const SizedBox(height: 12),
              ],

              // Model selector
              _Label('模型'),
              DropdownButtonFormField<String>(
                value: _selectedModel,
                dropdownColor: TermexColors.backgroundSecondary,
                style: _inputStyle,
                decoration: _inputDecoration(hint: ''),
                items: meta.models
                    .map((m) => DropdownMenuItem(value: m, child: Text(m)))
                    .toList(),
                onChanged: (v) => setState(() => _selectedModel = v!),
              ),
              const SizedBox(height: 12),

              // Context lines
              _Label('终端上下文行数'),
              DropdownButtonFormField<int>(
                value: _contextLines,
                dropdownColor: TermexColors.backgroundSecondary,
                style: _inputStyle,
                decoration: _inputDecoration(hint: ''),
                items: const [50, 100, 200, 500]
                    .map((n) =>
                        DropdownMenuItem(value: n, child: Text('$n 行')))
                    .toList(),
                onChanged: (v) => setState(() => _contextLines = v!),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text('取消',
              style: TextStyle(color: TermexColors.textSecondary)),
        ),
        ElevatedButton(
          onPressed: _save,
          style: ElevatedButton.styleFrom(
            backgroundColor: TermexColors.primary,
            foregroundColor: Colors.white,
          ),
          child: const Text('保存'),
        ),
      ],
    );
  }

  InputDecoration _inputDecoration({required String hint, Widget? suffix}) =>
      InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: TermexColors.textSecondary, fontSize: 12),
        suffixIcon: suffix,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: BorderSide(color: TermexColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: BorderSide(color: TermexColors.border),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        isDense: true,
      );

  TextStyle get _inputStyle =>
      TextStyle(fontSize: 12, color: TermexColors.textPrimary);
}

class _Label extends StatelessWidget {
  final String text;
  const _Label(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: TermexColors.textSecondary,
        ),
      ),
    );
  }
}

class _VerifyButton extends StatelessWidget {
  final bool isVerifying;
  final VoidCallback onTap;
  const _VerifyButton({required this.isVerifying, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: isVerifying ? null : onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          border: Border.all(color: TermexColors.border),
          borderRadius: BorderRadius.circular(6),
        ),
        child: isVerifying
            ? SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: TermexColors.primary,
                ),
              )
            : Text(
                '验证',
                style: TextStyle(
                    fontSize: 12, color: TermexColors.textSecondary),
              ),
      ),
    );
  }
}
