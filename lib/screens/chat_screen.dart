import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/message.dart';
import '../services/nearby_service.dart';

class ChatScreen extends StatefulWidget {
  final String peerId;
  const ChatScreen({super.key, required this.peerId});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final service = context.watch<NearbyService>();
    final peer = service.peers[widget.peerId];
    // This app broadcasts to all connected peers and shows one shared
    // history. For a strictly 1:1 view you'd filter messages by peer id.
    final messages = service.messages;
    _scrollToBottom();

    return Scaffold(
      appBar: AppBar(
        title: Text(peer?.name ?? 'Chat'),
      ),
      body: Column(
        children: [
          if (peer != null && !peer.isConnected)
            Container(
              width: double.infinity,
              color: Theme.of(context).colorScheme.errorContainer,
              padding: const EdgeInsets.all(8),
              child: Text(
                'Disconnected from ${peer.name}',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onErrorContainer,
                ),
              ),
            ),
          Expanded(
            child: messages.isEmpty
                ? const Center(child: Text('No messages yet — say hi!'))
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(12),
                    itemCount: messages.length,
                    itemBuilder: (context, index) =>
                        _MessageBubble(message: messages[index]),
                  ),
          ),
          _Composer(
            controller: _controller,
            enabled: peer?.isConnected ?? false,
            onSend: () {
              final text = _controller.text;
              if (text.trim().isEmpty) return;
              service.sendMessage(text);
              _controller.clear();
            },
          ),
        ],
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  final ChatMessage message;
  const _MessageBubble({required this.message});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final align = message.isMe ? Alignment.centerRight : Alignment.centerLeft;
    final color = message.isMe
        ? theme.colorScheme.primary
        : theme.colorScheme.surfaceVariant;
    final textColor =
        message.isMe ? theme.colorScheme.onPrimary : theme.colorScheme.onSurface;

    return Align(
      alignment: align,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!message.isMe)
              Padding(
                padding: const EdgeInsets.only(bottom: 2),
                child: Text(
                  message.senderName,
                  style: theme.textTheme.labelSmall
                      ?.copyWith(color: textColor.withOpacity(0.75)),
                ),
              ),
            Text(message.text, style: TextStyle(color: textColor)),
            const SizedBox(height: 2),
            Text(
              DateFormat.Hm().format(message.timestamp),
              style: theme.textTheme.labelSmall
                  ?.copyWith(color: textColor.withOpacity(0.6)),
            ),
          ],
        ),
      ),
    );
  }
}

class _Composer extends StatelessWidget {
  final TextEditingController controller;
  final bool enabled;
  final VoidCallback onSend;
  const _Composer({
    required this.controller,
    required this.enabled,
    required this.onSend,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: controller,
                enabled: enabled,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => onSend(),
                decoration: InputDecoration(
                  hintText: enabled ? 'Message' : 'Not connected',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                  ),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                ),
              ),
            ),
            const SizedBox(width: 8),
            IconButton.filled(
              onPressed: enabled ? onSend : null,
              icon: const Icon(Icons.send),
            ),
          ],
        ),
      ),
    );
  }
}
