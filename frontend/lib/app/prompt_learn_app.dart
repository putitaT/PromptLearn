import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../domain/models/user_role.dart';
import 'http_inspector.dart';
import '../domain/repositories/role_repository.dart';
import '../ui/core/layout/app_navigation.dart';
import '../ui/core/theme/app_theme.dart';
import '../ui/features/auth/views/role_selection_view.dart';
import '../ui/features/home/views/student_home_view.dart';
import '../ui/features/home/views/teacher_home_view.dart';
import '../ui/features/replay/replay_view_stub.dart'
    if (dart.library.js_interop) '../ui/features/replay/replay_view_web.dart';

class PromptLearnApp extends StatelessWidget {
  const PromptLearnApp({super.key, required this.roleRepository});

  final RoleRepository roleRepository;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PromptLearn',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      navigatorKey: HttpInspector.navigatorKey,
      navigatorObservers: HttpInspector.navigatorObservers,
      localizationsDelegates: HttpInspector.localizationsDelegates,
      home: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.light,
        child: _RoleGate(repository: roleRepository),
      ),
    );
  }
}

class _RoleGate extends StatefulWidget {
  const _RoleGate({required this.repository});

  final RoleRepository repository;

  @override
  State<_RoleGate> createState() => _RoleGateState();
}

class _RoleGateState extends State<_RoleGate> {
  UserRole? _role;
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _restoreRole();
  }

  Future<void> _restoreRole() async {
    UserRole? role;
    try {
      role = await widget.repository.load();
    } on PlatformException {
      // Open the login screen when the saved role cannot be read.
    }
    if (!mounted) return;
    setState(() {
      _role = role;
      _loading = false;
    });
  }

  Future<void> _changeRole(UserRole? role) async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      if (role == null) {
        await widget.repository.clear();
      } else {
        await widget.repository.save(role);
      }
      if (mounted) setState(() => _role = role);
    } on PlatformException {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not change roles. Try again.')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        backgroundColor: AppColors.ink,
        body: Center(child: CircularProgressIndicator(color: AppColors.accent)),
      );
    }

    final role = _role;
    if (role == null) {
      return RoleSelectionView(onSelect: _changeRole, isSaving: _saving);
    }

    return _PromptLearnShell(role: role, onSwitchRole: () => _changeRole(null));
  }
}

class _PromptLearnShell extends StatefulWidget {
  const _PromptLearnShell({required this.role, required this.onSwitchRole});

  final UserRole role;
  final VoidCallback onSwitchRole;

  @override
  State<_PromptLearnShell> createState() => _PromptLearnShellState();
}

class _PromptLearnShellState extends State<_PromptLearnShell> {
  var _destination = AppDestination.home;

  Widget _buildHome() {
    const displayName = 'Alexander P.';
    final now = DateTime.now();

    return switch (widget.role) {
      UserRole.teacher => TeacherHomeView(
        displayName: displayName,
        now: now,
        reviewNavigation: AppNavigation(
          destination: AppDestination.courses,
          vertical: true,
          reviewStyle: true,
          onSelected: (destination) {
            if (destination == AppDestination.courses) return;
            Navigator.of(context).popUntil((route) => route.isFirst);
            setState(() => _destination = destination);
          },
          onSwitchRole: () {
            Navigator.of(context).popUntil((route) => route.isFirst);
            widget.onSwitchRole();
          },
        ),
      ),
      UserRole.student => SingleChildScrollView(
        child: StudentHomeView(displayName: displayName, now: now),
      ),
    };
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.ink,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final useSidebar =
                constraints.maxWidth >= 600 && constraints.maxHeight >= 480;
            final wide = constraints.maxWidth >= 1000;
            final navigation = AppNavigation(
              destination: _destination,
              vertical: useSidebar,
              onSwitchRole: widget.onSwitchRole,
              onSelected: (destination) {
                setState(() => _destination = destination);
              },
            );
            final double inset = wide ? 25 : 12;
            final corners = BorderRadius.circular(wide ? 40 : 24);
            final panel = Padding(
              padding: EdgeInsetsDirectional.fromSTEB(
                useSidebar ? 0 : inset,
                inset,
                inset,
                useSidebar ? inset : 0,
              ),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: corners,
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x2465776C),
                      blurRadius: 120,
                      spreadRadius: -25,
                      offset: Offset(0, -3),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: corners,
                  child: ColoredBox(
                    color: AppColors.canvas,
                    child: SizedBox.expand(
                      child: _destination == AppDestination.home
                          ? _buildHome()
                          : SingleChildScrollView(
                              child:
                                  kIsWeb &&
                                      _destination == AppDestination.courses
                                  ? ReplayView(role: widget.role)
                                  : ColoredBox(
                                      color: AppColors.header,
                                      child: Padding(
                                        padding: EdgeInsets.all(wide ? 42 : 20),
                                        child: Text(
                                          _destination.label,
                                          style: Theme.of(context)
                                              .textTheme
                                              .titleLarge,
                                        ),
                                      ),
                                    ),
                            ),
                    ),
                  ),
                ),
              ),
            );

            if (useSidebar) {
              return Row(
                children: [
                  SizedBox(width: 100, child: navigation),
                  Expanded(child: panel),
                ],
              );
            }
            return Column(
              children: [
                Expanded(child: panel),
                navigation,
              ],
            );
          },
        ),
      ),
    );
  }
}
