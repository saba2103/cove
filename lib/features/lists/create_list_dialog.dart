import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/cove_theme.dart';
import '../../core/widgets/cove_pill_button.dart';
import 'list_controller.dart';

class CreateListDialog extends ConsumerStatefulWidget {
  const CreateListDialog({super.key});

  static Future<String?> show(BuildContext context) {
    return showDialog<String>(
      context: context,
      barrierColor: Colors.black54,
      builder: (_) => const CreateListDialog(),
    );
  }

  @override
  ConsumerState<CreateListDialog> createState() => _CreateListDialogState();
}

class _CreateListDialogState extends ConsumerState<CreateListDialog> {
  final _nameController = TextEditingController();
  bool _isCreating = false;
  String? _error;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;

    setState(() {
      _isCreating = true;
      _error = null;
    });

    try {
      final controller = ref.read(listControllerProvider);
      final id = await controller.createList(name: name);
      if (mounted) {
        Navigator.of(context).pop(id);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isCreating = false;
          _error = e.toString().replaceFirst('Bad state: ', '').replaceFirst('Exception: ', '');
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;

    return Dialog(
      backgroundColor: colors.surfaceCard,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: colors.borderHairline, width: 1),
      ),
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'NEW SHARED LIST',
              style: typography.caption.copyWith(
                letterSpacing: 1.1,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Create a collection',
              style: typography.headline.copyWith(fontSize: 20),
            ),
            const SizedBox(height: 16),
            Container(
              decoration: BoxDecoration(
                color: colors.surfaceRow,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: colors.borderHairline, width: 1),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
              child: TextField(
                controller: _nameController,
                autofocus: true,
                textInputAction: TextInputAction.done,
                textCapitalization: TextCapitalization.sentences,
                style: TextStyle(
                  fontFamily: 'GeneralSans',
                  fontSize: 15,
                  color: colors.textPrimary,
                ),
                decoration: InputDecoration(
                  hintText: 'e.g. Weekend Hardware, Book Wishlist…',
                  hintStyle: TextStyle(
                    fontFamily: 'GeneralSans',
                    fontSize: 14,
                    color: colors.textSubtle,
                  ),
                  border: InputBorder.none,
                ),
                onSubmitted: (_) => _submit(),
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 10),
              Text(
                _error!,
                style: typography.caption.copyWith(color: colors.accentSecondary),
              ),
            ],
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: _isCreating ? null : () => Navigator.of(context).pop(),
                  child: Text(
                    'Cancel',
                    style: TextStyle(
                      fontFamily: 'GeneralSans',
                      color: colors.textMuted,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                CovePillButton(
                  label: _isCreating ? 'Creating…' : 'Create List',
                  isCompact: true,
                  onPressed: _isCreating ? null : _submit,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
