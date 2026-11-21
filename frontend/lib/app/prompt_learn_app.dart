import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../data/repositories/local_assessment_draft_repository.dart';
import '../data/repositories/mock_homework_checker.dart';
import '../data/services/android_class_recording_service.dart';
import '../domain/models/user_role.dart';
import '../domain/repositories/assessment_draft_repository.dart';
import '../domain/repositories/assessment_rubric_generator.dart';
import '../domain/repositories/assistant_repository.dart';
import '../domain/repositories/course_syllabus_repository.dart';
import '../domain/repositories/homework_checker.dart';
import '../domain/repositories/role_repository.dart';
import '../domain/services/class_recording_service.dart';
import '../ui/core/layout/app_navigation.dart';
import '../ui/core/layout/app_page_layout.dart';
import '../ui/core/theme/app_theme.dart';
import '../ui/features/assessment/view_models/assessment_draft_controller.dart';
import '../ui/features/assessment/view_models/assessment_rubric_controller.dart';
import '../ui/features/assessment/views/student_homework_view.dart';
import '../ui/features/assessment/views/teacher_assessment_builder_view.dart';
import '../ui/features/assessment/views/teacher_scoring_rubric_view.dart';
import '../ui/features/assessment/widgets/homework_notebook.dart';
import '../ui/features/assistant/views/assistant_overlay.dart';
import '../ui/features/auth/views/role_selection_view.dart';
import '../ui/features/classroom/models/teacher_class_preview.dart';
import '../ui/features/classroom/views/teacher_class_setup_view.dart';
import '../ui/features/home/views/student_home_view.dart';
import '../ui/features/home/views/teacher_home_view.dart';
import '../ui/features/profile/views/syllabus_integration_dialog.dart';
import '../ui/features/replay/replay_view_stub.dart'
    if (dart.library.js_interop) '../ui/features/replay/replay_view_web.dart';
import 'http_inspector.dart';

class PromptLearnApp extends StatefulWidget {
  const PromptLearnApp({
    super.key,
    required this.roleRepository,
    this.homeworkChecker = const MockHomeworkChecker(),
    this.classRecording = const AndroidClassRecordingService(),
    this.assessmentDraftRepository = const LocalAssessmentDraftRepository(),
    this.assessmentRubricGenerator,
    this.syllabusRepository,
    this.assistantRepository,
  });

  final RoleRepository roleRepository;
  final HomeworkChecker homeworkChecker;
  final ClassRecordingService classRecording;
  final AssessmentDraftRepository assessmentDraftRepository;
  final AssessmentRubricGenerator? assessmentRubricGenerator;
  final CourseSyllabusRepository? syllabusRepository;

  final AssistantRepository? assistantRepository;

  @override
  State<PromptLearnApp> createState() => _PromptLearnAppState();
}

class _PromptLearnAppState extends State<PromptLearnApp> {
  final _role = ValueNotifier<UserRole?>(null);

  @override
  void dispose() {
    _role.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PromptLearn',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      navigatorKey: HttpInspector.navigatorKey,
      navigatorObservers: HttpInspector.navigatorObservers,
      localizationsDelegates: HttpInspector.localizationsDelegates,
      builder: (context, navigator) => Overlay.wrap(
        child: Stack(
          fit: StackFit.expand,
          children: [
            navigator!,
            ValueListenableBuilder<UserRole?>(
              valueListenable: _role,
              builder: (context, role, _) {
                if (role == null) return const SizedBox.shrink();
                return AssistantOverlay(
                  key: ValueKey(role),
                  role: role,
                  repository: widget.assistantRepository,
                );
              },
            ),
          ],
        ),
      ),
      home: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.light,
        child: _RoleGate(
          repository: widget.roleRepository,
          onRoleChanged: (role) => _role.value = role,
          homeworkChecker: widget.homeworkChecker,
          classRecording: widget.classRecording,
          assessmentDraftRepository: widget.assessmentDraftRepository,
          assessmentRubricGenerator: widget.assessmentRubricGenerator,
          syllabusRepository: widget.syllabusRepository,
        ),
      ),
    );
  }
}

class _RoleGate extends StatefulWidget {
  const _RoleGate({
    required this.repository,
    required this.onRoleChanged,
    required this.homeworkChecker,
    required this.classRecording,
    required this.assessmentDraftRepository,
    required this.assessmentRubricGenerator,
    required this.syllabusRepository,
  });

  final RoleRepository repository;
  final ValueChanged<UserRole?> onRoleChanged;
  final HomeworkChecker homeworkChecker;
  final ClassRecordingService classRecording;
  final AssessmentDraftRepository assessmentDraftRepository;
  final AssessmentRubricGenerator? assessmentRubricGenerator;
  final CourseSyllabusRepository? syllabusRepository;

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
    widget.onRoleChanged(role);
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
      if (mounted) {
        setState(() => _role = role);
        widget.onRoleChanged(role);
      }
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

    return _PromptLearnShell(
      role: role,
      homeworkChecker: widget.homeworkChecker,
      classRecording: widget.classRecording,
      assessmentDraftRepository: widget.assessmentDraftRepository,
      assessmentRubricGenerator: widget.assessmentRubricGenerator,
      syllabusRepository: widget.syllabusRepository,
      onSwitchRole: () => _changeRole(null),
    );
  }
}

class _PromptLearnShell extends StatefulWidget {
  const _PromptLearnShell({
    required this.role,
    required this.homeworkChecker,
    required this.classRecording,
    required this.assessmentDraftRepository,
    required this.assessmentRubricGenerator,
    required this.syllabusRepository,
    required this.onSwitchRole,
  });

  final UserRole role;
  final HomeworkChecker homeworkChecker;
  final ClassRecordingService classRecording;
  final AssessmentDraftRepository assessmentDraftRepository;
  final AssessmentRubricGenerator? assessmentRubricGenerator;
  final CourseSyllabusRepository? syllabusRepository;
  final VoidCallback onSwitchRole;

  @override
  State<_PromptLearnShell> createState() => _PromptLearnShellState();
}

enum _HomeDetail { homework, classSetup, assessment, rubric }

class _PromptLearnShellState extends State<_PromptLearnShell> {
  var _destination = AppDestination.home;
  _HomeDetail? _homeDetail;
  AssessmentDraftController? _assessment;
  AssessmentRubricController? _rubrics;
  bool _classLocked = false;
  final _pageKey = GlobalKey();
  late final _homeworkNotebook = HomeworkNotebook();

  @override
  void initState() {
    super.initState();
    if (widget.role == UserRole.teacher && widget.classRecording.isSupported) {
      _restoreActiveClass();
    }
  }

  @override
  void dispose() {
    _rubrics?.dispose();
    _assessment?.dispose();
    super.dispose();
  }

  Future<void> _restoreActiveClass() async {
    try {
      final recording = await widget.classRecording.status();
      if (!mounted || !recording.inProgress) return;
      setState(() {
        _destination = AppDestination.home;
        _homeDetail = _HomeDetail.classSetup;
      });
    } on PlatformException {
      // Stay on Home when the recording service is unavailable.
    } on MissingPluginException {
      // Leave Home usable on platforms that do not register Android capture.
    }
  }

  bool _canLeaveClass() {
    if (!_classLocked) return true;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('End the class before leaving this page.')),
    );
    return false;
  }

  void _switchRole() {
    if (_canLeaveClass()) widget.onSwitchRole();
  }

  void _selectDestination(AppDestination destination) {
    if (!_canLeaveClass()) return;
    setState(() {
      _destination = destination;
      _homeDetail = null;
    });
  }

  void _openHomeDetail(_HomeDetail detail) {
    if (detail == _HomeDetail.assessment) {
      _assessment ??= AssessmentDraftController(
        widget.assessmentDraftRepository,
      );
    }
    setState(() => _homeDetail = detail);
  }

  void _openRubric() {
    final rubrics = _rubrics ??= AssessmentRubricController(
      draft: _assessment!,
      generator: widget.assessmentRubricGenerator,
      lessonTitle: TeacherClassPreview.lessonTitle,
      lessonSteps: [
        for (final step in TeacherClassPreview.steps) step.instructions,
      ],
    );
    rubrics.prepareMissing();
    _openHomeDetail(_HomeDetail.rubric);
  }

  void _backToQuestions() => _openHomeDetail(_HomeDetail.assessment);

  void _closeHomeDetail() => _selectDestination(AppDestination.home);

  Widget _buildHome() {
    const displayName = 'Alexander P.';
    final now = DateTime.now();

    return switch (widget.role) {
      UserRole.teacher => TeacherHomeView(
        displayName: displayName,
        now: now,
        onStartClass: () => _openHomeDetail(_HomeDetail.classSetup),
        onOpenAssessment: () => _openHomeDetail(_HomeDetail.assessment),
        reviewNavigation: AppNavigation(
          destination: AppDestination.courses,
          vertical: true,
          reviewStyle: true,
          onSelected: (destination) {
            if (destination == AppDestination.courses) return;
            Navigator.of(context).popUntil((route) => route.isFirst);
            _selectDestination(destination);
          },
          onSwitchRole: () {
            Navigator.of(context).popUntil((route) => route.isFirst);
            widget.onSwitchRole();
          },
        ),
      ),
      UserRole.student => StudentHomeView(
        displayName: displayName,
        now: now,
        onOpenHomework: () => _openHomeDetail(_HomeDetail.homework),
      ),
    };
  }

  Widget _buildPage(BuildContext context, {required bool wide}) {
    if (_destination == AppDestination.home) {
      final home = _buildHome();
      final detail = _homeDetail;

      return PopScope(
        canPop: detail == null,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop && _homeDetail != null && !_classLocked) {
            if (_homeDetail == _HomeDetail.rubric) {
              _backToQuestions();
            } else {
              _closeHomeDetail();
            }
          }
        },
        child: IndexedStack(
          index: detail == null ? 0 : 1,
          sizing: StackFit.expand,
          children: [
            ExcludeFocus(excluding: detail != null, child: home),
            if (detail != null)
              switch (detail) {
                _HomeDetail.classSetup => TeacherClassSetupView(
                  onBack: _closeHomeDetail,
                  recordingService: widget.classRecording,
                  onNavigationLockChanged: (locked) => _classLocked = locked,
                ),
                _HomeDetail.assessment => TeacherAssessmentBuilderView(
                  controller: _assessment!,
                  onBack: _closeHomeDetail,
                  onNext: _openRubric,
                ),
                _HomeDetail.rubric => TeacherScoringRubricView(
                  controller: _rubrics!,
                  onBack: _backToQuestions,
                ),
                _HomeDetail.homework => StudentHomeworkView(
                  notebook: _homeworkNotebook,
                  checker: widget.homeworkChecker,
                  onBack: _closeHomeDetail,
                ),
              },
          ],
        ),
      );
    }

    if (kIsWeb && _destination == AppDestination.courses) {
      return SingleChildScrollView(child: ReplayView(role: widget.role));
    }

    final showSyllabusTest =
        _destination == AppDestination.profile &&
        widget.role == UserRole.teacher;
    return AppPageLayout(
      header: ColoredBox(
        color: AppColors.header,
        child: Padding(
          padding: EdgeInsets.all(wide ? 42 : 20),
          child: Text(
            _destination.label,
            style: Theme.of(context).textTheme.titleLarge,
          ),
        ),
      ),
      body: showSyllabusTest
          ? Padding(
              padding: const EdgeInsets.all(24),
              child: Align(
                alignment: AlignmentDirectional.centerStart,
                child: FilledButton.icon(
                  onPressed: () => showDialog<void>(
                    context: context,
                    builder: (context) => SyllabusIntegrationDialog(
                      repository: widget.syllabusRepository,
                    ),
                  ),
                  icon: const Icon(Icons.menu_book_outlined),
                  label: const Text('Test syllabus integration'),
                ),
              ),
            )
          : null,
    );
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
              destination:
                  _homeDetail != null && widget.role == UserRole.teacher
                  ? AppDestination.courses
                  : _destination,
              vertical: useSidebar,
              onSwitchRole: _switchRole,
              onSelected: _selectDestination,
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
                      key: _pageKey,
                      child: _buildPage(context, wide: wide),
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
