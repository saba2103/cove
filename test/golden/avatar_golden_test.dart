import 'package:cove/core/theme/cove_tokens.dart';
import 'package:cove/core/widgets/cove_avatar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'golden_harness.dart';

class _AvatarShowcase extends StatelessWidget {
  const _AvatarShowcase();

  @override
  Widget build(BuildContext context) {
    final cv = context.cv;

    Widget buildRungCard({
      required String title,
      required String subtitle,
      required CoveAvatarRung rung,
    }) {
      return Container(
        padding: const EdgeInsets.all(CoveSpace.gutter),
        decoration: BoxDecoration(
          color: cv.surfaceCard,
          borderRadius: const BorderRadius.all(
            Radius.circular(CoveRadius.card),
          ),
          border: Border.all(color: cv.lineHairline),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: CoveType.rowTitle.copyWith(color: cv.textPrimary),
                  ),
                  const SizedBox(height: CoveSpace.xs),
                  Text(
                    subtitle,
                    style: CoveType.rowSub.copyWith(color: cv.textSecondary),
                  ),
                ],
              ),
            ),
            const SizedBox(width: CoveSpace.md),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                CoveAvatar(
                  key: ValueKey('avatar_${rung.name}_a'),
                  person: CovePerson.a,
                  rung: rung,
                  nameOrInitial: 'Saba',
                ),
                const SizedBox(width: CoveSpace.sm),
                CoveAvatar(
                  key: ValueKey('avatar_${rung.name}_b'),
                  person: CovePerson.b,
                  rung: rung,
                  nameOrInitial: 'Ancy',
                ),
                const SizedBox(width: CoveSpace.sm),
                CoveAvatar(
                  key: ValueKey('avatar_${rung.name}_both'),
                  person: CovePerson.both,
                  rung: rung,
                ),
              ],
            ),
          ],
        ),
      );
    }

    return Scaffold(
      backgroundColor: cv.surfaceCanvas,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(CoveSpace.gutter),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'COVE AVATAR',
              style: CoveType.capsPage.copyWith(color: cv.accentText),
            ),
            const SizedBox(height: CoveSpace.xs),
            Text(
              'Household Attribution',
              style: CoveType.title.copyWith(color: cv.textPrimary),
            ),
            const SizedBox(height: CoveSpace.lg),

            // 1. Inline (24dp)
            buildRungCard(
              title: 'Inline · 24dp',
              subtitle: 'Inside a sentence (A · B · Both)',
              rung: CoveAvatarRung.inline,
            ),
            const SizedBox(height: CoveSpace.md),

            // 2. Row (28dp)
            buildRungCard(
              title: 'Row · 28dp',
              subtitle: 'List row leading (A · B · Both)',
              rung: CoveAvatarRung.row,
            ),
            const SizedBox(height: CoveSpace.md),

            // 3. Header (32dp)
            buildRungCard(
              title: 'Header · 32dp',
              subtitle: 'Header or card head (A · B · Both)',
              rung: CoveAvatarRung.header,
            ),
            const SizedBox(height: CoveSpace.md),

            // 4. Profile (64dp)
            Container(
              padding: const EdgeInsets.all(CoveSpace.gutter),
              decoration: BoxDecoration(
                color: cv.surfaceCard,
                borderRadius: const BorderRadius.all(
                  Radius.circular(CoveRadius.card),
                ),
                border: Border.all(color: cv.lineHairline),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Profile · 64dp',
                    style: CoveType.rowTitle.copyWith(color: cv.textPrimary),
                  ),
                  const SizedBox(height: CoveSpace.xs),
                  Text(
                    'Profile or home page (A · B · Both unfilled ring)',
                    style: CoveType.rowSub.copyWith(color: cv.textSecondary),
                  ),
                  const SizedBox(height: CoveSpace.md),
                  const Row(
                    children: [
                      CoveAvatar.profile(
                        key: ValueKey('avatar_profile_a'),
                        person: CovePerson.a,
                        nameOrInitial: 'Saba',
                      ),
                      SizedBox(width: CoveSpace.md),
                      CoveAvatar.profile(
                        key: ValueKey('avatar_profile_b'),
                        person: CovePerson.b,
                        nameOrInitial: 'Ancy',
                      ),
                      SizedBox(width: CoveSpace.md),
                      CoveAvatar.profile(
                        key: ValueKey('avatar_profile_both'),
                        person: CovePerson.both,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

void main() {
  testWidgets(
    'CoveAvatar golden matrix (inline 24, row 28, header 32, profile 64 x A, B, Both)',
    (tester) async {
      await goldenMatrix(
        tester,
        'avatar',
        const _AvatarShowcase(),
      );

      // Verify exact diameters for all four rungs
      expect(
        tester.getSize(find.byKey(const ValueKey('avatar_inline_a'))),
        equals(const Size(CoveSize.avatarInline, CoveSize.avatarInline)),
      );
      expect(
        tester.getSize(find.byKey(const ValueKey('avatar_row_a'))),
        equals(const Size(CoveSize.avatarRow, CoveSize.avatarRow)),
      );
      expect(
        tester.getSize(find.byKey(const ValueKey('avatar_header_a'))),
        equals(const Size(CoveSize.avatarHeader, CoveSize.avatarHeader)),
      );
      expect(
        tester.getSize(find.byKey(const ValueKey('avatar_profile_a'))),
        equals(const Size(CoveSize.avatarProfile, CoveSize.avatarProfile)),
      );

      // Verify Libre Bodoni w500 at 0.44 * diameter
      final profileAText = tester.widget<Text>(
        find.descendant(
          of: find.byKey(const ValueKey('avatar_profile_a')),
          matching: find.byType(Text),
        ),
      );
      expect(profileAText.data, equals('S'));
      expect(profileAText.style?.fontFamily, equals('LibreBodoni'));
      expect(profileAText.style?.fontWeight, equals(FontWeight.w500));
      expect(
        profileAText.style?.fontSize,
        closeTo(CoveSize.avatarProfile * 0.44, 1e-6),
      );

      // Verify Both renders '&' and uses an unfilled CustomPaint ring (no DecoratedBox fill)
      final profileBothFinder = find.byKey(const ValueKey('avatar_profile_both'));
      final profileBothText = tester.widget<Text>(
        find.descendant(
          of: profileBothFinder,
          matching: find.byType(Text),
        ),
      );
      expect(profileBothText.data, equals('&'));
      expect(
        find.descendant(of: profileBothFinder, matching: find.byType(DecoratedBox)),
        findsNothing,
      );
      expect(
        find.descendant(of: profileBothFinder, matching: find.byType(CustomPaint)),
        findsOneWidget,
      );
    },
  );

  test('CoveAvatar.resolvePerson is keyed strictly to homeCreatedBy', () {
    expect(
      CoveAvatar.resolvePerson(
        homeCreatedBy: 'user_saba',
        actorUserId: 'user_saba',
      ),
      equals(CovePerson.a),
    );
    expect(
      CoveAvatar.resolvePerson(
        homeCreatedBy: 'user_saba',
        actorUserId: 'user_ancy',
      ),
      equals(CovePerson.b),
    );
    expect(
      CoveAvatar.resolvePerson(
        homeCreatedBy: 'user_saba',
        actorUserId: 'user_saba',
        isShared: true,
      ),
      equals(CovePerson.both),
    );
  });
}
