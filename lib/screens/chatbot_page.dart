import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import '../config/api_config.dart';
import '../services/chatbot_service.dart';
import '../services/chat_history_store.dart';
import '../theme/app_colors.dart';

class ChatbotPage extends StatefulWidget {
  const ChatbotPage({super.key});

  @override
  State<ChatbotPage> createState() => _ChatbotPageState();
}

class _ChatbotPageState extends State<ChatbotPage> {
  final _service = ChatbotService(baseUrl: ApiConfig.baseUrl);
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  final List<ChatMessage> _history = [];
  bool _sending = false;
  bool _initialLoading = true;

  static const int _maxHistoryPairs = 6;

  static final ChatMessage _welcome = ChatMessage.assistant(
    "Selam 👋 Ben Healzy Asistan. Sağlık ve uygulama hakkındaki sorularını sorabilirsin, yardımcı olmaya çalışacağım.",
  );

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    final saved = await ChatHistoryStore.load();
    if (!mounted) return;
    setState(() {
      if (saved.isNotEmpty) {
        _history.addAll(saved);
      } else {
        _history.add(_welcome);
      }
      _initialLoading = false;
    });
    _scrollToBottom();
  }

  Future<void> _clearHistory() async {
    await ChatHistoryStore.clear();
    if (!mounted) return;
    setState(() {
      _history.clear();
      _history.add(_welcome);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _sending) return;

    setState(() {
      _history.add(ChatMessage.user(text));
      _sending = true;
      _controller.clear();
    });

    _scrollToBottom();

    try {
      final historyForApi = _trimmedHistoryForApi();
      final reply = await _service.ask(message: text, history: historyForApi);
      if (!mounted) return;
      setState(() {
        _history.add(ChatMessage.assistant(reply));
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _history.add(ChatMessage.assistant(
          "Üzgünüm, şu an yanıt veremiyorum. Biraz sonra tekrar dener misin?",
        ));
      });
    } finally {
      if (mounted) setState(() => _sending = false);
      await ChatHistoryStore.save(_history);
      _scrollToBottom();
    }
  }

  List<ChatMessage> _trimmedHistoryForApi() {
    final excludingLastUserMsg = _history.take(_history.length - 1).toList();
    final tailStart = excludingLastUserMsg.length > _maxHistoryPairs * 2
        ? excludingLastUserMsg.length - _maxHistoryPairs * 2
        : 0;
    return excludingLastUserMsg.sublist(tailStart);
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent + 120,
        duration: const Duration(milliseconds: 240),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final appBarFg = isDark ? Colors.white : AppColors.midnight;
    final appBarSubFg = isDark
        ? Colors.white70
        : AppColors.midnight.withValues(alpha: 0.65);
    final appBarAvatarBg = isDark
        ? Colors.white.withValues(alpha: 0.15)
        : AppColors.midnight.withValues(alpha: 0.08);

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBg : AppColors.pearl,
      appBar: AppBar(
        backgroundColor:
            isDark ? AppColors.darkSurface : Colors.transparent,
        foregroundColor: appBarFg,
        elevation: 0,
        title: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: appBarAvatarBg,
              ),
              padding: const EdgeInsets.all(2),
              clipBehavior: Clip.antiAlias,
              child: Lottie.asset(
                'assets/animations/ai_robot.json',
                fit: BoxFit.contain,
                repeat: true,
              ),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Healzy Asistan",
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: appBarFg,
                  ),
                ),
                Text(
                  "Sağlık ve uygulama yardımı",
                  style: TextStyle(fontSize: 12, color: appBarSubFg),
                ),
              ],
            ),
          ],
        ),
        actions: [
          if (_history.length > 1)
            IconButton(
              tooltip: "Sohbeti temizle",
              icon: const Icon(Icons.delete_outline_rounded),
              onPressed: () async {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text("Sohbeti sil"),
                    content: const Text("Tüm sohbet geçmişi silinecek. Devam edilsin mi?"),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Vazgeç")),
                      TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text("Sil")),
                    ],
                  ),
                );
                if (confirm == true) await _clearHistory();
              },
            ),
        ],
      ),
      body: Container(
        decoration: isDark ? null : BoxDecoration(gradient: AppColors.lightPageGradient),
        child: SafeArea(
          top: false,
          child: _initialLoading
              ? const Center(child: CircularProgressIndicator())
              : Column(
            children: [
              Expanded(
                child: ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.fromLTRB(12, 16, 12, 8),
                  itemCount: _history.length + (_sending ? 1 : 0),
                  itemBuilder: (_, i) {
                    if (i == _history.length && _sending) {
                      return const _TypingBubble();
                    }
                    final msg = _history[i];
                    return _MessageBubble(
                      text: msg.content,
                      isUser: msg.role == "user",
                      isDark: isDark,
                    );
                  },
                ),
              ),
              _InputBar(
                controller: _controller,
                sending: _sending,
                onSend: _send,
                isDark: isDark,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  final String text;
  final bool isUser;
  final bool isDark;

  const _MessageBubble({required this.text, required this.isUser, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final bg = isUser
        ? (isDark ? AppColors.midnightSoft : AppColors.midnight)
        : (isDark ? AppColors.darkSurface : Colors.white);
    final fg = isUser
        ? Colors.white
        : (isDark ? AppColors.darkTextPrimary : AppColors.textPrimary);

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.78),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(18),
            topRight: const Radius.circular(18),
            bottomLeft: Radius.circular(isUser ? 18 : 4),
            bottomRight: Radius.circular(isUser ? 4 : 18),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.06),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Text(
          text,
          style: TextStyle(color: fg, fontSize: 15, height: 1.4),
        ),
      ),
    );
  }
}

class _TypingBubble extends StatefulWidget {
  const _TypingBubble();

  @override
  State<_TypingBubble> createState() => _TypingBubbleState();
}

class _TypingBubbleState extends State<_TypingBubble> with SingleTickerProviderStateMixin {
  late final AnimationController _ac;

  @override
  void initState() {
    super.initState();
    _ac = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200))..repeat();
  }

  @override
  void dispose() {
    _ac.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final dotColor = isDark ? Colors.white70 : AppColors.textSecondary;
    final bg = isDark ? AppColors.darkSurface : Colors.white;

    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(18),
            topRight: Radius.circular(18),
            bottomLeft: Radius.circular(4),
            bottomRight: Radius.circular(18),
          ),
        ),
        child: AnimatedBuilder(
          animation: _ac,
          builder: (_, __) {
            return Row(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(3, (i) {
                final phase = (_ac.value + i * 0.2) % 1.0;
                final scale = 0.6 + 0.4 * (1 - (phase - 0.5).abs() * 2).clamp(0.0, 1.0);
                return Padding(
                  padding: EdgeInsets.symmetric(horizontal: 3),
                  child: Transform.scale(
                    scale: scale,
                    child: Container(
                      width: 7,
                      height: 7,
                      decoration: BoxDecoration(
                        color: dotColor,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                );
              }),
            );
          },
        ),
      ),
    );
  }
}

class _InputBar extends StatefulWidget {
  final TextEditingController controller;
  final bool sending;
  final VoidCallback onSend;
  final bool isDark;

  const _InputBar({
    required this.controller,
    required this.sending,
    required this.onSend,
    required this.isDark,
  });

  @override
  State<_InputBar> createState() => _InputBarState();
}

class _InputBarState extends State<_InputBar> {
  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _speechReady = false;
  bool _listening = false;
  String? _resolvedLocaleId;
  String _baseTextBeforeListen = '';

  @override
  void dispose() {
    _speech.stop();
    super.dispose();
  }

  Future<String?> _pickLocaleId() async {
    try {
      final locales = await _speech.locales();
      final tr = locales.firstWhere(
        (l) => l.localeId.toLowerCase().startsWith('tr'),
        orElse: () => locales.isNotEmpty
            ? locales.first
            : stt.LocaleName('', ''),
      );
      return tr.localeId.isEmpty ? null : tr.localeId;
    } catch (_) {
      return null;
    }
  }

  Future<void> _toggleDictation() async {
    if (widget.sending) return;

    if (_listening) {
      await _speech.stop();
      if (!mounted) return;
      setState(() => _listening = false);
      return;
    }

    if (!_speechReady) {
      _speechReady = await _speech.initialize(
        onStatus: (status) {
          if (!mounted) return;
          if (status == stt.SpeechToText.doneStatus ||
              status == stt.SpeechToText.notListeningStatus) {
            setState(() => _listening = false);
          }
        },
        onError: (err) {
          if (!mounted) return;
          setState(() => _listening = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Ses tanıma hatası: ${err.errorMsg}')),
          );
        },
        debugLogging: false,
      );
      if (!_speechReady) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Mikrofon izni verilmedi veya cihazda ses tanıma kullanılamıyor.',
            ),
          ),
        );
        return;
      }
      _resolvedLocaleId = await _pickLocaleId();
    }

    _baseTextBeforeListen = widget.controller.text;
    setState(() => _listening = true);

    await _speech.listen(
      localeId: _resolvedLocaleId,
      onResult: (result) {
        if (!mounted) return;
        final joiner = _baseTextBeforeListen.isEmpty ||
                _baseTextBeforeListen.endsWith(' ')
            ? ''
            : ' ';
        final merged =
            '$_baseTextBeforeListen$joiner${result.recognizedWords}';
        widget.controller.value = TextEditingValue(
          text: merged,
          selection: TextSelection.collapsed(offset: merged.length),
        );
      },
      listenOptions: stt.SpeechListenOptions(
        listenMode: stt.ListenMode.dictation,
        partialResults: true,
        cancelOnError: true,
        autoPunctuation: true,
      ),
      listenFor: const Duration(minutes: 1),
      pauseFor: const Duration(seconds: 4),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDark;
    return Container(
      padding: EdgeInsets.fromLTRB(
          12, 8, 12, MediaQuery.of(context).padding.bottom + 8),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : Colors.white,
        border: Border(
          top: BorderSide(
            color: isDark ? AppColors.darkBorder : AppColors.border,
            width: 0.5,
          ),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: widget.controller,
              minLines: 1,
              maxLines: 4,
              textCapitalization: TextCapitalization.sentences,
              enabled: !widget.sending,
              onSubmitted: (_) => widget.onSend(),
              decoration: InputDecoration(
                hintText: _listening
                    ? "Dinleniyor... konuşun"
                    : "Asistana bir şey sor...",
                filled: true,
                fillColor: isDark ? AppColors.darkBg : AppColors.surface,
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Material(
            color: _listening
                ? Colors.redAccent
                : (isDark ? AppColors.midnightSoft : AppColors.midnight)
                    .withValues(alpha: 0.12),
            shape: const CircleBorder(),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: widget.sending ? null : _toggleDictation,
              child: Container(
                width: 44,
                height: 44,
                alignment: Alignment.center,
                child: Icon(
                  _listening ? Icons.mic : Icons.mic_none_rounded,
                  color: _listening
                      ? Colors.white
                      : (isDark ? AppColors.darkTextPrimary : AppColors.midnight),
                  size: 22,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Material(
            color: isDark ? AppColors.midnightSoft : AppColors.midnight,
            shape: const CircleBorder(),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: widget.sending ? null : widget.onSend,
              child: Container(
                width: 44,
                height: 44,
                alignment: Alignment.center,
                child: widget.sending
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.send_rounded,
                        color: Colors.white, size: 20),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
