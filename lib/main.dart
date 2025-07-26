import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_pty/flutter_pty.dart';
import 'package:window_manager/window_manager.dart';
import 'package:xterm/xterm.dart';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:window_manager/window_manager.dart';

enum ResizeZoneEdge {
  left,
  right,
  top,
  bottom,
  topLeft,
  topRight,
  bottomLeft,
  bottomRight,
}

class ResizableWindow extends StatelessWidget {
  final Widget child;
  const ResizableWindow({super.key, required this.child});

  static const _resizeThickness = 6.0;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        child,
        // Edges
        _ResizeHandle(edge: ResizeZoneEdge.left, size: _resizeThickness),
        _ResizeHandle(edge: ResizeZoneEdge.right, size: _resizeThickness),
        _ResizeHandle(edge: ResizeZoneEdge.top, size: _resizeThickness),
        _ResizeHandle(edge: ResizeZoneEdge.bottom, size: _resizeThickness),
        // Corners
        _ResizeHandle(edge: ResizeZoneEdge.topLeft, size: _resizeThickness),
        _ResizeHandle(edge: ResizeZoneEdge.topRight, size: _resizeThickness),
        _ResizeHandle(edge: ResizeZoneEdge.bottomLeft, size: _resizeThickness),
        _ResizeHandle(edge: ResizeZoneEdge.bottomRight, size: _resizeThickness),
      ],
    );
  }
}

class _ResizeHandle extends StatelessWidget {
  final ResizeZoneEdge edge;
  final double size;

  const _ResizeHandle({required this.edge, required this.size});

  SystemMouseCursor get cursor {
    switch (edge) {
      case ResizeZoneEdge.left:
      case ResizeZoneEdge.right:
        return SystemMouseCursors.resizeLeftRight;
      case ResizeZoneEdge.top:
      case ResizeZoneEdge.bottom:
        return SystemMouseCursors.resizeUpDown;
      case ResizeZoneEdge.topLeft:
      case ResizeZoneEdge.bottomRight:
        return SystemMouseCursors.resizeUpLeftDownRight;
      case ResizeZoneEdge.topRight:
      case ResizeZoneEdge.bottomLeft:
        return SystemMouseCursors.resizeUpRightDownLeft;
    }
  }

  ResizeEdge get resizeEdge {
    switch (edge) {
      case ResizeZoneEdge.left:
        return ResizeEdge.left;
      case ResizeZoneEdge.right:
        return ResizeEdge.right;
      case ResizeZoneEdge.top:
        return ResizeEdge.top;
      case ResizeZoneEdge.bottom:
        return ResizeEdge.bottom;
      case ResizeZoneEdge.topLeft:
        return ResizeEdge.topLeft;
      case ResizeZoneEdge.topRight:
        return ResizeEdge.topRight;
      case ResizeZoneEdge.bottomLeft:
        return ResizeEdge.bottomLeft;
      case ResizeZoneEdge.bottomRight:
        return ResizeEdge.bottomRight;
    }
  }

  @override
  Widget build(BuildContext context) {
    Alignment alignment;
    double? width;
    double? height;

    switch (edge) {
      case ResizeZoneEdge.left:
        alignment = Alignment.centerLeft;
        width = size;
        height = double.infinity;
        break;
      case ResizeZoneEdge.right:
        alignment = Alignment.centerRight;
        width = size;
        height = double.infinity;
        break;
      case ResizeZoneEdge.top:
        alignment = Alignment.topCenter;
        width = double.infinity;
        height = size;
        break;
      case ResizeZoneEdge.bottom:
        alignment = Alignment.bottomCenter;
        width = double.infinity;
        height = size;
        break;
      case ResizeZoneEdge.topLeft:
        alignment = Alignment.topLeft;
        width = size;
        height = size;
        break;
      case ResizeZoneEdge.topRight:
        alignment = Alignment.topRight;
        width = size;
        height = size;
        break;
      case ResizeZoneEdge.bottomLeft:
        alignment = Alignment.bottomLeft;
        width = size;
        height = size;
        break;
      case ResizeZoneEdge.bottomRight:
        alignment = Alignment.bottomRight;
        width = size;
        height = size;
        break;
    }

    return Align(
      alignment: alignment,
      child: MouseRegion(
        cursor: cursor,
        child: GestureDetector(
          behavior: HitTestBehavior.translucent,
          onPanStart: (_) => windowManager.startResizing(resizeEdge),
          child: SizedBox(width: width, height: height),
        ),
      ),
    );
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await windowManager.ensureInitialized();
  runApp(Flutterm());
}

bool get isDesktop {
  if (kIsWeb) return false;
  return [
    TargetPlatform.windows,
    TargetPlatform.linux,
    TargetPlatform.macOS,
  ].contains(defaultTargetPlatform);
}

class Flutterm extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'flutterm',
      debugShowCheckedModeBanner: false,
      home: Home(),
    );
  }
}

class Home extends StatefulWidget {
  Home({super.key});

  @override
  // ignore: library_private_types_in_public_api
  _HomeState createState() => _HomeState();
}

class _HomeState extends State<Home> {
  final terminal = Terminal(maxLines: 10000);

  final terminalController = TerminalController();

  late final Pty pty;

  late final FocusNode _terminalFocusNode;

  @override
  void initState() {
    super.initState();

    _terminalFocusNode = FocusNode();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _terminalFocusNode.requestFocus();
      if (mounted) _startPty();
    });

    FocusManager.instance.highlightStrategy =
        FocusHighlightStrategy.alwaysTraditional;
  }

  void _startPty() {
    pty = Pty.start(
      shell,
      columns: terminal.viewWidth,
      rows: terminal.viewHeight,
    );

    pty.output
        .cast<List<int>>()
        .transform(Utf8Decoder())
        .listen(terminal.write);

    pty.exitCode.then((code) {
      terminal.write('the process exited with exit code $code');
    });

    terminal.onOutput = (data) {
      pty.write(const Utf8Encoder().convert(data));
    };

    terminal.onResize = (w, h, pw, ph) {
      pty.resize(h, w);
    };
  }

  final terminalShortcuts = <ShortcutActivator, Intent>{
    LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.keyA):
        const TerminalShortcutIntent('\x01'),
    LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.keyE):
        const TerminalShortcutIntent('\x05'),
    LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.keyK):
        const TerminalShortcutIntent('\x0b'),
    LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.keyU):
        const TerminalShortcutIntent('\x15'),
    LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.keyW):
        const TerminalShortcutIntent('\x17'),
    LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.keyL):
        const TerminalShortcutIntent('\x0c'),
    LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.keyC):
        const TerminalShortcutIntent('\x03'),
    LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.keyD):
        const TerminalShortcutIntent('\x04'),
  };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: ResizableWindow(
          child: Column(
            children: [
              CustomTitleBar(),
              Expanded(
                child: Actions(
                  actions: {
                    TerminalShortcutIntent: SendTerminalSequenceAction((
                      sequence,
                    ) {
                      pty.write(const Utf8Encoder().convert(sequence));
                    }),
                  },
                  child: TerminalView(
                    terminal,
                    controller: terminalController,
                    autofocus: true,
                    shortcuts: terminalShortcuts,
                    // backgroundOpacity: 0.7,
                    onSecondaryTapDown: (details, offset) async {
                      final RenderBox overlay =
                          Overlay.of(context).context.findRenderObject()
                              as RenderBox;

                      final selection = terminalController.selection;
                      final selectedText = selection != null
                          ? terminal.buffer.getText(selection)
                          : null;

                      final choice = await showMenu<String>(
                        context: context,
                        position: RelativeRect.fromRect(
                          details.globalPosition & const Size(40, 40),
                          Offset.zero & overlay.size,
                        ),
                        items: [
                          if (selectedText != null)
                            const PopupMenuItem<String>(
                              value: 'cut',
                              child: Text('Cut'),
                            ),
                          if (selectedText != null)
                            const PopupMenuItem<String>(
                              value: 'copy',
                              child: Text('Copy'),
                            ),
                          const PopupMenuItem<String>(
                            value: 'paste',
                            child: Text('Paste'),
                          ),
                        ],
                      );

                      switch (choice) {
                        case 'cut':
                          if (selectedText != null) {
                            await Clipboard.setData(
                              ClipboardData(text: selectedText),
                            );
                            terminal.paste(''); // simulate cut (optional)
                            terminalController.clearSelection();
                          }
                          break;
                        case 'copy':
                          if (selectedText != null) {
                            await Clipboard.setData(
                              ClipboardData(text: selectedText),
                            );
                            terminalController.clearSelection();
                          }
                          break;
                        case 'paste':
                          final data = await Clipboard.getData('text/plain');
                          final text = data?.text;
                          if (text != null) {
                            terminal.paste(text);
                          }
                          break;
                      }
                    },

                    textStyle: TerminalStyle(fontSize: 18),
                    theme: TerminalTheme(
                      background: Color.fromARGB(255, 0, 0, 0),
                      foreground: Color(0xFFcdd6f4),
                      cursor: Color(0xFFf5e0dc),
                      selection: const Color(0x80313244),
                      black: Color(0xFF45475a),
                      red: Color(0xFFf38ba8),
                      green: Color(0xFFa6e3a1),
                      yellow: Color(0xFFf9e2af),
                      blue: Color(0xFF89b4fa),
                      magenta: Color(0xFFf5c2e7),
                      cyan: Color(0xFF94e2d5),
                      white: Color(0xFFbac2de),
                      brightBlack: Color(0xFF585b70),
                      brightRed: Color(0xFFf38ba8),
                      brightGreen: Color(0xFFa6e3a1),
                      brightYellow: Color(0xFFf9e2af),
                      brightBlue: Color(0xFF89b4fa),
                      brightMagenta: Color(0xFFf5c2e7),
                      brightCyan: Color(0xFF94e2d5),
                      brightWhite: Color(0xFFa6adc8),
                      searchHitBackground: Color(0xFF45475a),
                      searchHitBackgroundCurrent: Color(0xFF89b4fa),
                      searchHitForeground: Color(0xFFcdd6f4),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String get shell {
  if (Platform.isMacOS || Platform.isLinux) {
    return Platform.environment['SHELL'] ?? 'bash';
  }

  if (Platform.isWindows) {
    return 'cmd.exe';
  }

  return 'sh';
}

class CustomTitleBar extends StatelessWidget {
  const CustomTitleBar({super.key});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onPanStart: (_) => windowManager.startDragging(),
      onDoubleTap: () async {
        final isMax = await windowManager.isMaximized();
        if (isMax) {
          await windowManager.unmaximize();
        } else {
          await windowManager.maximize();
        }
      },
      child: Container(
        height: 45,
        color: const Color.fromARGB(255, 0, 0, 0),
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Row(
          children: [
            // Traffic Light Buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _WindowButton(
                  color: const Color(0xFFf38ba8),
                  onPressed: () => windowManager.close(),
                ),
                const SizedBox(width: 8),
                _WindowButton(
                  color: const Color(0xFFf9e2af),
                  onPressed: () => windowManager.minimize(),
                ),
                const SizedBox(width: 8),
                _WindowButton(
                  color: const Color(0xFFa6e3a1),
                  onPressed: () async {
                    final isMax = await windowManager.isMaximized();
                    if (isMax) {
                      await windowManager.unmaximize();
                    } else {
                      await windowManager.maximize();
                    }
                  },
                ),
              ],
            ),
            const Spacer(),
            const Text(
              '',
              style: TextStyle(
                color: Color(0xFFcdd6f4),
                fontWeight: FontWeight.bold,
              ),
            ),
            const Spacer(flex: 2),
          ],
        ),
      ),
    );
  }
}

class _WindowButton extends StatelessWidget {
  final Color color;
  final VoidCallback onPressed;

  const _WindowButton({required this.color, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPressed,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
      ),
    );
  }
}

class TerminalShortcutIntent extends Intent {
  final String sequence;
  const TerminalShortcutIntent(this.sequence);
}

class SendTerminalSequenceAction extends Action<TerminalShortcutIntent> {
  final void Function(String sequence) send;

  SendTerminalSequenceAction(this.send);

  @override
  Object? invoke(covariant TerminalShortcutIntent intent) {
    send(intent.sequence);
    return null;
  }
}
