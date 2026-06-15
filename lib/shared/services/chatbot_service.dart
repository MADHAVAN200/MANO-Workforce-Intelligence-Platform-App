import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:flutter_application/shared/models/chatbot_message.dart';
import 'package:flutter_application/shared/services/auth_service.dart';
import 'package:flutter_application/shared/constants/api_constants.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ChatbotService extends ChangeNotifier {
  final AuthService _authService;
  final List<ChatbotMessage> _messages = [];
  bool _isLoading = false;
  bool _isChatbotEnabled = true;

  ChatbotService(this._authService) {
    _loadChatbotPreference();
  }

  bool get isChatbotEnabled => _isChatbotEnabled;

  Future<void> _loadChatbotPreference() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _isChatbotEnabled = prefs.getBool('chatbot_enabled') ?? true;
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading chatbot preference: $e');
    }
  }

  Future<void> setChatbotEnabled(bool enabled) async {
    if (_isChatbotEnabled == enabled) return;
    _isChatbotEnabled = enabled;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('chatbot_enabled', enabled);
    } catch (e) {
      debugPrint('Error saving chatbot preference: $e');
    }
  }

  Offset? _chatPosition;
  Offset? get chatPosition => _chatPosition;
  set chatPosition(Offset? newPos) {
    _chatPosition = newPos;
    notifyListeners();
  }

  Offset? _fabPosition;
  Offset? get fabPosition => _fabPosition;
  set fabPosition(Offset? newPos) {
    _fabPosition = newPos;
    notifyListeners();
  }

  List<ChatbotMessage> get messages => List.unmodifiable(_messages);
  bool get isLoading => _isLoading;

  /// Clear the chat session history.
  void clearChat(String pageName) {
    _messages.clear();
    _messages.add(ChatbotMessage.greeting(pageName));
    _isLoading = false;
    notifyListeners();
  }

  /// Initialize the chat with a greeting if empty.
  void initChatIfNeeded(String pageName) {
    if (_messages.isEmpty) {
      _messages.add(ChatbotMessage.greeting(pageName));
    }
  }

  /// Sends a message to the backend chatbot RAG service.
  Future<void> sendMessage(String text, String currentPath) async {
    if (text.trim().isEmpty || _isLoading) return;

    // 1. Add user message
    final userMessage = ChatbotMessage(
      role: 'user',
      text: text,
      timestamp: DateTime.now(),
    );
    _messages.add(userMessage);
    
    // 2. Set loading state and add loading placeholder
    _isLoading = true;
    final loadingPlaceholder = ChatbotMessage.loading();
    _messages.add(loadingPlaceholder);
    notifyListeners();

    try {
      final dio = _authService.dio;

      final response = await dio.post(
        ApiConstants.chatbotAskInternal,
        data: {
          'question': text,
          'path': currentPath,
        },
      );

      // Remove loading placeholder
      _messages.removeLast();

      if (response.statusCode == 200 && response.data['ok'] == true) {
        final answer = response.data['data']?['answer'] ?? 'Sorry, I couldn\'t process that request.';
        
        _messages.add(ChatbotMessage(
          role: 'assistant',
          text: answer,
          timestamp: DateTime.now(),
        ));
      } else {
        _messages.add(ChatbotMessage(
          role: 'assistant',
          text: 'Error: Failed to fetch response from Mano Copilot backend.',
          timestamp: DateTime.now(),
        ));
      }
    } catch (e) {
      // Remove loading placeholder
      if (_messages.isNotEmpty && _messages.last.isLoading) {
        _messages.removeLast();
      }
      
      String errorMessage = 'Failed to connect to Mano Copilot. Please check your connection.';
      if (e is DioException) {
        if (e.response?.data != null && e.response!.data is Map) {
          errorMessage = e.response!.data['message'] ?? errorMessage;
        }
      }

      _messages.add(ChatbotMessage(
        role: 'assistant',
        text: errorMessage,
        timestamp: DateTime.now(),
      ));
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
