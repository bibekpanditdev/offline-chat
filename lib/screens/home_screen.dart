import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/message.dart';
import '../services/nearby_service.dart';
import 'chat_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _starting = false;
  bool _permissionsDenied = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _start());
  }

  Future<void> _start() async {
    setState(() => _starting = true);
    final service = context.read<NearbyService>();
    final granted = await service.requestPermissions();
    if (!granted) {
      setState(() {
        _starting = false;
        _permissionsDenied = true;
      });
      return;
    }
    await service.startAdvertising();
    await service.startDiscovery();
    setState(() => _starting = false);
  }

  @override
  void dispose() {
    context.read<NearbyService>().stopAll();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final service = context.watch<NearbyService>();
    final peers = service.peers.values.toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Offline Chat'),
        actions: [
          IconButton(
            tooltip: 'My display name',
            icon: const Icon(Icons.person_outline),
            onPressed: () => _editName(context, service),
          ),
        ],
      ),
      body: _permissionsDenied
          ? _PermissionsBlockedView(onRetry: _start)
          : Column(
              children: [
                _StatusBanner(starting: _starting, service: service),
                Expanded(
                  child: peers.isEmpty
                      ? _EmptyState(starting: _starting)
                      : ListView.separated(
                          padding: const EdgeInsets.all(12),
                          itemCount: peers.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 8),
                          itemBuilder: (context, index) {
                            final peer = peers[index];
                            return _PeerTile(peer: peer, service: service);
                          },
                        ),
                ),
              ],
            ),
    );
  }

  void _editName(BuildContext context, NearbyService service) {
    final controller = TextEditingController(text: service.myName);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Your display name'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Shown to nearby devices'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              service.setDisplayName(controller.text);
              Navigator.pop(context);
              // Restart advertising so the new name is broadcast.
              service.stopAdvertising().then((_) => service.startAdvertising());
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }
}

class _StatusBanner extends StatelessWidget {
  final bool starting;
  final NearbyService service;
  const _StatusBanner({required this.starting, required this.service});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    String text;
    IconData icon;
    if (starting) {
      text = 'Starting Bluetooth/WiFi discovery…';
      icon = Icons.sync;
    } else if (service.isAdvertising && service.isDiscovering) {
      text = 'Visible & scanning as "${service.myName}" — no internet used';
      icon = Icons.wifi_tethering;
    } else {
      text = 'Discovery is off';
      icon = Icons.wifi_off;
    }
    return Container(
      width: double.infinity,
      color: theme.colorScheme.surfaceVariant,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          Icon(icon, size: 18, color: theme.colorScheme.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text, style: theme.textTheme.bodySmall),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final bool starting;
  const _EmptyState({required this.starting});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.bluetooth_searching,
                size: 56, color: Theme.of(context).colorScheme.outline),
            const SizedBox(height: 16),
            Text(
              starting
                  ? 'Looking for nearby devices…'
                  : 'No devices found yet',
              style: Theme.of(context).textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Open this app on another Android phone nearby with '
              'Bluetooth, Location, and WiFi turned on.',
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _PermissionsBlockedView extends StatelessWidget {
  final VoidCallback onRetry;
  const _PermissionsBlockedView({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.warning_amber_rounded,
                size: 56, color: Theme.of(context).colorScheme.error),
            const SizedBox(height: 16),
            const Text(
              'Bluetooth, Location, and Nearby Devices permissions are '
              'required to find other phones without internet.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            FilledButton(onPressed: onRetry, child: const Text('Grant permissions')),
          ],
        ),
      ),
    );
  }
}

class _PeerTile extends StatelessWidget {
  final NearbyPeer peer;
  final NearbyService service;
  const _PeerTile({required this.peer, required this.service});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: peer.isConnected
              ? Theme.of(context).colorScheme.primary
              : Theme.of(context).colorScheme.surfaceVariant,
          child: Icon(
            Icons.phone_android,
            color: peer.isConnected
                ? Theme.of(context).colorScheme.onPrimary
                : Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        title: Text(peer.name),
        subtitle: Text(
          peer.isConnected
              ? 'Connected'
              : peer.isConnecting
                  ? 'Connecting…'
                  : 'Tap to connect',
        ),
        trailing: peer.isConnecting
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : peer.isConnected
                ? const Icon(Icons.chat_bubble_outline)
                : const Icon(Icons.chevron_right),
        onTap: () {
          if (peer.isConnected) {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => ChatScreen(peerId: peer.id)),
            );
          } else if (!peer.isConnecting) {
            service.requestConnection(peer.id);
          }
        },
      ),
    );
  }
}
