import 'package:flutter_svg/flutter_svg.dart';
import 'package:material_ui/material_ui.dart';

import '../theme/app_theme.dart';

class NotificationsButton extends StatelessWidget {
  const NotificationsButton({super.key});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: 'Notifications',
      style: IconButton.styleFrom(
        backgroundColor: AppColors.notificationBackground,
        fixedSize: const Size.square(48),
      ),
      icon: SvgPicture.asset(
        'assets/navigation/notifications.svg',
        width: 26,
        height: 30,
        excludeFromSemantics: true,
      ),
      onPressed: () => showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Notifications'),
          content: const Text('Welcome to PromptLearn.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
          ],
        ),
      ),
    );
  }
}
