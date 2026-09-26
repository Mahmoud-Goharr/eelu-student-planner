import 'package:flutter/material.dart';

import '../../../../core/localization/app_localizations.dart';

class WelcomeCard extends StatelessWidget {
  const WelcomeCard({
    required this.primaryColor,
    required this.isDark,
    this.name,
    this.avatarUrl,
    super.key,
  });

  final Color primaryColor;
  final bool isDark;
  final String? name;
  final String? avatarUrl;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final hasAvatar = avatarUrl != null && avatarUrl!.trim().isNotEmpty;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 18, 16, 18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(26),
        gradient: LinearGradient(
          colors: [
            primaryColor,
            Color.lerp(primaryColor, Colors.blue, .35)!,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: primaryColor.withValues(alpha: .20),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: .15),
              shape: BoxShape.circle,
            ),
            child: Icon(
              isDark
                  ? Icons.dark_mode_outlined
                  : Icons.wb_sunny_outlined,
              color: Colors.white,
              size: 24,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  name == null || name!.trim().isEmpty
                      ? l10n.welcomeBack
                      : '${name!.trim()} 👋',
                  textAlign: TextAlign.right,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  l10n.keepGoing,
                  textAlign: TextAlign.right,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: .85),
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          CircleAvatar(
            radius: 31,
            backgroundColor: Colors.white.withValues(alpha: .18),
            backgroundImage:
                hasAvatar ? NetworkImage(avatarUrl!) : null,
            child: hasAvatar
                ? null
                : const Icon(
                    Icons.person,
                    color: Colors.white,
                    size: 30,
                  ),
          ),
        ],
      ),
    );
  }
}
