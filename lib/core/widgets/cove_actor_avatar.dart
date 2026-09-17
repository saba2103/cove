import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../features/activity/activity_models.dart';
import '../../features/profile/partner_profile_controller.dart';
import '../../features/profile/user_profile_controller.dart';
import '../theme/cove_theme.dart';

/// Renders the profile avatar of the actor (local user or partner) who performed an activity.
/// Displays their profile photo if set, or their initial letter styled in bold headline serif
/// against the luxury accent color. Optionally renders a bottom-right action badge and top-right unread dot.
class CoveActorAvatar extends ConsumerWidget {
  final FormattedActivityItem? item;
  final bool? isLocalActor;
  final String? actorName;
  final String? avatarUrl;
  final IconData? badgeIcon;
  final bool isRead;
  final bool showBadge;
  final double size;

  const CoveActorAvatar({
    super.key,
    this.item,
    this.isLocalActor,
    this.actorName,
    this.avatarUrl,
    this.badgeIcon,
    this.isRead = true,
    this.showBadge = true,
    this.size = 38,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final typography = context.typography;

    final userProfile = ref.watch(userProfileProvider);
    final partnerProfile = ref.watch(partnerProfileProvider);

    final isLocal = isLocalActor ?? item?.isLocalActor ?? false;

    final effectiveAvatarUrl = avatarUrl ??
        (isLocal
            ? userProfile.avatarUrl
            : (item?.actorAvatarUrl ?? partnerProfile.avatarUrl));

    final effectiveName = actorName ??
        (isLocal
            ? (userProfile.displayName.isNotEmpty
                ? userProfile.displayName
                : 'You')
            : (item?.actorName.isNotEmpty == true &&
                    item!.actorName != 'Partner'
                ? item!.actorName
                : (partnerProfile.displayName.isNotEmpty
                    ? partnerProfile.displayName
                    : 'Partner')));

    final trimmedName = effectiveName.trim();
    final initial = trimmedName.isNotEmpty
        ? trimmedName[0].toUpperCase()
        : (isLocal ? 'U' : 'P');

    final hasPhoto =
        effectiveAvatarUrl != null && effectiveAvatarUrl.isNotEmpty;
    final icon = badgeIcon ?? item?.icon;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        // Main Avatar Circle
        Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: isRead
                  ? colors.borderHairline
                  : colors.accentPrimary.withValues(alpha: 0.6),
              width: isRead ? 1.0 : 1.5,
            ),
          ),
          child: CircleAvatar(
            radius: size / 2,
            backgroundColor:
                hasPhoto ? colors.surfaceRow : colors.accentPrimary,
            backgroundImage: hasPhoto ? NetworkImage(effectiveAvatarUrl) : null,
            onBackgroundImageError:
                hasPhoto ? (exception, stackTrace) {} : null,
            child: hasPhoto
                ? null
                : Text(
                    initial,
                    style: typography.headline.copyWith(
                      fontSize: size * 0.44,
                      fontWeight: FontWeight.w700,
                      color: colors.surfaceRow,
                    ),
                  ),
          ),
        ),

        // Unread Indicator Dot (top-right)
        if (!isRead)
          Positioned(
            top: -1,
            right: -1,
            child: Container(
              width: 9,
              height: 9,
              decoration: BoxDecoration(
                color: colors.accentSecondary,
                shape: BoxShape.circle,
                border: Border.all(
                  color: colors.surfaceCard,
                  width: 1.5,
                ),
              ),
            ),
          ),

        // Action / Module Mini Badge (bottom-right)
        if (showBadge && icon != null)
          Positioned(
            bottom: -2,
            right: -2,
            child: Container(
              width: size <= 30 ? 14 : 17,
              height: size <= 30 ? 14 : 17,
              decoration: BoxDecoration(
                color: colors.surfaceCard,
                shape: BoxShape.circle,
                border: Border.all(
                  color: colors.background,
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.15),
                    blurRadius: 2,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
              child: Center(
                child: Icon(
                  icon,
                  size: size <= 30 ? 8 : 10,
                  color: colors.accentPrimary,
                ),
              ),
            ),
          ),
      ],
    );
  }
}
