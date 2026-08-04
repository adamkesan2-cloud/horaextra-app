// lib/presentation/features/chat/chat_screen.dart
import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:horaextra_app/core/constants/app_colors.dart';
import 'package:horaextra_app/core/providers/app_provider.dart';
import 'package:horaextra_app/core/providers/auth_provider.dart';

class ChatMessage {
  final String id;
  final String senderId;
  final String senderName;
  final String text;
  final DateTime timestamp;

  ChatMessage({
    required this.id,
    required this.senderId,
    required this.senderName,
    required this.text,
    required this.timestamp,
  });

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      id: json['id']?.toString() ?? UniqueKey().toString(),
      senderId:
          json['senderId']?.toString() ?? json['sender_id']?.toString() ?? '',
      senderName: json['senderName']?.toString() ??
          json['sender_name']?.toString() ??
          '',
      text: json['text']?.toString() ?? json['message']?.toString() ?? '',
      timestamp: DateTime.tryParse(json['timestamp']?.toString() ??
              json['createdAt']?.toString() ??
              json['created_at']?.toString() ??
              '') ??
          DateTime.now(),
    );
  }
}

class ChatScreen extends StatefulWidget {
  final String requestId;
  final String providerId;
  final String providerName;

  const ChatScreen({
    super.key,
    required this.requestId,
    required this.providerId,
    required this.providerName,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  // TODO: ajustar estas rotas conforme o backend real (controllers/routes de chat)
  String _messagesEndpoint(String baseUrl) =>
      '$baseUrl/api/chat/${widget.requestId}/messages';

  final TextEditingController _inputController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<ChatMessage> _messages = [];

  Timer? _pollTimer;
  bool _isLoading = true;
  bool _isSending = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadMessages();
    _pollTimer = Timer.periodic(
        const Duration(seconds: 3), (_) => _loadMessages(silent: true));
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _inputController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadMessages({bool silent = false}) async {
    if (!silent) setState(() => _isLoading = true);
    try {
      final ap = Provider.of<AppProvider>(context, listen: false);
      final res = await http
          .get(Uri.parse(_messagesEndpoint(ap.baseUrl)))
          .timeout(const Duration(seconds: 10));

      if (res.statusCode == 200 && mounted) {
        final data = jsonDecode(res.body);
        final list = (data is Map && data['messages'] is List)
            ? data['messages'] as List
            : (data is List ? data : []);
        final parsed = list
            .map((m) =>
                ChatMessage.fromJson(Map<String, dynamic>.from(m as Map)))
            .toList()
          ..sort((a, b) => a.timestamp.compareTo(b.timestamp));

        setState(() {
          _messages
            ..clear()
            ..addAll(parsed);
          _error = null;
          _isLoading = false;
        });
        _scrollToBottom();
      } else if (!silent) {
        setState(() {
          _isLoading = false;
          _error =
              'Não foi possível carregar as mensagens (${res.statusCode}).';
        });
      }
    } catch (e) {
      if (!silent && mounted) {
        setState(() {
          _isLoading = false;
          _error = 'Erro ao carregar mensagens. Verifica a ligação.';
        });
      }
    }
  }

  Future<void> _sendMessage() async {
    final text = _inputController.text.trim();
    if (text.isEmpty || _isSending) return;

    final auth = Provider.of<AuthProvider>(context, listen: false);
    final ap = Provider.of<AppProvider>(context, listen: false);
    final senderId = auth.currentUser?.id ?? '';
    final senderName = auth.currentUser?.name ?? 'Cliente';

    final optimistic = ChatMessage(
      id: 'local_${DateTime.now().millisecondsSinceEpoch}',
      senderId: senderId,
      senderName: senderName,
      text: text,
      timestamp: DateTime.now(),
    );

    setState(() {
      _messages.add(optimistic);
      _isSending = true;
      _inputController.clear();
    });
    _scrollToBottom();

    try {
      final res = await http
          .post(
            Uri.parse(_messagesEndpoint(ap.baseUrl)),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'senderId': senderId,
              'senderName': senderName,
              'text': text,
            }),
          )
          .timeout(const Duration(seconds: 10));

      if (res.statusCode != 200 && res.statusCode != 201 && mounted) {
        _showSnack(
            'Falha ao enviar mensagem (${res.statusCode}).', AppColors.error);
      } else {
        _loadMessages(silent: true);
      }
    } catch (e) {
      if (mounted) _showSnack('Erro ao enviar mensagem: $e', AppColors.error);
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
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

  void _showSnack(String message, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content:
          Text(message, style: const TextStyle(fontWeight: FontWeight.w600)),
      backgroundColor: color,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final myId = auth.currentUser?.id ?? '';

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded,
              color: AppColors.primaryBlue),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          widget.providerName,
          style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppColors.primaryBlue),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: AppColors.border, height: 1),
        ),
      ),
      body: Column(
        children: [
          Expanded(child: _buildBody(myId)),
          _buildInputBar(),
        ],
      ),
    );
  }

  Widget _buildBody(String myId) {
    if (_isLoading) {
      return const Center(
          child: CircularProgressIndicator(color: AppColors.primaryBlue));
    }
    if (_error != null && _messages.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(_error!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppColors.textSecondary)),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => _loadMessages(),
                style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryBlue,
                    foregroundColor: Colors.white),
                child: const Text('Tentar novamente'),
              ),
            ],
          ),
        ),
      );
    }
    if (_messages.isEmpty) {
      return const Center(
        child: Text('Ainda não há mensagens.\nEscreve para iniciar a conversa.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.textSecondary)),
      );
    }
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.all(16),
      itemCount: _messages.length,
      itemBuilder: (ctx, i) => _buildBubble(_messages[i], myId),
    );
  }

  Widget _buildBubble(ChatMessage msg, String myId) {
    final isMine = msg.senderId == myId;
    return Align(
      alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints:
            BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isMine ? AppColors.primaryBlue : AppColors.white,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(14),
            topRight: const Radius.circular(14),
            bottomLeft: Radius.circular(isMine ? 14 : 2),
            bottomRight: Radius.circular(isMine ? 2 : 14),
          ),
          border: isMine ? null : Border.all(color: AppColors.border),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 4,
                offset: const Offset(0, 2))
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              msg.text,
              style: TextStyle(
                color: isMine ? Colors.white : AppColors.primaryBlue,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '${msg.timestamp.hour.toString().padLeft(2, '0')}:${msg.timestamp.minute.toString().padLeft(2, '0')}',
              style: TextStyle(
                fontSize: 10,
                color: isMine
                    ? Colors.white.withOpacity(0.7)
                    : AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInputBar() {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
        decoration: const BoxDecoration(
          color: AppColors.white,
          border: Border(top: BorderSide(color: AppColors.border)),
        ),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _inputController,
                minLines: 1,
                maxLines: 4,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _sendMessage(),
                decoration: InputDecoration(
                  hintText: 'Escreve uma mensagem...',
                  filled: true,
                  fillColor: AppColors.creamLight,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: _isSending ? null : _sendMessage,
              child: Container(
                width: 44,
                height: 44,
                decoration: const BoxDecoration(
                    color: AppColors.primaryBlue, shape: BoxShape.circle),
                child: _isSending
                    ? const Padding(
                        padding: EdgeInsets.all(12),
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.send_rounded,
                        color: Colors.white, size: 20),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
