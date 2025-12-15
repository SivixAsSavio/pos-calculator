import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Sync message types
enum SyncMessageType {
  discovery,       // Find peers on the network
  discoveryReply,  // Reply to discovery
  syncRequest,     // Request full data sync
  syncData,        // Full data package
  userUpdate,      // User data changed
  branchUpdate,    // Branch cash changed
  cashCountUpdate, // Cash count added/changed
}

/// A sync message
class SyncMessage {
  final SyncMessageType type;
  final String senderId;
  final String senderName;
  final DateTime timestamp;
  final Map<String, dynamic>? data;

  SyncMessage({
    required this.type,
    required this.senderId,
    required this.senderName,
    DateTime? timestamp,
    this.data,
  }) : timestamp = timestamp ?? DateTime.now();

  Map<String, dynamic> toJson() => {
    'type': type.name,
    'senderId': senderId,
    'senderName': senderName,
    'timestamp': timestamp.toIso8601String(),
    'data': data,
  };

  factory SyncMessage.fromJson(Map<String, dynamic> json) => SyncMessage(
    type: SyncMessageType.values.firstWhere(
      (t) => t.name == json['type'],
      orElse: () => SyncMessageType.discovery,
    ),
    senderId: json['senderId'],
    senderName: json['senderName'],
    timestamp: DateTime.parse(json['timestamp']),
    data: json['data'],
  );
}

/// A discovered peer
class Peer {
  final String id;
  final String name;
  final InternetAddress address;
  final int port;
  final DateTime lastSeen;

  Peer({
    required this.id,
    required this.name,
    required this.address,
    required this.port,
    DateTime? lastSeen,
  }) : lastSeen = lastSeen ?? DateTime.now();

  String get endpoint => '${address.address}:$port';
}

/// Callback types for sync events
typedef OnDataReceived = void Function(SyncMessageType type, Map<String, dynamic> data);
typedef OnPeerDiscovered = void Function(Peer peer);

/// P2P Sync Service for local network synchronization
class SyncService extends ChangeNotifier {
  static const int _broadcastPort = 45678;
  static const int _tcpPort = 45679;
  static const String _deviceIdKey = 'sync_device_id';
  
  String? _deviceId;
  String _deviceName = 'Unknown';
  RawDatagramSocket? _udpSocket;
  ServerSocket? _tcpServer;
  final Map<String, Peer> _peers = {};
  bool _isRunning = false;
  Timer? _discoveryTimer;
  Timer? _cleanupTimer;
  SharedPreferences? _prefs;

  OnDataReceived? onDataReceived;
  OnPeerDiscovered? onPeerDiscovered;

  String? get deviceId => _deviceId;
  String get deviceName => _deviceName;
  bool get isRunning => _isRunning;
  List<Peer> get peers => _peers.values.toList();
  int get peerCount => _peers.length;

  /// Initialize the sync service
  Future<void> init(String deviceName) async {
    _prefs = await SharedPreferences.getInstance();
    _deviceName = deviceName;
    
    // Get or create device ID
    _deviceId = _prefs?.getString(_deviceIdKey);
    if (_deviceId == null) {
      _deviceId = 'device_${DateTime.now().millisecondsSinceEpoch}_${Platform.localHostname}';
      await _prefs?.setString(_deviceIdKey, _deviceId!);
    }
  }

  /// Start the sync service
  Future<bool> start() async {
    if (_isRunning) return true;
    if (_deviceId == null) {
      debugPrint('SyncService: Not initialized');
      return false;
    }

    try {
      // Start UDP broadcast listener
      _udpSocket = await RawDatagramSocket.bind(
        InternetAddress.anyIPv4,
        _broadcastPort,
        reuseAddress: true,
      );
      _udpSocket!.broadcastEnabled = true;
      _udpSocket!.listen(_handleUdpPacket);

      // Start TCP server for data transfer
      _tcpServer = await ServerSocket.bind(
        InternetAddress.anyIPv4,
        _tcpPort,
        shared: true,
      );
      _tcpServer!.listen(_handleTcpConnection);

      _isRunning = true;

      // Start discovery
      _discoveryTimer = Timer.periodic(
        const Duration(seconds: 10),
        (_) => broadcastDiscovery(),
      );

      // Cleanup old peers
      _cleanupTimer = Timer.periodic(
        const Duration(seconds: 30),
        (_) => _cleanupOldPeers(),
      );

      // Initial discovery
      broadcastDiscovery();

      notifyListeners();
      debugPrint('SyncService: Started on ports UDP:$_broadcastPort, TCP:$_tcpPort');
      return true;
    } catch (e) {
      debugPrint('SyncService: Failed to start - $e');
      await stop();
      return false;
    }
  }

  /// Stop the sync service
  Future<void> stop() async {
    _isRunning = false;
    _discoveryTimer?.cancel();
    _cleanupTimer?.cancel();
    _udpSocket?.close();
    await _tcpServer?.close();
    _peers.clear();
    notifyListeners();
    debugPrint('SyncService: Stopped');
  }

  /// Handle incoming UDP packet
  void _handleUdpPacket(RawSocketEvent event) {
    if (event != RawSocketEvent.read) return;
    
    final datagram = _udpSocket?.receive();
    if (datagram == null) return;

    try {
      final json = jsonDecode(utf8.decode(datagram.data));
      final message = SyncMessage.fromJson(json);
      
      // Ignore own messages
      if (message.senderId == _deviceId) return;

      switch (message.type) {
        case SyncMessageType.discovery:
          _handleDiscovery(message, datagram.address);
          break;
        case SyncMessageType.discoveryReply:
          _handleDiscoveryReply(message, datagram.address);
          break;
        default:
          break;
      }
    } catch (e) {
      debugPrint('SyncService: UDP parse error - $e');
    }
  }

  /// Handle discovery message
  void _handleDiscovery(SyncMessage message, InternetAddress address) {
    // Add/update peer
    final peer = Peer(
      id: message.senderId,
      name: message.senderName,
      address: address,
      port: _tcpPort,
    );
    _peers[peer.id] = peer;
    onPeerDiscovered?.call(peer);
    notifyListeners();

    // Send reply
    _sendDiscoveryReply(address);
  }

  /// Handle discovery reply
  void _handleDiscoveryReply(SyncMessage message, InternetAddress address) {
    final peer = Peer(
      id: message.senderId,
      name: message.senderName,
      address: address,
      port: _tcpPort,
    );
    _peers[peer.id] = peer;
    onPeerDiscovered?.call(peer);
    notifyListeners();
  }

  /// Send discovery reply
  void _sendDiscoveryReply(InternetAddress address) {
    final message = SyncMessage(
      type: SyncMessageType.discoveryReply,
      senderId: _deviceId!,
      senderName: _deviceName,
    );
    
    final data = utf8.encode(jsonEncode(message.toJson()));
    _udpSocket?.send(data, address, _broadcastPort);
  }

  /// Broadcast discovery message
  void broadcastDiscovery() {
    if (!_isRunning || _udpSocket == null) return;

    final message = SyncMessage(
      type: SyncMessageType.discovery,
      senderId: _deviceId!,
      senderName: _deviceName,
    );
    
    final data = utf8.encode(jsonEncode(message.toJson()));
    
    // Broadcast to common subnet ranges
    _getBroadcastAddresses().forEach((address) {
      try {
        _udpSocket?.send(data, address, _broadcastPort);
      } catch (e) {
        // Ignore broadcast errors
      }
    });
  }

  /// Get broadcast addresses for local network
  List<InternetAddress> _getBroadcastAddresses() {
    return [
      InternetAddress('255.255.255.255'),
      InternetAddress('192.168.1.255'),
      InternetAddress('192.168.0.255'),
      InternetAddress('10.0.0.255'),
      InternetAddress('172.16.0.255'),
    ];
  }

  /// Handle incoming TCP connection
  void _handleTcpConnection(Socket socket) {
    debugPrint('SyncService: TCP connection from ${socket.remoteAddress.address}');
    
    final buffer = StringBuffer();
    
    socket.listen(
      (data) {
        buffer.write(utf8.decode(data));
        
        // Check for complete message (ends with newline)
        final content = buffer.toString();
        if (content.endsWith('\n')) {
          try {
            final json = jsonDecode(content.trim());
            final message = SyncMessage.fromJson(json);
            _handleSyncMessage(message, socket);
          } catch (e) {
            debugPrint('SyncService: TCP parse error - $e');
          }
          buffer.clear();
        }
      },
      onError: (e) => debugPrint('SyncService: TCP error - $e'),
      onDone: () => socket.close(),
    );
  }

  /// Handle sync message
  void _handleSyncMessage(SyncMessage message, Socket socket) {
    if (message.senderId == _deviceId) return;

    switch (message.type) {
      case SyncMessageType.syncRequest:
        // Handled by caller
        break;
      case SyncMessageType.syncData:
      case SyncMessageType.userUpdate:
      case SyncMessageType.branchUpdate:
      case SyncMessageType.cashCountUpdate:
        if (message.data != null) {
          onDataReceived?.call(message.type, message.data!);
        }
        break;
      default:
        break;
    }
  }

  /// Send data to all peers
  Future<void> broadcastData(SyncMessageType type, Map<String, dynamic> data) async {
    if (!_isRunning) return;

    final message = SyncMessage(
      type: type,
      senderId: _deviceId!,
      senderName: _deviceName,
      data: data,
    );

    final jsonData = '${jsonEncode(message.toJson())}\n';
    
    for (final peer in _peers.values) {
      try {
        final socket = await Socket.connect(
          peer.address,
          peer.port,
          timeout: const Duration(seconds: 5),
        );
        socket.write(jsonData);
        await socket.flush();
        await socket.close();
      } catch (e) {
        debugPrint('SyncService: Failed to send to ${peer.name} - $e');
      }
    }
  }

  /// Send data to specific peer
  Future<bool> sendToPeer(Peer peer, SyncMessageType type, Map<String, dynamic> data) async {
    if (!_isRunning) return false;

    final message = SyncMessage(
      type: type,
      senderId: _deviceId!,
      senderName: _deviceName,
      data: data,
    );

    try {
      final socket = await Socket.connect(
        peer.address,
        peer.port,
        timeout: const Duration(seconds: 5),
      );
      socket.write('${jsonEncode(message.toJson())}\n');
      await socket.flush();
      await socket.close();
      return true;
    } catch (e) {
      debugPrint('SyncService: Failed to send to ${peer.name} - $e');
      return false;
    }
  }

  /// Request full sync from a peer
  Future<void> requestSync(Peer peer) async {
    await sendToPeer(peer, SyncMessageType.syncRequest, {});
  }

  /// Clean up old peers
  void _cleanupOldPeers() {
    final cutoff = DateTime.now().subtract(const Duration(minutes: 2));
    _peers.removeWhere((id, peer) => peer.lastSeen.isBefore(cutoff));
    notifyListeners();
  }

  /// Get local IP address
  Future<String?> getLocalIpAddress() async {
    try {
      final interfaces = await NetworkInterface.list(
        type: InternetAddressType.IPv4,
        includeLoopback: false,
      );
      
      for (final interface in interfaces) {
        for (final address in interface.addresses) {
          if (!address.isLoopback) {
            return address.address;
          }
        }
      }
    } catch (e) {
      debugPrint('SyncService: Failed to get local IP - $e');
    }
    return null;
  }
}

/// Sync service for web (stub - P2P not available on web)
class SyncServiceWeb extends ChangeNotifier {
  bool get isRunning => false;
  List<Peer> get peers => [];
  int get peerCount => 0;
  String? get deviceId => null;
  String get deviceName => 'Web Client';

  Future<void> init(String deviceName) async {}
  Future<bool> start() async => false;
  Future<void> stop() async {}
  void broadcastDiscovery() {}
  Future<void> broadcastData(SyncMessageType type, Map<String, dynamic> data) async {}
  Future<String?> getLocalIpAddress() async => null;
}
