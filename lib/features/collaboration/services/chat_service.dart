import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../models/chat_models.dart';
import '../../../shared/services/socket_service.dart';

class ChatService extends ChangeNotifier {
  final Dio _dio;
  int _totalUnreadCount = 0;
  
  dynamic _lastSocket;
  SocketService? _socketService;

  ChatService(this._dio);

  int get totalUnreadCount => _totalUnreadCount;

  void initializeSocketListening(SocketService socketService) {
    _socketService = socketService;
    _socketService!.addListener(_onSocketServiceChanged);
    _onSocketServiceChanged();
  }

  void _onSocketServiceChanged() {
    if (_socketService == null) return;
    final s = _socketService!.socket;
    if (_lastSocket != s) {
      if (_lastSocket != null) {
        try {
          _lastSocket.off('room_created', _onSocketRoomEvent);
          _lastSocket.off('room_deleted', _onSocketRoomEvent);
          _lastSocket.off('message_received', _onSocketRoomEvent);
        } catch (_) {}
      }
      _lastSocket = s;
      if (s != null) {
        s.on('room_created', _onSocketRoomEvent);
        s.on('room_deleted', _onSocketRoomEvent);
        s.on('message_received', _onSocketRoomEvent);
      }
      // Since socket changed, fetch rooms list to update count
      getRooms();
    }
  }

  void _onSocketRoomEvent(dynamic data) {
    getRooms();
  }

  @override
  void dispose() {
    if (_socketService != null) {
      _socketService!.removeListener(_onSocketServiceChanged);
    }
    if (_lastSocket != null) {
      try {
        _lastSocket.off('room_created', _onSocketRoomEvent);
        _lastSocket.off('room_deleted', _onSocketRoomEvent);
        _lastSocket.off('message_received', _onSocketRoomEvent);
      } catch (_) {}
    }
    super.dispose();
  }

  // 1. Fetch Rooms list
  Future<List<ChatRoom>> getRooms() async {
    try {
      final response = await _dio.get('/collaboration/rooms');
      if (response.statusCode == 200 && response.data['success'] == true) {
        final List<dynamic> data = response.data['data'] ?? [];
        final rooms = data.map((json) => ChatRoom.fromJson(json)).toList();
        
        final count = rooms.fold<int>(0, (sum, room) => sum + room.unreadCount);
        if (_totalUnreadCount != count) {
          _totalUnreadCount = count;
          Future.microtask(() => notifyListeners());
        }
        
        return rooms;
      }
      return [];
    } catch (e) {
      debugPrint("ChatService getRooms error: $e");
      return [];
    }
  }

  // 2. Fetch Directory / Coworkers list (excluding bots/AI accounts)
  Future<List<ChatMember>> getCoworkers() async {
    try {
      final response = await _dio.get('/collaboration/users');
      if (response.statusCode == 200 && response.data['success'] == true) {
        final List<dynamic> data = response.data['data'] ?? [];
        final list = data.map((json) => ChatMember.fromJson(json)).toList();
        
        // Filter out AI accounts
        return list.where((u) {
          final name = u.userName.toLowerCase();
          final type = u.userType?.toLowerCase() ?? '';
          return !(name.contains('bot') ||
              name.contains('assistant') ||
              name.contains('ai') ||
              type.contains('bot') ||
              type.contains('ai'));
        }).toList();
      }
      return [];
    } catch (e) {
      debugPrint("ChatService getCoworkers error: $e");
      return [];
    }
  }

  // 3. Fetch Message History
  Future<List<ChatMessage>> getMessages(int roomId) async {
    try {
      final response = await _dio.get('/collaboration/rooms/$roomId/messages');
      if (response.statusCode == 200 && response.data['success'] == true) {
        final List<dynamic> data = response.data['data'] ?? [];
        return data.map((json) => ChatMessage.fromJson(json)).toList();
      }
      return [];
    } catch (e) {
      debugPrint("ChatService getMessages error: $e");
      return [];
    }
  }

  // 4. Send Chat Message
  Future<ChatMessage?> sendMessage(int roomId, String messageText, Map<String, dynamic>? attachment) async {
    try {
      final response = await _dio.post(
        '/collaboration/rooms/$roomId/messages',
        data: {
          'message_text': messageText,
          'attachment': attachment,
        },
      );
      if ((response.statusCode == 200 || response.statusCode == 201) && response.data['success'] == true) {
        return ChatMessage.fromJson(response.data['data']);
      }
      return null;
    } catch (e) {
      debugPrint("ChatService sendMessage error: $e");
      return null;
    }
  }

  // 5. Upload Attachment
  Future<Map<String, dynamic>?> uploadAttachment(int roomId, String filePath, String fileName) async {
    try {
      final formData = FormData.fromMap({
        'file': await MultipartFile.fromFile(filePath, filename: fileName),
      });
      final response = await _dio.post(
        '/collaboration/rooms/$roomId/upload',
        data: formData,
      );
      if (response.statusCode == 200 && response.data['success'] == true) {
        return Map<String, dynamic>.from(response.data['file']);
      }
      return null;
    } catch (e) {
      debugPrint("ChatService uploadAttachment error: $e");
      return null;
    }
  }

  // 6. Create Chat Room (Group or DM)
  Future<ChatRoom?> createRoom({
    required String type, // 'direct' | 'group'
    required List<int> memberIds,
    String? roomName,
  }) async {
    try {
      final payload = {
        'room_type': type,
        'member_ids': memberIds,
      };
      if (roomName != null && roomName.trim().isNotEmpty) {
        payload['room_name'] = roomName;
      }
      final response = await _dio.post('/collaboration/rooms', data: payload);
      if ((response.statusCode == 200 || response.statusCode == 201) && (response.data['success'] == true || response.data['ok'] == true)) {
        final roomData = response.data['data'] ?? response.data['room'] ?? response.data;
        final room = ChatRoom.fromJson(roomData);
        getRooms();
        return room;
      }
      return null;
    } catch (e) {
      debugPrint("ChatService createRoom error: $e");
      return null;
    }
  }

  // 7. Update Group Members
  Future<ChatRoom?> updateMembers(int roomId, List<int> memberIds) async {
    try {
      final response = await _dio.put(
        '/collaboration/rooms/$roomId/members',
        data: {
          'member_ids': memberIds,
        },
      );
      if (response.statusCode == 200 && response.data['success'] == true) {
        return ChatRoom.fromJson(response.data['data']);
      }
      return null;
    } catch (e) {
      debugPrint("ChatService updateMembers error: $e");
      return null;
    }
  }

  // 8. Mark Room as Read
  Future<bool> markAsRead(int roomId) async {
    try {
      final response = await _dio.put('/collaboration/rooms/$roomId/read');
      final success = response.statusCode == 200 && response.data['success'] == true;
      if (success) {
        getRooms();
      }
      return success;
    } catch (e) {
      debugPrint("ChatService markAsRead error: $e");
      return false;
    }
  }
}
