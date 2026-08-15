import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:nearby_connections/nearby_connections.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:uuid/uuid.dart';

import '../models/message.dart';

/// Service name shared by every instance of the app so devices can find
/// each other. Must be identical on both ends of a connection.
const String kServiceId = 'com.example.offline_chat.service';

/// Wraps Google's Nearby Connections API (via the nearby_connections plugin)
/// to provide advertising, discovery, connection management, and message
/// send/receive, all without any internet connection. Works over a
/// combination of Bluetooth, BLE, and WiFi Direct depending on what the
/// plugin/OS negotiates.
class NearbyService extends ChangeNotifier {
  final Nearby _nearby = Nearby();
  final Uuid _uuid = const Uuid();

  String myId = '';
  String myName = 'Device-${DateTime.now().millisecondsSinceEpoch % 10000}';

  bool isAdvertising = false;
  bool isDiscovering = false;

  final Map<String, NearbyPeer> peers = {}; // endpointId -> peer
  final List<ChatMessage> messages = [];

  /// Notified with (peerId, message) any time a new message is fully
  /// received. Screens can use this to scroll / show notifications.
  void Function(ChatMessage message)? onMessageReceived;

  NearbyService() {
    myId = _uuid.v4().substring(0, 8);
  }

  void setDisplayName(String name) {
    myName = name.trim().isEmpty ? myName : name.trim();
  }

  // ---------------------------------------------------------------------
  // Permissions
  // ---------------------------------------------------------------------

  /// Requests every runtime permission Nearby Connections needs on Android.
  /// Returns true only if all required permissions were granted.
  Future<bool> requestPermissions() async {
    final statuses = await [
      Permission.bluetooth,
      Permission.bluetoothAdvertise,
      Permission.bluetoothConnect,
      Permission.bluetoothScan,
      Permission.location, // still required pre-Android 12 and by some OEMs
      Permission.nearbyWifiDevices,
    ].request();

    return statuses.values.every(
      (status) => status.isGranted || status.isLimited,
    );
  }

  // ---------------------------------------------------------------------
  // Advertising + Discovery
  // ---------------------------------------------------------------------

  /// Makes this device visible to others nearby ("host" role). Any device
  /// can advertise and discover simultaneously — there's no fixed
  /// client/server split, which is what makes this genuinely peer-to-peer.
  Future<void> startAdvertising() async {
    if (isAdvertising) return;
    try {
      await _nearby.startAdvertising(
        myName,
        Strategy.P2P_CLUSTER,
        onConnectionInitiated: _onConnectionInitiated,
        onConnectionResult: _onConnectionResult,
        onDisconnected: _onDisconnected,
        serviceId: kServiceId,
      );
      isAdvertising = true;
      notifyListeners();
    } catch (e) {
      debugPrint('startAdvertising failed: $e');
    }
  }

  /// Actively looks for other devices already advertising nearby.
  Future<void> startDiscovery() async {
    if (isDiscovering) return;
    try {
      await _nearby.startDiscovery(
        myName,
        Strategy.P2P_CLUSTER,
        onEndpointFound: (id, name, serviceId) {
          peers[id] = NearbyPeer(id: id, name: name);
          notifyListeners();
        },
        onEndpointLost: (id) {
          if (id != null) {
            peers.remove(id);
            notifyListeners();
          }
        },
        serviceId: kServiceId,
      );
      isDiscovering = true;
      notifyListeners();
    } catch (e) {
      debugPrint('startDiscovery failed: $e');
    }
  }

  Future<void> stopAdvertising() async {
    await _nearby.stopAdvertising();
    isAdvertising = false;
    notifyListeners();
  }

  Future<void> stopDiscovery() async {
    await _nearby.stopDiscovery();
    isDiscovering = false;
    notifyListeners();
  }

  // ---------------------------------------------------------------------
  // Connection lifecycle
  // ---------------------------------------------------------------------

  /// Sends a connection request to a discovered peer.
  Future<void> requestConnection(String endpointId) async {
    final peer = peers[endpointId];
    if (peer == null) return;
    peer.isConnecting = true;
    notifyListeners();
    try {
      await _nearby.requestConnection(
        myName,
        endpointId,
        onConnectionInitiated: _onConnectionInitiated,
        onConnectionResult: _onConnectionResult,
        onDisconnected: _onDisconnected,
      );
    } catch (e) {
      debugPrint('requestConnection failed: $e');
      peer.isConnecting = false;
      notifyListeners();
    }
  }

  void _onConnectionInitiated(String id, ConnectionInfo info) {
    // Auto-accept. For a production app, surface a confirmation dialog
    // here (info.authenticationDigits lets both users verify they're
    // pairing with the right physical device).
    _nearby.acceptConnection(
      id,
      onPayLoadRecieved: _onPayloadReceived,
      onPayloadTransferUpdate: (endpointId, payloadTransferUpdate) {},
    );
    peers.putIfAbsent(id, () => NearbyPeer(id: id, name: info.endpointName));
    peers[id]!.name = info.endpointName;
    notifyListeners();
  }

  void _onConnectionResult(String id, Status status) {
    final peer = peers[id];
    if (peer == null) return;
    peer.isConnecting = false;
    peer.isConnected = status == Status.CONNECTED;
    notifyListeners();
  }

  void _onDisconnected(String id) {
    final peer = peers[id];
    if (peer != null) {
      peer.isConnected = false;
      peer.isConnecting = false;
    }
    notifyListeners();
  }

  Future<void> disconnect(String endpointId) async {
    await _nearby.disconnectFromEndpoint(endpointId);
    peers[endpointId]?.isConnected = false;
    notifyListeners();
  }

  // ---------------------------------------------------------------------
  // Messaging
  // ---------------------------------------------------------------------

  /// Sends a text message to every currently connected peer (broadcast).
  /// Also appends the message to local history immediately.
  Future<void> sendMessage(String text) async {
    if (text.trim().isEmpty) return;
    final message = ChatMessage(
      id: _uuid.v4(),
      senderId: myId,
      senderName: myName,
      text: text.trim(),
      timestamp: DateTime.now(),
      isMe: true,
    );
    messages.add(message);
    notifyListeners();

    final bytes = Uint8List.fromList(utf8.encode(message.toWire()));
    for (final peer in peers.values.where((p) => p.isConnected)) {
      try {
        await _nearby.sendBytesPayload(peer.id, bytes);
      } catch (e) {
        debugPrint('sendBytesPayload to ${peer.id} failed: $e');
        message.status = MessageStatus.failed;
        notifyListeners();
      }
    }
  }

  void _onPayloadReceived(String endpointId, Payload payload) {
    if (payload.type != PayloadType.BYTES || payload.bytes == null) return;
    final raw = utf8.decode(payload.bytes!);
    final message = ChatMessage.fromWire(raw, isMe: false);
    if (message == null) return;
    messages.add(message);
    notifyListeners();
    onMessageReceived?.call(message);
  }

  // ---------------------------------------------------------------------
  // Cleanup
  // ---------------------------------------------------------------------

  Future<void> stopAll() async {
    await _nearby.stopAdvertising();
    await _nearby.stopDiscovery();
    await _nearby.stopAllEndpoints();
    isAdvertising = false;
    isDiscovering = false;
    for (final peer in peers.values) {
      peer.isConnected = false;
    }
    notifyListeners();
  }
}
