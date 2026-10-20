// SPDX-FileCopyrightText: 2026 Magic Lane International B.V. <info@magiclane.com>
// SPDX-License-Identifier: Apache-2.0
//
// Contact Magic Lane at <info@magiclane.com> for SDK licensing options.

import 'package:activation_companion/ui/pages/offline_key_page.dart';
import 'package:activation_companion/ui/widgets/page_body.dart';
import 'package:flutter/material.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Activation Companion')),
      body: PageBody(
        children: [
          Text(
            'For devices without an internet connection: scan or paste the request shown by the device, '
            'then type the key you get here back into the device.',
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          const SizedBox(height: 16),
          _ActionCard(
            icon: Icons.verified_outlined,
            title: 'Activate a device',
            description: 'Get the key that activates a device.',
            onTap: () => Navigator.of(context).push(OfflineKeyPage.activationRoute()),
          ),
          _ActionCard(
            icon: Icons.link_off,
            title: 'Deactivate a device',
            description: 'Get the key that deactivates a device and frees its license for another one.',
            onTap: () => Navigator.of(context).push(OfflineKeyPage.deactivationRoute()),
          ),
        ],
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  const _ActionCard({required this.icon, required this.title, required this.description, required this.onTap});

  final IconData icon;
  final String title;
  final String description;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Icon(icon, size: 32),
        title: Text(title),
        subtitle: Text(description),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}
