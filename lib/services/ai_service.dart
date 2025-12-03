import 'dart:async';
import 'package:flutter/services.dart';
import 'package:firebase_ai/firebase_ai.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

final systemPromptProvider = FutureProvider<String>((ref) async {
  return rootBundle.loadString('assets/system_prompt.md');
});

final firebaseAppProvider = Provider<FirebaseApp>((ref) {
  return Firebase.app();
});

final firestoreProvider = Provider<FirebaseFirestore>((ref) {
  return FirebaseFirestore.instance;
});

final geminiModelProvider = FutureProvider<GenerativeModel>((ref) async {
  await ref.watch(firebaseAppProvider);
  final systemPrompt = await ref.watch(systemPromptProvider.future);

  return FirebaseAI.googleAI().generativeModel(
    model: 'gemini-2.0-flash',
    systemInstruction: Content.system(systemPrompt),
  );
});

class ChatSessionModel {
  final String id;
  final String title;
  final List<ChatMessage> messages;
  final DateTime createdAt;

  ChatSessionModel({
    required this.id,
    required this.title,
    required this.messages,
    required this.createdAt,
  });

  ChatSessionModel copyWith({String? title, List<ChatMessage>? messages}) {
    return ChatSessionModel(
      id: id,
      title: title ?? this.title,
      messages: messages ?? this.messages,
      createdAt: createdAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'createdAt': Timestamp.fromDate(createdAt),
      'messages': messages.map((msg) => msg.toMap()).toList(),
    };
  }

  factory ChatSessionModel.fromMap(Map<String, dynamic> map) {
    return ChatSessionModel(
      id: map['id'] as String,
      title: map['title'] as String,
      createdAt: (map['createdAt'] as Timestamp).toDate(),
      messages: (map['messages'] as List<dynamic>)
          .map((msgMap) => ChatMessage.fromMap(msgMap as Map<String, dynamic>))
          .toList(),
    );
  }
}

final currentChatSessionIdProvider = StateProvider<String>(
  (ref) => const Uuid().v4(),
);

final geminiChatSessionProvider = FutureProvider<ChatSession>((ref) async {
  final model = await ref.watch(geminiModelProvider.future);
  final currentSessionId = ref.watch(currentChatSessionIdProvider);
  final firestore = ref.read(firestoreProvider);

  DocumentSnapshot sessionDoc = await firestore
      .collection('chatSessionswithAI')
      .doc(currentSessionId)
      .get();

  List<Content> history = [];
  if (sessionDoc.exists) {
    ChatSessionModel sessionData = ChatSessionModel.fromMap(
      sessionDoc.data() as Map<String, dynamic>,
    );

    history = sessionData.messages.map((msg) {
      if (msg.isUser) {
        return Content.text(msg.text);
      } else {
        return Content.model([TextPart(msg.text)]);
      }
    }).toList();
  }

  return model.startChat(history: history);
});

class ChatMessage {
  final String id;
  final String text;
  final bool isUser;
  final DateTime timestamp;

  ChatMessage({
    required this.id,
    required this.text,
    required this.isUser,
    required this.timestamp,
  });

  factory ChatMessage.user(String text) => ChatMessage(
    id: const Uuid().v4(),
    text: text,
    isUser: true,
    timestamp: DateTime.now(),
  );

  factory ChatMessage.llm(String text) => ChatMessage(
    id: const Uuid().v4(),
    text: text,
    isUser: false,
    timestamp: DateTime.now(),
  );

  ChatMessage copyWith({String? text, bool? isUser, DateTime? timestamp}) =>
      ChatMessage(
        id: id,
        text: text ?? this.text,
        isUser: isUser ?? this.isUser,
        timestamp: timestamp ?? this.timestamp,
      );

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'text': text,
      'isUser': isUser,
      'timestamp': Timestamp.fromDate(timestamp),
    };
  }

  factory ChatMessage.fromMap(Map<String, dynamic> map) {
    return ChatMessage(
      id: map['id'] as String,
      text: map['text'] as String,
      isUser: map['isUser'] as bool,
      timestamp: (map['timestamp'] as Timestamp).toDate(),
    );
  }
}

final chatStateProvider =
    StateNotifierProvider<ChatStateNotifier, List<ChatMessage>>((ref) {
      final currentSessionId = ref.watch(currentChatSessionIdProvider);
      final firestore = ref.read(firestoreProvider);
      return ChatStateNotifier(
        firestore: firestore,
        currentSessionId: currentSessionId,
      );
    });

final chatSearchQueryProvider = StateProvider<String>((ref) => '');

final filteredChatMessagesProvider = Provider<List<ChatMessage>>((ref) {
  final searchQuery = ref.watch(chatSearchQueryProvider);
  final messages = ref.watch(chatStateProvider);
  
  if (searchQuery.isEmpty) {
    return messages;
  }
  
  final query = searchQuery.toLowerCase();
  return messages.where((message) {
    return message.text.toLowerCase().contains(query);
  }).toList();
});

class ChatStateNotifier extends StateNotifier<List<ChatMessage>> {
  final FirebaseFirestore _firestore;
  final String _currentSessionId;
  StreamSubscription? _sessionSubscription;

  ChatStateNotifier({
    required FirebaseFirestore firestore,
    required String currentSessionId,
  }) : _firestore = firestore,
       _currentSessionId = currentSessionId,
       super([]) {
    _listenToSessionMessages();
  }

  @override
  void dispose() {
    _sessionSubscription?.cancel();
    super.dispose();
  }

  void _listenToSessionMessages() {
    _sessionSubscription?.cancel();
    _sessionSubscription = _firestore
        .collection('chatSessionswithAI')
        .doc(_currentSessionId)
        .snapshots()
        .listen(
          (snapshot) {
            if (snapshot.exists && snapshot.data() != null) {
              final sessionData = ChatSessionModel.fromMap(snapshot.data()!);

              state = sessionData.messages;
            } else {
              state = [];
            }
          },
          onError: (error) {
            print("Error listening to chat session: $error");
          },
        );
  }

  void addUserMessage(String text) {
    final msg = ChatMessage.user(text);
    state = [...state, msg];
    _saveSessionToFirestore();
  }

  ChatMessage createLlmMessage() {
    final msg = ChatMessage.llm("");
    state = [...state, msg];
    _saveSessionToFirestore();
    return msg;
  }

  void appendToMessage(String id, String chunk) {
    state = [
      for (final m in state) m.id == id ? m.copyWith(text: m.text + chunk) : m,
    ];
  }

  void finalizeMessage(String id) {
    _saveSessionToFirestore();
  }

  Future<void> _saveSessionToFirestore() async {
    final docRef = _firestore.collection('chatSessionswithAI').doc(_currentSessionId);

    DateTime createdAt;
    final existing = await docRef.get();
    if (existing.exists) {
      createdAt = (existing.data()!['createdAt'] as Timestamp).toDate();
    } else {
      createdAt = DateTime.now();
    }

    final sessionTitle = state.isNotEmpty
        ? state.first.text.split('\n').first
        : "New Chat ${DateFormat.yMMMd().add_jm().format(DateTime.now())}";

    final session = ChatSessionModel(
      id: _currentSessionId,
      title: sessionTitle,
      messages: state,
      createdAt: createdAt,
    );

    await docRef.set(session.toMap());
  }

}

final logStateProvider = StateNotifierProvider<LogStateNotifier, List<String>>((
  ref,
) {
  return LogStateNotifier();
});

class LogStateNotifier extends StateNotifier<List<String>> {
  LogStateNotifier() : super([]);

  void logUserText(String text) {
    state = [...state, "USER: $text"];
  }

  void logLlmText(String text) {
    state = [...state, "AI: $text"];
  }

  void logError(Object e, {StackTrace? st}) {
    state = [...state, "ERROR: $e\n$st"];
  }
}

final allChatSessionsStreamProvider = StreamProvider<List<ChatSessionModel>>((
  ref,
) {
  final firestore = ref.read(firestoreProvider);
  return firestore
      .collection('chatSessionswithAI')
      .orderBy('createdAt', descending: true)
      .snapshots()
      .map((snapshot) {
        return snapshot.docs
            .map((doc) => ChatSessionModel.fromMap(doc.data()))
            .toList();
      });
});

final filteredChatSessionsProvider =
    Provider.family<AsyncValue<List<ChatSessionModel>>, String>((
      ref,
      searchTerm,
    ) {
      final allSessionsAsync = ref.watch(allChatSessionsStreamProvider);

      return allSessionsAsync.when(
        data: (sessions) {
          if (searchTerm.isEmpty) {
            return AsyncValue.data(sessions);
          }
          final lowerCaseSearchTerm = searchTerm.toLowerCase();
          final filtered = sessions.where((session) {
            return session.title.toLowerCase().contains(lowerCaseSearchTerm) ||
                session.messages.any(
                  (msg) => msg.text.toLowerCase().contains(lowerCaseSearchTerm),
                );
          }).toList();
          return AsyncValue.data(filtered);
        },
        loading: () => const AsyncValue.loading(),
        error: (e, st) => AsyncValue.error(e, st),
      );
    });

final geminiChatServiceProvider = Provider<GeminiChatService>(
  (ref) => GeminiChatService(ref),
);

class GeminiChatService {
  GeminiChatService(this.ref);
  final Ref ref;

  Future<void> sendMessage(String text) async {
    final chat = await ref.read(geminiChatSessionProvider.future);
    final chatState = ref.read(chatStateProvider.notifier);
    final logState = ref.read(logStateProvider.notifier);

    chatState.addUserMessage(text);
    logState.logUserText(text);

    final llmMsg = chatState.createLlmMessage();

    try {
      final responseStream = chat.sendMessageStream(Content.text(text));
      StringBuffer fullReplyBuffer = StringBuffer();

      await for (final response in responseStream) {
        final chunk = response.text;
        if (chunk != null) {
          fullReplyBuffer.write(chunk);
          chatState.appendToMessage(llmMsg.id, chunk);
        }
      }
      logState.logLlmText(fullReplyBuffer.toString());
    } catch (e, st) {
      chatState.appendToMessage(
        llmMsg.id,
        "⚠️ Error: Could not process your request.",
      );
      logState.logError(e, st: st);
    } finally {
      chatState.finalizeMessage(llmMsg.id);
    }
  }

  void startNewChatSession() {
    final currentSessionId = ref.read(currentChatSessionIdProvider);
    final currentMessages = ref.read(chatStateProvider);
    if (currentMessages.isEmpty) {
      _deleteChatSession(currentSessionId);
    }

    final newSessionId = const Uuid().v4();
    ref.read(currentChatSessionIdProvider.notifier).state = newSessionId;
    ref.invalidate(geminiChatSessionProvider);
  }

  Future<void> _deleteChatSession(String sessionId) async {
    final firestore = ref.read(firestoreProvider);
    try {
      await firestore.collection('chatSessionswithAI').doc(sessionId).delete();
    } catch (e) {
      print('Error deleting chat session $sessionId: $e');
    }
  }

  Future<void> deleteCurrentChatSession() async {
    final currentSessionId = ref.read(currentChatSessionIdProvider);
    await _deleteChatSession(currentSessionId);

    startNewChatSession();
  }
}
