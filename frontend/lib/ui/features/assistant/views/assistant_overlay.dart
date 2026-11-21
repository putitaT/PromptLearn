import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../domain/models/user_role.dart';
import '../../../../domain/repositories/assistant_repository.dart';
import '../../../core/theme/app_theme.dart';
import '../view_models/assistant_view_model.dart';

const _launcherLabel = 'Ask Prompt Learn';
const _launcherEdgePadding = 8.0;
const _launcherHintGap = 21.0;
const _green = Color(0xFF4ABE7A);
const _surface = AppColors.ink;
const _corner = BorderRadius.only(
  topLeft: Radius.circular(30),
  topRight: Radius.circular(30),
  bottomLeft: Radius.circular(30),
  bottomRight: Radius.circular(9),
);
const _shadow = BoxShadow(
  color: Color(0x9023342A),
  offset: Offset(30, 24),
  blurRadius: 126.3,
  spreadRadius: 4,
);

class AssistantOverlay extends StatefulWidget {
  const AssistantOverlay({
    super.key,
    required this.role,
    required this.repository,
  });

  final UserRole role;
  final AssistantRepository? repository;

  @override
  State<AssistantOverlay> createState() => _AssistantOverlayState();
}

class _AssistantOverlayState extends State<AssistantOverlay> {
  late final _chat = AssistantViewModel(
    role: widget.role,
    repository: widget.repository,
  );
  final _input = TextEditingController();
  final _focus = FocusNode();
  final _scroll = ScrollController();
  late final Timer _hintTimer;
  bool _showHint = true;
  bool _open = false;
  Offset? _launcherPosition;

  @override
  void initState() {
    super.initState();
    _chat.addListener(_showLatest);
    _hintTimer = Timer(const Duration(seconds: 5), () {
      setState(() => _showHint = false);
    });
  }

  @override
  void dispose() {
    _hintTimer.cancel();
    _chat.dispose();
    _input.dispose();
    _focus.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _showLatest() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _scroll.hasClients) {
        _scroll.jumpTo(_scroll.position.maxScrollExtent);
      }
    });
  }

  void _openChat() {
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() => _open = true);
    _showLatest();
  }

  void _closeChat() {
    _focus.unfocus();
    setState(() => _open = false);
  }

  void _send() {
    final text = _input.text.trim();
    if (text.isEmpty || !_chat.canSend) return;
    _input.clear();
    _focus.unfocus();
    _chat.send(text);
  }

  void _editMessage() {
    _input.text = _chat.messages.last.text;
    _chat.editFailedMessage();
    _focus.requestFocus();
  }

  Offset _keepLauncherInBounds(Offset position, Rect bounds) => Offset(
    position.dx.clamp(bounds.left, bounds.right),
    position.dy.clamp(bounds.top, bounds.bottom),
  );

  @override
  Widget build(BuildContext context) {
    final safe = MediaQuery.viewPaddingOf(context);
    final keyboard = MediaQuery.viewInsetsOf(context).bottom;
    return LayoutBuilder(
      builder: (context, constraints) {
        final sidebar =
            constraints.maxWidth - safe.horizontal >= 600 &&
            constraints.maxHeight - safe.vertical >= 480;
        final wide = sidebar && constraints.maxWidth >= 1000;
        final inset = wide ? 64.0 : 16.0;
        final right = safe.right + inset;
        final bottom = keyboard > 0
            ? keyboard + 10
            : safe.bottom + (wide ? 59 : (sidebar ? 24 : 76));
        final availableWidth = constraints.maxWidth - safe.left - inset - right;
        final availableHeight = constraints.maxHeight - safe.top - bottom - 12;
        final launcherSize = wide ? 75.0 : 52.0;
        final minLeft = safe.left + _launcherEdgePadding;
        final minTop = safe.top + _launcherEdgePadding;
        final launcherBounds = Rect.fromLTRB(
          minLeft,
          minTop,
          math.max(
            minLeft,
            constraints.maxWidth -
                safe.right -
                _launcherEdgePadding -
                launcherSize,
          ),
          math.max(
            minTop,
            constraints.maxHeight -
                safe.bottom -
                _launcherEdgePadding -
                launcherSize,
          ),
        );
        final launcherPosition = _keepLauncherInBounds(
          _launcherPosition ??
              Offset(
                constraints.maxWidth - right - launcherSize,
                constraints.maxHeight - bottom - launcherSize,
              ),
          launcherBounds,
        );
        final hintLeftEdge = launcherPosition.dx - _launcherHintGap;
        final hintRightEdge =
            launcherPosition.dx + launcherSize + _launcherHintGap;
        final screenRight =
            constraints.maxWidth - safe.right - _launcherEdgePadding;
        final hintOnLeft =
            hintLeftEdge - minLeft >= screenRight - hintRightEdge;

        return Stack(
          children: [
            if (_open) ...[
              Positioned.fill(
                child: ModalBarrier(
                  dismissible: true,
                  onDismiss: _closeChat,
                  semanticsLabel: 'Dismiss PL AI',
                ),
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: IgnorePointer(
                  child: Image.asset(
                    'assets/assistant/bottom-gradient.png',
                    fit: BoxFit.fitWidth,
                    excludeFromSemantics: true,
                  ),
                ),
              ),
              if (availableHeight > 0 && availableWidth > 0)
                Positioned(
                  right: right,
                  bottom: bottom,
                  width: math.min(481, availableWidth),
                  child: CallbackShortcuts(
                    bindings: {
                      const SingleActivator(LogicalKeyboardKey.escape):
                          _closeChat,
                    },
                    child: FocusScope(
                      autofocus: true,
                      child: ListenableBuilder(
                        listenable: _chat,
                        builder: (context, _) =>
                            _conversation(availableHeight, wide: wide),
                      ),
                    ),
                  ),
                ),
            ] else if (keyboard == 0) ...[
              if (wide && _showHint)
                Positioned(
                  left: hintOnLeft ? minLeft : hintRightEdge,
                  right: hintOnLeft
                      ? constraints.maxWidth - hintLeftEdge
                      : safe.right + _launcherEdgePadding,
                  bottom:
                      constraints.maxHeight -
                      launcherPosition.dy -
                      launcherSize +
                      8,
                  child: Align(
                    alignment: hintOnLeft
                        ? Alignment.centerRight
                        : Alignment.centerLeft,
                    child: const _LauncherHint(),
                  ),
                ),
              Positioned(
                left: launcherPosition.dx,
                top: launcherPosition.dy,
                child: GestureDetector(
                  dragStartBehavior: DragStartBehavior.down,
                  onPanStart: (_) => _launcherPosition = launcherPosition,
                  onPanUpdate: (details) => setState(() {
                    _launcherPosition = _keepLauncherInBounds(
                      _launcherPosition! + details.delta,
                      launcherBounds,
                    );
                  }),
                  child: _Launcher(size: launcherSize, onPressed: _openChat),
                ),
              ),
            ],
          ],
        );
      },
    );
  }

  Widget _conversation(double availableHeight, {required bool wide}) {
    final composerHeight = wide ? 75.0 : 56.0;
    const gap = 14.0;
    final panelHeight = math.min(394.0, availableHeight - composerHeight - gap);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        if (panelHeight >= 91) ...[
          Container(
            height: panelHeight,
            decoration: const BoxDecoration(
              color: _surface,
              borderRadius: BorderRadius.all(Radius.circular(30)),
              boxShadow: [_shadow],
            ),
            child: Material(
              color: Colors.transparent,
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(21, 2, 9, 0),
                    child: Row(
                      children: [
                        const Text(
                          'PL AI',
                          style: TextStyle(
                            color: Color(0xFFDFFFCC),
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const Spacer(),
                        IconButton(
                          tooltip: 'Close PL AI',
                          color: Colors.white70,
                          onPressed: _closeChat,
                          icon: const Icon(Icons.close, size: 20),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: ListView(
                      controller: _scroll,
                      keyboardDismissBehavior:
                          ScrollViewKeyboardDismissBehavior.onDrag,
                      padding: const EdgeInsets.fromLTRB(24, 0, 24, 18),
                      children: [
                        if (_chat.messages.isEmpty)
                          const _MessageBubble(
                            AssistantMessage(
                              text: 'What can I help you with?',
                              isUser: false,
                            ),
                          ),
                        for (final message in _chat.messages)
                          _MessageBubble(message),
                        if (_chat.isSending)
                          const Text(
                            'PL AI is thinking…',
                            semanticsLabel: 'PL AI is thinking',
                            style: TextStyle(color: Colors.white70),
                          ),
                        if (_chat.error case final error?) ...[
                          Text(
                            error,
                            style: const TextStyle(color: Colors.white),
                          ),
                          Wrap(
                            children: [
                              TextButton(
                                style: TextButton.styleFrom(
                                  foregroundColor: _green,
                                ),
                                onPressed: _chat.retry,
                                child: const Text('Retry'),
                              ),
                              TextButton(
                                style: TextButton.styleFrom(
                                  foregroundColor: _green,
                                ),
                                onPressed: _editMessage,
                                child: const Text('Edit question'),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: gap),
        ],
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 391),
          child: DecoratedBox(
            decoration: const BoxDecoration(
              color: _surface,
              borderRadius: _corner,
              boxShadow: [_shadow],
            ),
            child: Material(
              color: Colors.transparent,
              child: SizedBox(
                height: math.min(composerHeight, availableHeight),
                child: Row(
                  children: [
                    if (panelHeight < 91)
                      IconButton(
                        tooltip: 'Close PL AI',
                        color: Colors.white70,
                        onPressed: _closeChat,
                        icon: const Icon(Icons.close, size: 20),
                      )
                    else
                      _questionStarters(),
                    Expanded(
                      child: TextField(
                        controller: _input,
                        focusNode: _focus,
                        enabled: _chat.canSend,
                        cursorColor: _green,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: wide ? 20 : 16,
                        ),
                        decoration: const InputDecoration(
                          border: InputBorder.none,
                          isDense: true,
                          counterText: '',
                          hintText: 'Ask PL AI here!',
                          hintStyle: TextStyle(color: Colors.white70),
                        ),
                        textInputAction: TextInputAction.send,
                        maxLength: AssistantViewModel.messageLimit,
                        onSubmitted: (_) => _send(),
                      ),
                    ),
                    Padding(
                      padding: EdgeInsets.only(right: wide ? 14 : 6),
                      child: ValueListenableBuilder<TextEditingValue>(
                        valueListenable: _input,
                        builder: (context, value, _) => IconButton(
                          tooltip: 'Send question',
                          style: IconButton.styleFrom(
                            foregroundColor: _surface,
                            backgroundColor: _green,
                            disabledForegroundColor: Colors.white54,
                            disabledBackgroundColor: const Color(0x404ABE7A),
                          ),
                          onPressed:
                              _chat.canSend && value.text.trim().isNotEmpty
                              ? _send
                              : null,
                          icon: const Icon(
                            Icons.arrow_upward_rounded,
                            size: 21,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _questionStarters() {
    final starters = widget.role == UserRole.teacher
        ? ['Help me plan a lesson on ', 'Suggest a formative assessment for ']
        : ['Give me a hint for ', 'Help me understand '];
    return MenuAnchor(
      menuChildren: [
        for (final prompt in starters)
          MenuItemButton(
            onPressed: () {
              _input.value = TextEditingValue(
                text: prompt,
                selection: TextSelection.collapsed(offset: prompt.length),
              );
              _focus.requestFocus();
            },
            child: Text(prompt.trimRight()),
          ),
      ],
      builder: (context, controller, _) => IconButton(
        tooltip: 'Question starters',
        color: Colors.white,
        onPressed: _chat.canSend ? controller.open : null,
        icon: const Icon(Icons.add_rounded),
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble(this.message);

  final AssistantMessage message;

  @override
  Widget build(BuildContext context) {
    final text = Text(
      message.text,
      style: TextStyle(
        color: message.isUser ? _surface : Colors.white,
        fontSize: 18,
        height: message.isUser ? 1.25 : 1.6,
      ),
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: message.isUser
          ? Align(
              alignment: AlignmentDirectional.centerEnd,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 300),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  decoration: const BoxDecoration(
                    color: _green,
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(20),
                      topRight: Radius.circular(20),
                      bottomLeft: Radius.circular(20),
                      bottomRight: Radius.circular(6),
                    ),
                  ),
                  child: text,
                ),
              ),
            )
          : Align(alignment: AlignmentDirectional.centerStart, child: text),
    );
  }
}

class _LauncherHint extends StatelessWidget {
  const _LauncherHint();

  @override
  Widget build(BuildContext context) => const IgnorePointer(
    child: ExcludeSemantics(
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.all(Radius.circular(18)),
          boxShadow: [
            _shadow,
            BoxShadow(
              color: Color(0x36949DA6),
              offset: Offset(0, 4),
              blurRadius: 95.3,
              spreadRadius: 4,
            ),
          ],
        ),
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 18, vertical: 13),
          child: Text.rich(
            TextSpan(
              text: 'don’t understand. ',
              children: [
                TextSpan(
                  text: '$_launcherLabel!',
                  style: TextStyle(color: _green),
                ),
              ],
            ),
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.black,
              fontFamily: 'Roboto',
              decoration: TextDecoration.none,
              fontSize: 18,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ),
    ),
  );
}

class _Launcher extends StatelessWidget {
  const _Launcher({required this.size, required this.onPressed});

  final double size;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final corners = size == 75
        ? _corner
        : const BorderRadius.only(
            topLeft: Radius.circular(21),
            topRight: Radius.circular(21),
            bottomLeft: Radius.circular(21),
            bottomRight: Radius.circular(7),
          );
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: corners,
        boxShadow: const [_shadow],
      ),
      child: Material(
        color: _surface,
        borderRadius: corners,
        clipBehavior: Clip.antiAlias,
        child: IconButton(
          tooltip: _launcherLabel,
          style: IconButton.styleFrom(fixedSize: Size.square(size)),
          onPressed: onPressed,
          icon: SvgPicture.asset(
            'assets/assistant/spark.svg',
            width: size == 75 ? 36 : 25,
            height: size == 75 ? 36 : 25,
            excludeFromSemantics: true,
          ),
        ),
      ),
    );
  }
}
