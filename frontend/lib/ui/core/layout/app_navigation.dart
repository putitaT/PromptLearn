import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../theme/app_theme.dart';

enum AppDestination {
  home('Home', 'home.svg', 48),
  courses('Courses', 'courses.svg', 51),
  learningTools('Learning tools', 'bulb.svg', 56),
  profile('Profile', 'profile.svg', 55);

  const AppDestination(this.label, this.asset, this.iconSize);

  final String label;
  final String asset;
  final double iconSize;
}

class AppNavigation extends StatelessWidget {
  const AppNavigation({
    super.key,
    required this.destination,
    required this.vertical,
    required this.onSelected,
    required this.onSwitchRole,
    this.reviewStyle = false,
  });

  final AppDestination destination;
  final bool vertical;
  final ValueChanged<AppDestination> onSelected;
  final VoidCallback onSwitchRole;
  final bool reviewStyle;

  @override
  Widget build(BuildContext context) {
    final logoSize = reviewStyle ? 60.0 : 48.0;
    final logo = _imageButton(
      label: 'Switch login role',
      asset: 'mark.png',
      onPressed: onSwitchRole,
      size: logoSize,
      radius: 13,
    );

    if (!vertical) {
      return Material(
        color: Colors.transparent,
        child: SizedBox(
          height: 64,
          child: Row(
            children: [
              Padding(
                padding: const EdgeInsetsDirectional.only(start: 8),
                child: logo,
              ),
              for (final item in AppDestination.values)
                Expanded(child: _destinationButton(item, compact: true)),
            ],
          ),
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        const avatarSize = 52.0;
        final inset = math.min(70.0, constraints.maxHeight * 0.068);
        final availableHeight =
            constraints.maxHeight - inset * 2 - logoSize - avatarSize;
        final preferredItemHeight = math.min(
          134.0,
          constraints.maxHeight * 0.13,
        );
        final itemHeight = math.min(
          preferredItemHeight,
          availableHeight / AppDestination.values.length,
        );

        return Material(
          color: Colors.transparent,
          child: Padding(
            padding: EdgeInsets.symmetric(vertical: inset),
            child: Column(
              children: [
                logo,
                const Spacer(),
                for (final item in AppDestination.values)
                  SizedBox(
                    height: itemHeight,
                    child: _destinationButton(item, compact: false),
                  ),
                const Spacer(),
                _imageButton(
                  label: 'Open profile',
                  asset: 'avatar.jpg',
                  onPressed: () => onSelected(AppDestination.profile),
                  size: avatarSize,
                  radius: avatarSize / 2,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _destinationButton(AppDestination item, {required bool compact}) {
    final selected = item == destination;
    const indicatorRadius = Radius.circular(14);
    return Semantics(
      selected: selected,
      button: true,
      child: Tooltip(
        message: item.label,
        child: InkWell(
          onTap: () => onSelected(item),
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (selected && reviewStyle)
                Center(
                  child: Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      color: const Color(0x14FFFFFF),
                      borderRadius: BorderRadius.circular(18),
                    ),
                  ),
                ),
              Center(
                child: SvgPicture.asset(
                  'assets/navigation/${item.asset}',
                  width: item.iconSize * (compact ? 0.64 : 0.72),
                  colorFilter: ColorFilter.mode(
                    selected ? Colors.white : AppColors.inactiveIcon,
                    BlendMode.srcIn,
                  ),
                  excludeFromSemantics: true,
                ),
              ),
              if (selected && compact)
                const Align(
                  alignment: Alignment.bottomCenter,
                  child: SizedBox(
                    width: 36,
                    height: 4,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: AppColors.accent,
                        borderRadius: BorderRadius.vertical(
                          top: indicatorRadius,
                        ),
                      ),
                    ),
                  ),
                ),
              if (selected && !compact && !reviewStyle)
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: FractionallySizedBox(
                    heightFactor: 0.73,
                    child: const SizedBox(
                      width: 8,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: AppColors.accent,
                          borderRadius: BorderRadiusDirectional.horizontal(
                            end: indicatorRadius,
                          ),
                        ),
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

  Widget _imageButton({
    required String label,
    required String asset,
    required VoidCallback onPressed,
    required double size,
    required double radius,
  }) {
    return Tooltip(
      message: label,
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(radius),
        clipBehavior: Clip.antiAlias,
        child: Ink.image(
          image: ResizeImage(
            AssetImage('assets/navigation/$asset'),
            width: (size * 3).round(),
            allowUpscaling: false,
          ),
          fit: BoxFit.cover,
          width: size,
          height: size,
          child: InkWell(onTap: onPressed),
        ),
      ),
    );
  }
}
