import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import '../services/ai_service.dart';
import '../utils/date_formatter.dart';

class AIChatScreen extends ConsumerStatefulWidget {
  const AIChatScreen({super.key});

  @override
  ConsumerState<AIChatScreen> createState() => _AiChatPageState();
}

class _AiChatPageState extends ConsumerState<AIChatScreen> with SingleTickerProviderStateMixin {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _chatSearchController = TextEditingController();
  String _drawerSearchTerm = '';

  bool _isSending = false;
  bool _isSearching = false;

  late AnimationController _typingAnimationController;
  late Animation<double> _dotOneAnimation;
  late Animation<double> _dotTwoAnimation;
  late Animation<double> _dotThreeAnimation;

  @override
  void initState() {
    super.initState();
    _typingAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();

    _dotOneAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _typingAnimationController,
        curve: const Interval(0.0, 0.33, curve: Curves.easeOut),
      ),
    );
    _dotTwoAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _typingAnimationController,
        curve: const Interval(0.33, 0.66, curve: Curves.easeOut),
      ),
    );
    _dotThreeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _typingAnimationController,
        curve: const Interval(0.66, 1.0, curve: Curves.easeOut),
      ),
    );

    _searchController.addListener(() {
      setState(() {
        _drawerSearchTerm = _searchController.text;
      });
    });

    _chatSearchController.addListener(() {
      ref.read(chatSearchQueryProvider.notifier).state = _chatSearchController.text;
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    _typingAnimationController.dispose();
    _searchController.dispose();
    _chatSearchController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    _controller.clear();
    setState(() => _isSending = true);

    final chatService = ref.read(geminiChatServiceProvider);
    await chatService.sendMessage(text);

    setState(() => _isSending = false);
    _scrollToBottom();
  }

  void _startNewChat() {
    ref.read(geminiChatServiceProvider).startNewChatSession();
    ref.read(chatSearchQueryProvider.notifier).state = '';
    _chatSearchController.clear();
    setState(() => _isSearching = false);
    Navigator.of(context).pop();
  }

  void _toggleSearch() {
    setState(() {
      _isSearching = !_isSearching;
      if (!_isSearching) {
        _chatSearchController.clear();
        ref.read(chatSearchQueryProvider.notifier).state = '';
      }
    });
  }

  void _clearSearch() {
    _chatSearchController.clear();
    ref.read(chatSearchQueryProvider.notifier).state = '';
  }

  Future<void> _confirmDeleteCurrentChat(BuildContext context) async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text("chat.delete_title".tr()),
        content: Text("chat.delete_confirmation".tr()),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text("common.cancel".tr(), style: const TextStyle(color: Colors.grey)),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: Text("common.delete".tr(), style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await ref.read(geminiChatServiceProvider).deleteCurrentChatSession();
      ref.read(chatSearchQueryProvider.notifier).state = '';
      _chatSearchController.clear();
      setState(() => _isSearching = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final allMessages = ref.watch(chatStateProvider);
    final filteredMessages = ref.watch(filteredChatMessagesProvider);
    final currentSessionId = ref.watch(currentChatSessionIdProvider);
    final searchQuery = ref.watch(chatSearchQueryProvider);

    final displayMessages = searchQuery.isEmpty
        ? allMessages
        : filteredMessages;

    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());

    return Scaffold(
      appBar: _isSearching
          ? _buildSearchAppBar(context)
          : _buildNormalAppBar(context),
      drawer: Drawer(
        child: Column(
          children: [
            DrawerHeader(
              child: SizedBox(
                width: double.infinity,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.end,
                  spacing: 10,
                  children: [
                    Text("chat.sessions_title".tr(), style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    )),
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: ElevatedButton.icon(
                        onPressed: _startNewChat,
                        icon: const Icon(Icons.add_comment),
                        label: Text("chat.new_chat".tr()),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: "chat.search_chats_hint".tr(),
                  prefixIcon: const Icon(Icons.search),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide.none,
                  ),
                  filled: true,
                  fillColor:
                      Theme.of(context).inputDecorationTheme.fillColor ??
                      Colors.grey.shade200,
                  contentPadding: const EdgeInsets.symmetric(vertical: 0),
                ),
              ),
            ),
            Expanded(
              child: ref.watch(filteredChatSessionsProvider(_drawerSearchTerm)).when(
                data: (sessions) {
                  if (sessions.isEmpty && _drawerSearchTerm.isNotEmpty) {
                    return Center(
                      child: Text("chat.no_matching_chats".tr()),
                    );
                  } else if (sessions.isEmpty) {
                    return Center(
                      child: Text("chat.no_sessions".tr()),
                    );
                  }
                  return ListView.builder(
                    itemCount: sessions.length,
                    itemBuilder: (context, index) {
                      final session = sessions[index];
                      final isSelected = session.id == currentSessionId;
                      return ListTile(
                        leading: const Icon(Icons.chat_bubble_outline),
                        title: Text(session.title),
                        subtitle: Text(DateFormatter.shortDateTime(session.createdAt)),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete_forever, color: Colors.red),
                          onPressed: () => _confirmDeleteCurrentChat(context),
                          tooltip: 'chat.delete_tooltip'.tr(),
                        ),
                        selected: isSelected,
                        onTap: () {
                          ref.read(currentChatSessionIdProvider.notifier).state = session.id;
                          ref.invalidate(geminiChatSessionProvider);
                          ref.read(chatSearchQueryProvider.notifier).state = '';
                          _chatSearchController.clear();
                          setState(() => _isSearching = false);
                          Navigator.of(context).pop();
                        },
                      );
                    },
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (err, stack) => Center(child: Text('chat.sessions_error'.tr(args: [err.toString()]))),
              ),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          if (searchQuery.isNotEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: Theme.of(
                context,
              ).colorScheme.surfaceVariant.withOpacity(0.5),
              child: Row(
                children: [
                  Icon(Icons.search, size: 16, color: Colors.grey.shade600),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'chat.search_results'.tr(
                        args: [
                          filteredMessages.length.toString(),
                          filteredMessages.length == 1 ? 
                            'chat.message_singular'.tr() : 
                            'chat.message_plural'.tr(),
                          searchQuery
                        ]
                      ),
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 16),
                    onPressed: _clearSearch,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 36),
                  ),
                ],
              ),
            ),
          Expanded(
            child: displayMessages.isEmpty && !_isSending
                ? _buildEmptyChatPrompt(context)
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(16),
                    itemCount: displayMessages.length + (_isSending ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (_isSending && index == displayMessages.length) {
                        return _buildTypingBubble();
                      }
                      final msg = displayMessages[index];
                      return _buildMessageBubble(msg, searchQuery);
                    },
                  ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      decoration: InputDecoration(
                        hintText: "chat.input_hint".tr(),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                      ),
                      onSubmitted: (_) => _send(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.send),
                    iconSize: 28,
                    color: Theme.of(context).colorScheme.primary,
                    onPressed: _isSending ? null : _send,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  AppBar _buildNormalAppBar(BuildContext context) {
    return AppBar(
      title: Text("chat.title".tr()),
      leading: Builder(
        builder: (context) => IconButton(
          icon: const Icon(Icons.menu),
          onPressed: () => Scaffold.of(context).openDrawer(),
          tooltip: 'common.menu_tooltip'.tr(),
        ),
      ),
      actions: [
        if (ref.read(chatStateProvider).isNotEmpty)
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: _toggleSearch,
            tooltip: 'chat.search_tooltip'.tr(),
          ),
        IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => _exitChat(context),
          tooltip: 'common.exit_tooltip'.tr(),
        ),
      ],
    );
  }

  AppBar _buildSearchAppBar(BuildContext context) {
    return AppBar(
      leading: IconButton(
        icon: const Icon(Icons.arrow_back),
        onPressed: _toggleSearch,
      ),
      title: TextField(
        controller: _chatSearchController,
        autofocus: true,
        decoration: InputDecoration(
          hintText: "chat.search_in_chat_hint".tr(),
          border: InputBorder.none,
          hintStyle: TextStyle(color: Theme.of(context).hintColor),
        ),
        style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color),
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => _exitChat(context),
          tooltip: 'common.exit_tooltip'.tr(),
        ),
        if (_chatSearchController.text.isNotEmpty)
          IconButton(
            icon: const Icon(Icons.clear), 
            onPressed: _clearSearch
          ),
      ],
    );
  }

  void _exitChat(BuildContext context) {
    Navigator.of(context).pop();
  }

  Widget _buildMessageBubble(ChatMessage msg, String searchQuery) {
    final bool isUser = msg.isUser;
    final String formattedTime = DateFormat.jm().format(msg.timestamp);
    final Color textColor = isUser ? Colors.white : Colors.black;
    final Color bubbleColor = isUser
        ? Colors.blue.shade600
        : Colors.grey.shade200;

    if (!isUser && msg.text.isEmpty && _isSending) {
      return const SizedBox.shrink();
    }

    final String displayText = msg.text;
    final bool hasSearchMatch = searchQuery.isNotEmpty && displayText.toLowerCase().contains(searchQuery.toLowerCase());

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Column(
        crossAxisAlignment: isUser
            ? CrossAxisAlignment.end
            : CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!isUser) ...[
                const CircleAvatar(
                  backgroundColor: Colors.blueGrey,
                  child: Icon(Icons.face_2, color: Colors.white, size: 20),
                ),
                const SizedBox(width: 8),
              ],
              Container(
                margin: const EdgeInsets.symmetric(vertical: 6),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                constraints: const BoxConstraints(maxWidth: 300),
                decoration: BoxDecoration(
                  color: bubbleColor,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: !isUser
                    ? _buildMarkdownWithHighlight(
                        displayText,
                        textColor,
                        isUser,
                        searchQuery,
                      )
                    : _buildTextWithHighlight(
                        displayText,
                        textColor,
                        searchQuery,
                      ),
              ),
              if (isUser) ...[
                const SizedBox(width: 8),
                const CircleAvatar(
                  backgroundColor: Colors.deepPurple,
                  child: Icon(Icons.person, color: Colors.white, size: 20),
                ),
              ],
            ],
          ),
          Padding(
            padding: EdgeInsets.only(
              left: isUser ? 0 : 50,
              right: isUser ? 50 : 0,
              bottom: 10,
            ),
            child: Text(
              formattedTime,
              style: TextStyle(color: Colors.grey.shade600, fontSize: 10),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMarkdownWithHighlight(
    String text,
    Color textColor,
    bool isUser,
    String searchQuery,
  ) {
    if (searchQuery.isEmpty) {
      return MarkdownBody(
        data: text,
        selectable: true,
        styleSheet: MarkdownStyleSheet(
          p: TextStyle(color: textColor, fontSize: 15),
          strong: TextStyle(color: textColor, fontWeight: FontWeight.bold),
          em: TextStyle(color: textColor, fontStyle: FontStyle.italic),
          listBullet: TextStyle(color: textColor, fontSize: 15),
          tableHead: TextStyle(color: textColor, fontWeight: FontWeight.bold),
          tableBody: TextStyle(color: textColor),
          tableBorder: TableBorder.all(color: Colors.grey),
          code: TextStyle(
            backgroundColor: isUser
                ? Colors.blue.shade800
                : Colors.grey.shade300,
            color: isUser ? Colors.white : Colors.blueGrey.shade800,
            fontFamily: 'monospace',
            fontSize: 14,
          ),
        ),
      );
    }

    return SelectableText.rich(
      _buildHighlightedText(text, searchQuery, textColor),
      style: TextStyle(color: textColor, fontSize: 15),
    );
  }

  Widget _buildTextWithHighlight(
    String text,
    Color textColor,
    String searchQuery,
  ) {
    return SelectableText.rich(
      _buildHighlightedText(text, searchQuery, textColor),
      style: TextStyle(color: textColor, fontSize: 15),
    );
  }

  TextSpan _buildHighlightedText(
    String text,
    String query,
    Color defaultColor,
  ) {
    if (query.isEmpty) {
      return TextSpan(
        text: text,
        style: TextStyle(color: defaultColor),
      );
    }

    final pattern = RegExp(RegExp.escape(query), caseSensitive: false);
    final matches = pattern.allMatches(text);

    if (matches.isEmpty) {
      return TextSpan(
        text: text,
        style: TextStyle(color: defaultColor),
      );
    }

    final List<TextSpan> spans = [];
    int currentIndex = 0;

    for (final match in matches) {
      if (match.start > currentIndex) {
        spans.add(
          TextSpan(
            text: text.substring(currentIndex, match.start),
            style: TextStyle(color: defaultColor),
          ),
        );
      }

      spans.add(
        TextSpan(
          text: text.substring(match.start, match.end),
          style: TextStyle(
            color: defaultColor,
            backgroundColor: Colors.yellow,
            fontWeight: FontWeight.bold,
          ),
        ),
      );

      currentIndex = match.end;
    }

    if (currentIndex < text.length) {
      spans.add(
        TextSpan(
          text: text.substring(currentIndex),
          style: TextStyle(color: defaultColor),
        ),
      );
    }

    return TextSpan(children: spans);
  }

  Widget _buildTypingBubble() {
    return Align(
      alignment: Alignment.centerLeft,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircleAvatar(
            backgroundColor: Colors.blueGrey,
            child: Icon(Icons.computer, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 8),
          Container(
            margin: const EdgeInsets.symmetric(vertical: 6),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildAnimatedDot(_dotOneAnimation),
                _buildAnimatedDot(_dotTwoAnimation),
                _buildAnimatedDot(_dotThreeAnimation),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAnimatedDot(Animation<double> animation) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        return Opacity(
          opacity: animation.value,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2.0),
            child: Container(
              width: 6,
              height: 6,
              decoration: const BoxDecoration(
                color: Colors.black54,
                shape: BoxShape.circle,
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildEmptyChatPrompt(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.psychology_alt_outlined, size: 80),
          const SizedBox(height: 20),
          Text(
            "chat.welcome_message".tr(),
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}