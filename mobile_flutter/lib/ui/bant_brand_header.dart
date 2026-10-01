import 'package:flutter/material.dart';

import '../models/profile.dart';
import 'bant_theme.dart';

class BantBrandHeader extends StatelessWidget {
  final BantProfile profile;
  final int unread;
  final VoidCallback? onNotifications;

  const BantBrandHeader({
    super.key,
    required this.profile,
    this.unread = 0,
    this.onNotifications,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 54,
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: const Color(0xFFE8F4FF),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Text(
              'B',
              style: TextStyle(
                color: BantTheme.blue,
                fontSize: 24,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFE8F4FF),
              borderRadius: BorderRadius.circular(999),
            ),
            child: const Text(
              'BANT',
              style: TextStyle(
                color: BantTheme.blue,
                fontSize: 12,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const Spacer(),
          Stack(
            clipBehavior: Clip.none,
            children: [
              IconButton(
                onPressed: onNotifications,
                icon: const Icon(
                  Icons.notifications_none_rounded,
                  color: BantTheme.secondary,
                ),
              ),
              if (unread > 0)
                Positioned(
                  right: 2,
                  top: 2,
                  child: Container(
                    constraints: const BoxConstraints(minWidth: 17),
                    height: 17,
                    alignment: Alignment.center,
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    decoration: BoxDecoration(
                      color: BantTheme.danger,
                      borderRadius: BorderRadius.circular(99),
                    ),
                    child: Text(
                      unread > 9 ? '9+' : '$unread',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 9,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 7),
          CircleAvatar(
            radius: 19,
            backgroundColor: const Color(0xFFE8F4FF),
            backgroundImage: profile.avatarUrl != null
                ? NetworkImage(profile.avatarUrl!)
                : null,
            child: profile.avatarUrl == null
                ? Text(
                    profile.displayName.isEmpty
                        ? 'B'
                        : profile.displayName.characters.first.toUpperCase(),
                    style: const TextStyle(
                      color: BantTheme.blue,
                      fontWeight: FontWeight.w900,
                    ),
                  )
                : null,
          ),
        ],
      ),
    );
  }
}
