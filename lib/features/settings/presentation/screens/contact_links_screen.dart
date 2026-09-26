import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/constants/asset_paths.dart';
import '../../../../core/constants/contact_constants.dart';
import '../../../../core/localization/app_localizations.dart';

class ContactLinksScreen extends StatelessWidget {
  const ContactLinksScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final contacts = [
      _ContactItem(
        assetPath: AssetPaths.whatsapp,
        title: l10n.whatsapp,
        description: l10n.contactWhatsappDescription,
        value: ContactConstants.whatsapp,
      ),
      _ContactItem(
        assetPath: AssetPaths.email,
        title: l10n.emailContact,
        description: l10n.contactEmailDescription,
        value: ContactConstants.email,
      ),
      _ContactItem(
        assetPath: AssetPaths.linkedin,
        title: l10n.linkedin,
        description: l10n.contactLinkedinDescription,
        value: ContactConstants.linkedin,
      ),
      _ContactItem(
        assetPath: AssetPaths.github,
        title: l10n.github,
        description: l10n.contactGithubDescription,
        value: ContactConstants.github,
      ),
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.contactAndLinksTitle),
      ),
      body: ListView.separated(
        padding: const EdgeInsets.all(20),
        itemCount: contacts.length,
        separatorBuilder: (_, _) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final contact = contacts[index];
          final theme = Theme.of(context);

          return Card(
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 8,
              ),
              leading: _ContactLogo(assetPath: contact.assetPath),
              title: Text(
                contact.title,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              subtitle: Text(contact.description),
              trailing: Icon(
                Icons.open_in_new_rounded,
                size: 18,
                color: theme.colorScheme.onSurfaceVariant,
              ),
              onTap: () => _openContact(context, contact.value),
            ),
          );
        },
      ),
    );
  }

  Future<void> _openContact(
    BuildContext context,
    String value,
  ) async {
    final uri = Uri.parse(value.contains('@') ? 'mailto:$value' : value);

    try {
      final launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );

      if (!launched && context.mounted) {
        _showLaunchError(context);
      }
    } on Exception {
      if (context.mounted) {
        _showLaunchError(context);
      }
    }
  }

  void _showLaunchError(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          AppLocalizations.of(context).unableToOpenLink,
        ),
      ),
    );
  }
}

class _ContactLogo extends StatelessWidget {
  const _ContactLogo({required this.assetPath});

  final String assetPath;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: 48,
        height: 48,
        padding: const EdgeInsets.all(7),
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        child: Image.asset(
          assetPath,
          fit: BoxFit.contain,
          errorBuilder: (_, _, _) {
            return Icon(
              Icons.link_rounded,
              color: Theme.of(context).colorScheme.primary,
            );
          },
        ),
      ),
    );
  }
}

class _ContactItem {
  const _ContactItem({
    required this.assetPath,
    required this.title,
    required this.description,
    required this.value,
  });

  final String assetPath;
  final String title;
  final String description;
  final String value;
}
