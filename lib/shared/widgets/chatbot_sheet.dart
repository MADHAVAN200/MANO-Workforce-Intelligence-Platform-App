import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_application/shared/models/chatbot_message.dart';
import 'package:flutter_application/shared/services/chatbot_service.dart';
import 'package:flutter_application/shared/services/auth_service.dart';
import 'package:flutter_application/shared/navigation/navigation_controller.dart';
import 'package:flutter_application/shared/utils/page_path_helper.dart';
import 'package:flutter_application/shared/widgets/chatbot_fab.dart'; // Import ChatbotOverlayManager

class ChatbotSheet extends StatefulWidget {
  final PageType currentPageType;

  const ChatbotSheet({super.key, required this.currentPageType});

  @override
  State<ChatbotSheet> createState() => _ChatbotSheetState();
}

class _ChatbotSheetState extends State<ChatbotSheet> {
  final TextEditingController _inputController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  late ChatbotService _chatbotService;
  late PageType _currentPageType;

  double _right = 0;
  double _bottom = 0;
  bool _isPositionInitialized = false;

  final double _width = 360;
  final double _height = 500;

  @override
  void initState() {
    super.initState();
    _currentPageType = widget.currentPageType;
    _chatbotService = context.read<ChatbotService>();
    _chatbotService.addListener(_onChatbotServiceChanged);
    navigationNotifier.addListener(_onPageChanged);
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _chatbotService.initChatIfNeeded(_currentPageType.title);
      _scrollToBottom();
      _initializePosition();
    });
  }

  void _initializePosition() {
    if (!mounted) return;
    final screenSize = MediaQuery.of(context).size;
    final cachedPos = _chatbotService.chatPosition;
    
    final actualWidth = _getActualWidth();
    final actualHeight = _getActualHeight();

    setState(() {
      if (cachedPos != null) {
        _right = cachedPos.dx.clamp(8.0, screenSize.width - actualWidth - 8.0);
        _bottom = cachedPos.dy.clamp(8.0, screenSize.height - actualHeight - 8.0);
      } else {
        _right = 20.0;
        _bottom = 170.0;
        _chatbotService.chatPosition = Offset(_right, _bottom);
      }
      _isPositionInitialized = true;
    });
  }

  double _getActualWidth() {
    final screenWidth = MediaQuery.of(context).size.width;
    return screenWidth < _width + 32 ? screenWidth - 32 : _width;
  }

  double _getActualHeight() {
    final screenHeight = MediaQuery.of(context).size.height;
    return screenHeight * 0.7 < _height ? screenHeight * 0.7 : _height;
  }

  @override
  void dispose() {
    _chatbotService.removeListener(_onChatbotServiceChanged);
    navigationNotifier.removeListener(_onPageChanged);
    _inputController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onChatbotServiceChanged() {
    if (mounted) {
      _scrollToBottom();
    }
  }

  void _onPageChanged() {
    if (mounted) {
      setState(() {
        _currentPageType = navigationNotifier.value;
      });
      _chatbotService.initChatIfNeeded(_currentPageType.title);
      _scrollToBottom();
    }
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      Future.delayed(const Duration(milliseconds: 100), () {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      });
    }
  }

  void _handleSubmitted() async {
    final text = _inputController.text.trim();
    if (text.isEmpty) return;

    _inputController.clear();
    final chatbotService = context.read<ChatbotService>();
    final backendPath = PagePathHelper.getBackendPath(_currentPageType);

    await chatbotService.sendMessage(text, backendPath);
    _scrollToBottom();
  }

  void _handleSuggestionTap(String question) async {
    final chatbotService = context.read<ChatbotService>();
    final backendPath = PagePathHelper.getBackendPath(_currentPageType);

    await chatbotService.sendMessage(question, backendPath);
    _scrollToBottom();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final chatbotService = context.watch<ChatbotService>();
    final suggestions = PagePathHelper.getSuggestedQuestions(_currentPageType);

    // Auto-dismiss on logout
    final authService = context.watch<AuthService>();
    if (authService.user == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ChatbotOverlayManager.destroyAll();
      });
      return const SizedBox.shrink();
    }

    if (!_isPositionInitialized) {
      return const SizedBox.shrink();
    }

    final actualWidth = _getActualWidth();
    final actualHeight = _getActualHeight();
    final viewInsetsBottom = MediaQuery.of(context).viewInsets.bottom;
    final screenSize = MediaQuery.of(context).size;

    // Shift window up if keyboard would cover it
    double renderBottom = _bottom;
    if (viewInsetsBottom > 0) {
      renderBottom = _bottom + viewInsetsBottom;
      if (renderBottom + actualHeight > screenSize.height - 40) {
        renderBottom = screenSize.height - actualHeight - 40;
      }
    }

    return Positioned(
      right: _right,
      bottom: renderBottom,
      width: actualWidth,
      height: actualHeight,
      child: Material(
        color: Colors.transparent,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
            child: Container(
              decoration: BoxDecoration(
                color: isDark
                    ? const Color(0xFF161B22).withValues(alpha: 0.85)
                    : const Color(0xFFFFFFFF).withValues(alpha: 0.9),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.12)
                      : Colors.black.withValues(alpha: 0.08),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.15),
                    blurRadius: 16,
                    spreadRadius: 4,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                children: [
                  // Draggable Header
                  GestureDetector(
                    onPanUpdate: (details) {
                      setState(() {
                        _right -= details.delta.dx;
                        _bottom -= details.delta.dy;
                        _right = _right.clamp(8.0, screenSize.width - actualWidth - 8.0);
                        _bottom = _bottom.clamp(8.0, screenSize.height - actualHeight - 8.0);
                      });
                    },
                    onPanEnd: (_) {
                      _chatbotService.chatPosition = Offset(_right, _bottom);
                    },
                    child: _buildHeader(context, isDark, chatbotService),
                  ),
                  
                  // Chat Messages Area
                  Expanded(
                    child: chatbotService.messages.isEmpty
                        ? const Center(child: CircularProgressIndicator())
                        : ListView.builder(
                            controller: _scrollController,
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            itemCount: chatbotService.messages.length,
                            itemBuilder: (context, index) {
                              final message = chatbotService.messages[index];
                              return _buildChatBubble(message, isDark, actualWidth);
                            },
                          ),
                  ),

                  // Suggestions Chips (Only show if not currently loading)
                  if (!chatbotService.isLoading && suggestions.isNotEmpty)
                    _buildSuggestions(suggestions, isDark),

                  // Message Input
                  _buildInputArea(isDark, chatbotService.isLoading),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, bool isDark, ChatbotService service) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.02)
            : Colors.black.withValues(alpha: 0.02),
        border: Border(
          bottom: BorderSide(
            color: isDark
                ? Colors.white.withValues(alpha: 0.08)
                : Colors.black.withValues(alpha: 0.05),
          ),
        ),
      ),
      child: Column(
        children: [
          Container(
            width: 36,
            height: 4,
            margin: const EdgeInsets.only(bottom: 8),
            decoration: BoxDecoration(
              color: isDark ? Colors.white30 : Colors.black26,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF6366F1), Color(0xFF4F46E5)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF6366F1).withValues(alpha: 0.4),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.smart_toy_outlined,
                  color: Colors.white,
                  size: 16,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Mano Copilot',
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    Row(
                      children: [
                        Container(
                          width: 5,
                          height: 5,
                          decoration: const BoxDecoration(
                            color: Color(0xFF10B981),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            'AI Guide • ${_currentPageType.title}',
                            style: GoogleFonts.poppins(
                              fontSize: 10,
                              fontWeight: FontWeight.w500,
                              color: isDark ? Colors.white54 : Colors.black54,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.refresh, size: 18),
                tooltip: 'Reset Chat',
                constraints: const BoxConstraints(),
                padding: const EdgeInsets.all(4),
                color: isDark ? Colors.white60 : Colors.black54,
                onPressed: () {
                  service.clearChat(_currentPageType.title);
                  _scrollToBottom();
                },
              ),
              const SizedBox(width: 4),
              IconButton(
                icon: const Icon(Icons.close, size: 18),
                tooltip: 'Hide Chat',
                constraints: const BoxConstraints(),
                padding: const EdgeInsets.all(4),
                color: isDark ? Colors.white60 : Colors.black54,
                onPressed: () {
                  ChatbotOverlayManager.hideWindow(context, _currentPageType);
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildChatBubble(ChatbotMessage message, bool isDark, double actualWidth) {
    if (message.isLoading) {
      return Align(
        alignment: Alignment.centerLeft,
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 6),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: isDark ? Colors.white.withValues(alpha: 0.06) : Colors.black.withValues(alpha: 0.04),
            borderRadius: const BorderRadius.only(
              topRight: Radius.circular(16),
              bottomRight: Radius.circular(16),
              topLeft: Radius.circular(16),
            ),
            border: Border.all(
              color: isDark ? Colors.white.withValues(alpha: 0.06) : Colors.black.withValues(alpha: 0.04),
            ),
          ),
          child: const SizedBox(
            width: 40,
            height: 20,
            child: _TypingIndicator(),
          ),
        ),
      );
    }

    final isUser = message.isUser;
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 6),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        constraints: BoxConstraints(
          maxWidth: actualWidth * 0.78,
        ),
        decoration: BoxDecoration(
          gradient: isUser
              ? const LinearGradient(
                  colors: [Color(0xFF6366F1), Color(0xFF4F46E5)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : null,
          color: isUser
              ? null
              : (isDark
                  ? Colors.white.withValues(alpha: 0.07)
                  : Colors.black.withValues(alpha: 0.04)),
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(isUser ? 16 : 0),
            bottomRight: Radius.circular(isUser ? 0 : 16),
          ),
          border: isUser
              ? null
              : Border.all(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.08)
                      : Colors.black.withValues(alpha: 0.04),
                ),
          boxShadow: isUser
              ? [
                  BoxShadow(
                    color: const Color(0xFF6366F1).withValues(alpha: 0.25),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Text(
          message.text,
          style: GoogleFonts.poppins(
            color: isUser
                ? Colors.white
                : (isDark ? Colors.white.withValues(alpha: 0.95) : Colors.black87),
            fontSize: 13,
            height: 1.4,
          ),
        ),
      ),
    );
  }

  Widget _buildSuggestions(List<String> suggestions, bool isDark) {
    return Container(
      height: 38,
      margin: const EdgeInsets.only(bottom: 8),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: suggestions.length,
        itemBuilder: (context, index) {
          final question = suggestions[index];
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => _handleSuggestionTap(question),
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: isDark
                        ? const Color(0xFF6366F1).withValues(alpha: 0.1)
                        : const Color(0xFF6366F1).withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: const Color(0xFF6366F1).withValues(alpha: 0.25),
                      width: 1,
                    ),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    question,
                    style: GoogleFonts.poppins(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: const Color(0xFF6366F1),
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildInputArea(bool isDark, bool isLoading) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF161B22).withValues(alpha: 0.5) : Colors.grey[50]!.withValues(alpha: 0.5),
        border: Border(
          top: BorderSide(
            color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.05),
          ),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF0D1117) : Colors.white,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: isDark ? Colors.white.withValues(alpha: 0.12) : Colors.grey[300]!,
                ),
              ),
              child: TextField(
                controller: _inputController,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _handleSubmitted(),
                enabled: !isLoading,
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  color: isDark ? Colors.white : Colors.black87,
                ),
                decoration: InputDecoration(
                  hintText: 'Ask Mano Copilot anything...',
                  hintStyle: GoogleFonts.poppins(
                    fontSize: 12.5,
                    color: isDark ? Colors.white38 : Colors.black38,
                  ),
                  border: InputBorder.none,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: isLoading ? null : _handleSubmitted,
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF6366F1), Color(0xFF4F46E5)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF6366F1).withValues(alpha: 0.35),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Icon(
                isLoading ? Icons.hourglass_empty : Icons.send_rounded,
                color: Colors.white,
                size: 16,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TypingIndicator extends StatefulWidget {
  const _TypingIndicator();

  @override
  State<_TypingIndicator> createState() => _TypingIndicatorState();
}

class _TypingIndicatorState extends State<_TypingIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final dotColor = isDark ? Colors.white60 : Colors.black45;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: List.generate(3, (index) {
        return AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            final delay = index * 0.2;
            final dynamicValue = (_controller.value - delay).clamp(0.0, 1.0);
            double scale = 1.0;
            double opacity = 0.4;
            
            if (dynamicValue > 0.0 && dynamicValue < 0.4) {
              final progress = dynamicValue / 0.4;
              scale = 1.0 + (0.4 * progress);
              opacity = 0.4 + (0.6 * progress);
            } else if (dynamicValue >= 0.4 && dynamicValue < 0.8) {
              final progress = (dynamicValue - 0.4) / 0.4;
              scale = 1.4 - (0.4 * progress);
              opacity = 1.0 - (0.6 * progress);
            }

            return Opacity(
              opacity: opacity.clamp(0.2, 1.0),
              child: Transform.scale(
                scale: scale,
                child: Container(
                  width: 5,
                  height: 5,
                  decoration: BoxDecoration(
                    color: dotColor,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            );
          },
        );
      }),
    );
  }
}
