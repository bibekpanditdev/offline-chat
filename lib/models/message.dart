enum MessageStatus { sent, delivered, failed }

class ChatMessage {
  final String id;
  final String senderId;
  final String senderName;
  final String text;
  final DateTime timestamp;
  final bool isMe;
  MessageStatus status;

  ChatMessage({
    required this.id,
    required this.senderId,
    required this.senderName,
    required this.text,
    required this.timestamp,
    required this.isMe,
    this.status = MessageStatus.sent,
  });

  // Simple wire format: id|senderId|senderName|timestampMillis|text
  // Pipe characters inside the text are escaped so multi-field parsing stays safe.
  String toWire() {
    final safeText = text.replaceAll('|', '\u0001');
    return [
      id,
      senderId,
      senderName,
      timestamp.millisecondsSinceEpoch.toString(),
      safeText,
    ].join('|');
  }

  static ChatMessage? fromWire(String data, {required bool isMe}) {
    final parts = data.split('|');
    if (parts.length < 5) return null;
    final text = parts.sublist(4).join('|').replaceAll('\u0001', '|');
    return ChatMessage(
      id: parts[0],
      senderId: parts[1],
      senderName: parts[2],
      timestamp: DateTime.fromMillisecondsSinceEpoch(
        int.tryParse(parts[3]) ?? DateTime.now().millisecondsSinceEpoch,
      ),
      text: text,
      isMe: isMe,
    );
  }
}

class NearbyPeer {
  final String id;
  String name;
  bool isConnected;
  bool isConnecting;

  NearbyPeer({
    required this.id,
    required this.name,
    this.isConnected = false,
    this.isConnecting = false,
  });
}
