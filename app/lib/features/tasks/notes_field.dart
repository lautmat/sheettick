import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/tasks/note_links.dart';

/// Opens [uri] in the browser or the mail app.
typedef LinkOpener = Future<bool> Function(Uri uri);

Future<bool> _openExternally(Uri uri) => launchUrl(uri, mode: LaunchMode.externalApplication);

/// A task's notes: rendered Markdown (headings, lists, links, bold, code) while they are not being edited, the raw text in
/// a field while they are. Tapping the rendered notes starts editing; leaving the field (tapping elsewhere) shows the
/// rendered notes again. Empty notes show the field straight away. [controller] always holds the raw Markdown, which is
/// what is saved to the Sheet.
///
/// Only web and mail links open (see [safeNoteLink]), and images are not fetched: a note comes from the Sheet, so what is
/// in it is not trusted to load anything. An image shows its description instead.
class TaskNotesField extends StatefulWidget {
  const TaskNotesField({super.key, required this.controller, this.openLink = _openExternally});

  final TextEditingController controller;

  /// How a link is opened; replaced in tests.
  final LinkOpener openLink;

  @override
  State<TaskNotesField> createState() => _TaskNotesFieldState();
}

class _TaskNotesFieldState extends State<TaskNotesField> {
  final _focus = FocusNode();
  late bool _editing = widget.controller.text.trim().isEmpty;

  @override
  void initState() {
    super.initState();
    _focus.addListener(_onFocus);
  }

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  void _onFocus() {
    // Leaving the field shows the notes rendered, unless there is nothing to render.
    if (!_focus.hasFocus && _editing && widget.controller.text.trim().isNotEmpty) {
      setState(() => _editing = false);
    }
  }

  void _startEditing() {
    setState(() => _editing = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focus.requestFocus();
    });
  }

  Future<void> _open(String? href) async {
    final uri = safeNoteLink(href);
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (uri == null) {
      messenger?.showSnackBar(const SnackBar(content: Text('This link cannot be opened.')));
      return;
    }
    var opened = false;
    try {
      opened = await widget.openLink(uri);
    } catch (_) {
      opened = false;
    }
    if (!opened) messenger?.showSnackBar(const SnackBar(content: Text('Could not open the link.')));
  }

  @override
  Widget build(BuildContext context) {
    if (_editing) {
      return TextField(
        key: const Key('taskNotesField'),
        controller: widget.controller,
        focusNode: _focus,
        minLines: 6,
        maxLines: null,
        keyboardType: TextInputType.multiline,
        onTapOutside: (_) => _focus.unfocus(),
        decoration: const InputDecoration(
          hintText: 'Notes (Markdown)',
          border: InputBorder.none,
          alignLabelWithHint: true,
        ),
      );
    }
    final theme = Theme.of(context);
    return InkWell(
      key: const Key('taskNotesRendered'),
      onTap: _startEditing,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 96),
        child: Align(
          alignment: Alignment.topLeft,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: MarkdownBody(
              data: widget.controller.text,
              styleSheet: MarkdownStyleSheet.fromTheme(theme),
              onTapLink: (text, href, title) => _open(href),
              imageBuilder: (uri, title, alt) => Text(
                (alt ?? '').isEmpty ? '[image]' : '[image: $alt]',
                style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontStyle: FontStyle.italic),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
