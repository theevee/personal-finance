import 'package:flutter/material.dart';
import 'package:kabob/core/l10n/l10n.dart';
import 'package:kabob/shared/widgets/app_card.dart';

class PrivacyScreen extends StatelessWidget {
  const PrivacyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Scaffold(
      appBar: AppBar(title: Text(l.privacyPolicy)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
        children: [
          AppCard(
            child: Text(l.privacyPolicyBody, style: const TextStyle(height: 1.6)),
          ),
        ],
      ),
    );
  }
}
