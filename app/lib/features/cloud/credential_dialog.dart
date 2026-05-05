/// Cloud-provider credential entry dialog.
///
/// Persisted as a keychain reference (see §6.5 of the v0.46 spec).
/// Submission returns a structured payload; actual keychain storage happens
/// via the FRB `cloud_save_credential` API on the caller side.
library;

import 'package:flutter/material.dart';

enum CloudProvider { aws, aliyun, k8s }

class CredentialSubmission {
  final CloudProvider provider;
  final String profileName;
  final String accessKey;
  final String secretKey;
  final String? region;

  const CredentialSubmission({
    required this.provider,
    required this.profileName,
    required this.accessKey,
    required this.secretKey,
    this.region,
  });

  /// Rendered keychain key per spec §6.5 — e.g. `cloud:aws:profile:prod`.
  String get keychainRef {
    final tag = switch (provider) {
      CloudProvider.aws => 'aws:profile',
      CloudProvider.aliyun => 'aliyun',
      CloudProvider.k8s => 'k8s:token',
    };
    return 'cloud:$tag:$profileName';
  }
}

Future<CredentialSubmission?> showCloudCredentialDialog({
  required BuildContext context,
  required CloudProvider provider,
}) {
  final profileCtrl = TextEditingController(text: 'default');
  final accessCtrl = TextEditingController();
  final secretCtrl = TextEditingController();
  final regionCtrl = TextEditingController();

  return showDialog<CredentialSubmission>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text('配置 ${_providerLabel(provider)} 凭据'),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: profileCtrl,
              decoration: const InputDecoration(labelText: 'Profile 名称'),
            ),
            TextField(
              controller: accessCtrl,
              decoration: const InputDecoration(labelText: 'Access Key ID'),
            ),
            TextField(
              controller: secretCtrl,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Secret Key'),
            ),
            TextField(
              controller: regionCtrl,
              decoration: const InputDecoration(
                labelText: 'Region',
                hintText: '例如 us-east-1 / cn-hangzhou',
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              '凭据将通过系统 Keychain 安全存储，数据库只保留引用。',
              style: TextStyle(fontSize: 11),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('取消'),
        ),
        ElevatedButton(
          onPressed: () {
            if (accessCtrl.text.isEmpty || secretCtrl.text.isEmpty) return;
            Navigator.pop(
              ctx,
              CredentialSubmission(
                provider: provider,
                profileName: profileCtrl.text.isEmpty
                    ? 'default'
                    : profileCtrl.text,
                accessKey: accessCtrl.text,
                secretKey: secretCtrl.text,
                region: regionCtrl.text.isEmpty ? null : regionCtrl.text,
              ),
            );
          },
          child: const Text('保存'),
        ),
      ],
    ),
  );
}

String _providerLabel(CloudProvider p) => switch (p) {
      CloudProvider.aws => 'AWS',
      CloudProvider.aliyun => 'Aliyun',
      CloudProvider.k8s => 'Kubernetes',
    };
