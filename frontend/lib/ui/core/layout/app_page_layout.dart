import 'package:flutter/widgets.dart';

/// Holds the page header above the independently scrolling body.
class AppPageLayout extends StatelessWidget {
  const AppPageLayout({super.key, required this.header, this.body});

  final Widget header;
  final Widget? body;

  @override
  Widget build(BuildContext context) {
    final content = body;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        header,
        if (content != null)
          Expanded(
            child: SingleChildScrollView(primary: false, child: content),
          ),
      ],
    );
  }
}
