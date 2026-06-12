import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/config.dart';
import '../auth/auth_controller.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(authControllerProvider).session;

    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: ListTile(
              leading: CircleAvatar(
                child: Text(
                  (session?.name.isNotEmpty ?? false)
                      ? session!.name[0].toUpperCase()
                      : 'G',
                ),
              ),
              title: Text(session?.name ?? 'Guest'),
              subtitle: Text(
                (session?.isGuest ?? true)
                    ? 'Guest session — create an account to keep your history'
                    : session!.email,
              ),
            ),
          ),
          const SizedBox(height: 8),
          if (session?.isGuest ?? false)
            Card(
              child: ListTile(
                leading: const Icon(Icons.person_add_alt),
                title: const Text('Create an account'),
                subtitle: const Text(
                    'Keep your contributions and access your dashboard'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.push('/register'),
              ),
            ),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.dns_outlined),
                  title: const Text('API server'),
                  subtitle: Text(AppConfig.apiBaseUrl),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.logout),
                  title: Text(
                      (session?.isGuest ?? true) ? 'End guest session' : 'Sign out'),
                  onTap: () async {
                    await ref.read(authControllerProvider.notifier).signOut();
                    if (context.mounted) context.go('/login');
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
