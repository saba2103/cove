import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/shape/cove_shape.dart';
import '../../core/theme/cove_tokens.dart';
import '../../core/widgets/cove_pill_button.dart';
import 'list_controller.dart';

class CreateListDialog extends ConsumerStatefulWidget {
  const CreateListDialog({super.key});

  static Future<String?> show(BuildContext context) {
    return showDialog<String>(
      context: context,
      barrierColor: context.cv.surfaceScrim,
      builder: (_) => const CreateListDialog(),
    );
  }

  @override
  ConsumerState<CreateListDialog> createState() => _CreateListDialogState();
}

class _CreateListDialogState extends ConsumerState<CreateListDialog> {
  static const double _kBorderWidth =
      1.0; // (literal) 1dp dialog and input card hairline border width
  static const double _kTitleBottomGap =
      16.0; // (literal) 16dp vertical gap below dialog title

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
          _error = e
              .toString()
              .replaceFirst('Bad state: ', '')
              .replaceFirst('Exception: ', '');
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cv = context.cv;
    final isScaled = MediaQuery.textScalerOf(context).scale(1.0) > 1.0;

    final dialogBody = Padding(
      padding: const EdgeInsets.all(CoveSpace.gutter),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'NEW SHARED LIST',
            style: CoveType.capsCard.copyWith(color: cv.textSecondary),
          ),
          const SizedBox(height: CoveSpace.sm),
          Text(
            'Create a collection',
            style: CoveType.slipTitle.copyWith(color: cv.textPrimary),
          ),
          const SizedBox(height: _kTitleBottomGap),
          Container(
            decoration: CoveShape.decoration(
              CoveSpace.md,
              color: cv.surfaceRow,
              side: BorderSide(
                color: cv.lineFocus,
                width: _kBorderWidth,
              ),
            ),
            padding: const EdgeInsets.symmetric(
              horizontal: CoveSpace.md,
              vertical: CoveSpace.xs,
            ),
            child: TextField(
              controller: _nameController,
              autofocus: true,
              textInputAction: TextInputAction.done,
              textCapitalization: TextCapitalization.sentences,
              cursorColor: cv.lineFocus,
              style: CoveType.body.copyWith(color: cv.textPrimary),
              decoration: InputDecoration(
                hintText: 'e.g. Weekend Hardware, Book Wishlist…',
                hintMaxLines: isScaled ? 8 : null,
                hintStyle: CoveType.readout.copyWith(
                  color: cv.textTertiary,
                ),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
              ),
              onSubmitted: (_) => _submit(),
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: CoveSpace.sm),
            Text(
              _error!,
              style: CoveType.rowSub.copyWith(color: cv.statusAlertText),
            ),
          ],
          const SizedBox(height: CoveSpace.gutter),
          if (isScaled)
            Align(
              alignment: Alignment.centerRight,
              child: Wrap(
                alignment: WrapAlignment.end,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: CoveSpace.sm,
                runSpacing: CoveSpace.sm,
                children: [
                  TextButton(
                    onPressed: _isCreating
                        ? null
                        : () => Navigator.of(context).pop(),
                    child: Text(
                      'Cancel',
                      style: CoveType.readout.copyWith(
                        color: cv.textSecondary,
                      ),
                    ),
                  ),
                  CovePillButton(
                    label: _isCreating ? 'Creating…' : 'Create List',
                    isCompact: true,
                    onPressed: _isCreating ? null : _submit,
                  ),
                ],
              ),
            )
          else
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: _isCreating
                      ? null
                      : () => Navigator.of(context).pop(),
                  child: Text(
                    'Cancel',
                    style: CoveType.readout.copyWith(
                      color: cv.textSecondary,
                    ),
                  ),
                ),
                const SizedBox(width: CoveSpace.sm),
                CovePillButton(
                  label: _isCreating ? 'Creating…' : 'Create List',
                  isCompact: true,
                  onPressed: _isCreating ? null : _submit,
                ),
              ],
            ),
        ],
      ),
    );

    return Dialog(
      backgroundColor: cv.surfaceCard,
      shape: CoveShape.border(
        CoveRadius.card,
        side: BorderSide(color: cv.lineHairline, width: _kBorderWidth),
      ),
      insetPadding: const EdgeInsets.symmetric(
        horizontal: CoveSpace.lg,
        vertical: CoveSpace.lg,
      ),
      child: isScaled ? SingleChildScrollView(child: dialogBody) : dialogBody,
    );
  }
}
