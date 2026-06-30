import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'core/constants/colors.dart';
import 'core/services/auth_service.dart';
import 'core/services/theme_service.dart';
import 'models/user_profile.dart';
import 'screens/splash/splash_screen.dart';
import 'screens/onboarding/onboarding_screen.dart';
import 'screens/onboarding/onboarding_questions_screen.dart';
import 'screens/home/home_screen.dart';
import 'screens/reader/reader_screen.dart';
import 'screens/study/ai_study_screen.dart';
import 'screens/groups/groups_screen.dart';
import 'screens/notes/notes_screen.dart';
import 'screens/profile/profile_screen.dart';
import 'screens/plans/reading_plans_screen.dart';

// ── Providers ──────────────────────────────────────────────────────────────────

final authStreamProvider = StreamProvider<User?>((ref) {
  return FirebaseAuth.instance.authStateChanges();
});

// Listens to ThemeService ChangeNotifier so the app re-renders on theme switch
final themeModeProvider = ChangeNotifierProvider<ThemeService>((_) => ThemeService());

// ── Notification deep-link support ────────────────────────────────────────────

final pendingNotificationRoute = ValueNotifier<String?>(null);

// ── Router ────────────────────────────────────────────────────────────────────

final routerProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authStreamProvider);
  final authNotifier = _AuthNotifier(FirebaseAuth.instance.authStateChanges());
  ref.onDispose(authNotifier.dispose);

  return GoRouter(
    initialLocation: '/home',
    refreshListenable: Listenable.merge([authNotifier, pendingNotificationRoute]),
    redirect: (context, state) {
      final isAuthenticated = authState.valueOrNull != null;
      final isLoading = authState.isLoading;

      if (isLoading) return null;

      // Allow /onboarding-questions to pass through without redirect
      if (state.matchedLocation == '/onboarding-questions') {
        if (!isAuthenticated) return '/onboarding';
        return null;
      }

      if (!isAuthenticated && state.matchedLocation != '/onboarding') {
        return '/onboarding';
      }
      if (isAuthenticated && state.matchedLocation == '/onboarding') {
        return '/home';
      }

      // Notification deep link
      final pending = pendingNotificationRoute.value;
      if (pending != null && isAuthenticated) {
        pendingNotificationRoute.value = null;
        return pending;
      }

      return null;
    },
    routes: [
      GoRoute(
        path: '/onboarding',
        builder: (_, __) => const OnboardingScreen(),
      ),
      GoRoute(
        path: '/onboarding-questions',
        builder: (_, __) => const OnboardingQuestionsScreen(),
      ),
      ShellRoute(
        builder: (context, state, child) => AppShell(child: child),
        routes: [
          GoRoute(
            path: '/home',
            builder: (_, __) => const HomeScreen(),
          ),
          GoRoute(
            path: '/reader',
            builder: (context, state) {
              final extra = state.extra as Map<String, dynamic>?;
              return _ReaderWrapper(
                book: extra?['book'] as String?,
                chapter: extra?['chapter'] as int?,
                startVerse: extra?['startVerse'] as int?,
                version: extra?['version'] as String?,
              );
            },
          ),
          GoRoute(
            path: '/study',
            builder: (context, state) {
              final extra = state.extra as Map<String, dynamic>?;
              return AiStudyScreen(
                initialBook:    extra?['book']    as String?,
                initialChapter: extra?['chapter'] as int?,
              );
            },
          ),
          GoRoute(
            path: '/groups',
            builder: (_, __) => const GroupsScreen(),
          ),
          GoRoute(
            path: '/notes',
            builder: (_, __) => const NotesScreen(),
          ),
          GoRoute(
            path: '/plans',
            builder: (_, __) => const ReadingPlansScreen(),
          ),
          GoRoute(
            path: '/profile',
            builder: (_, __) => const ProfileScreen(),
          ),
        ],
      ),
    ],
  );
});

// ── App ───────────────────────────────────────────────────────────────────────

class DigDeeperApp extends ConsumerStatefulWidget {
  const DigDeeperApp({super.key});

  @override
  ConsumerState<DigDeeperApp> createState() => _DigDeeperAppState();
}

class _DigDeeperAppState extends ConsumerState<DigDeeperApp>
    with SingleTickerProviderStateMixin {
  late final AnimationController _splashCtrl;
  late final Animation<double> _splashOpacity;
  bool _splashVisible = true;
  bool _fadeStarted = false;

  @override
  void initState() {
    super.initState();
    _splashCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _splashOpacity = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(parent: _splashCtrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _splashCtrl.dispose();
    super.dispose();
  }

  void _startFadeIfNeeded(bool authResolved) {
    if (!authResolved || _fadeStarted) return;
    _fadeStarted = true;
    // Small delay so the first frame of the real app renders before we fade
    Future.delayed(const Duration(milliseconds: 100), () {
      if (!mounted) return;
      _splashCtrl.forward().then((_) {
        if (mounted) setState(() => _splashVisible = false);
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authStreamProvider);
    final router    = ref.watch(routerProvider);
    final themeMode = ref.watch(themeModeProvider).mode;

    _startFadeIfNeeded(!authState.isLoading);

    return MaterialApp.router(
      title: 'Dig Deeper',
      theme: _lightTheme,
      darkTheme: _darkTheme,
      themeMode: themeMode,
      routerConfig: router,
      debugShowCheckedModeBanner: false,
      builder: (context, child) => GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        behavior: HitTestBehavior.opaque,
        child: Stack(
          children: [
            child!,
            if (_splashVisible)
              FadeTransition(
                opacity: _splashOpacity,
                child: const SplashScreen(),
              ),
          ],
        ),
      ),
    );
  }
}

// ── Themes ────────────────────────────────────────────────────────────────────

final _darkTheme = ThemeData(
  brightness: Brightness.dark,
  scaffoldBackgroundColor: AppColors.black,
  colorScheme: const ColorScheme.dark(
    primary: AppColors.gold,
    secondary: AppColors.gold,
    surface: AppColors.cardDark,
    error: AppColors.error,
  ),
  bottomNavigationBarTheme: const BottomNavigationBarThemeData(
    backgroundColor: AppColors.black,
    selectedItemColor: AppColors.gold,
    unselectedItemColor: AppColors.textMuted,
    type: BottomNavigationBarType.fixed,
    elevation: 0,
  ),
  dividerColor: AppColors.border,
  dialogTheme: const DialogThemeData(
    backgroundColor: AppColors.cardDark,
  ),
);

// Warm parchment light theme
const _lightBg       = Color(0xFFF5EFE6);
const _lightCard      = Color(0xFFFFFFFF);
const _lightCardMid   = Color(0xFFF0E8D8);
const _lightBorder    = Color(0xFFD4C5A9);
const _lightText      = Color(0xFF1C1008);
const _lightTextMuted = Color(0xFF6B6355);

final _lightTheme = ThemeData(
  brightness: Brightness.light,
  scaffoldBackgroundColor: _lightBg,
  colorScheme: const ColorScheme.light(
    primary: AppColors.gold,
    secondary: AppColors.gold,
    surface: _lightCard,
    error: AppColors.error,
    onSurface: _lightText,
    onPrimary: Colors.white,
  ),
  bottomNavigationBarTheme: const BottomNavigationBarThemeData(
    backgroundColor: _lightCard,
    selectedItemColor: AppColors.gold,
    unselectedItemColor: _lightTextMuted,
    type: BottomNavigationBarType.fixed,
    elevation: 0,
  ),
  dividerColor: _lightBorder,
  dialogTheme: const DialogThemeData(
    backgroundColor: _lightCard,
  ),
  cardColor: _lightCard,
  inputDecorationTheme: const InputDecorationTheme(
    fillColor: _lightCardMid,
  ),
  textTheme: const TextTheme(
    bodyMedium: TextStyle(color: _lightText),
    bodyLarge:  TextStyle(color: _lightText),
  ),
);

// ── App Shell (Bottom Nav) ────────────────────────────────────────────────────

class AppShell extends StatelessWidget {
  final Widget child;
  const AppShell({super.key, required this.child});

  static const _tabs = [
    (path: '/home',    label: 'Home',   icon: Icons.home_outlined),
    (path: '/reader',  label: 'Bible',  icon: Icons.menu_book_outlined),
    (path: '/study',   label: 'Study',  icon: Icons.psychology_outlined),
    (path: '/notes',   label: 'Notes',  icon: Icons.edit_note_outlined),
    (path: '/groups',  label: 'Groups', icon: Icons.group_outlined),
  ];

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).matchedLocation;
    final currentIndex = _tabs.indexWhere((t) => location.startsWith(t.path));

    return Scaffold(
      body: child,
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: currentIndex < 0 ? 0 : currentIndex,
        onTap: (i) => context.go(_tabs[i].path),
        items: _tabs
            .map((t) => BottomNavigationBarItem(
                  icon: Icon(t.icon),
                  label: t.label,
                ))
            .toList(),
      ),
    );
  }
}

// ── Reader Wrapper — restores last reading position ───────────────────────────

class _ReaderWrapper extends StatefulWidget {
  final String? book;
  final int? chapter;
  final int? startVerse;
  final String? version;

  const _ReaderWrapper({this.book, this.chapter, this.startVerse, this.version});

  @override
  State<_ReaderWrapper> createState() => _ReaderWrapperState();
}

class _ReaderWrapperState extends State<_ReaderWrapper> {
  String? _book;
  int? _chapter;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    if (widget.book != null) {
      _book = widget.book;
      _chapter = widget.chapter;
      _loaded = true;
    } else {
      _restorePosition();
    }
  }

  Future<void> _restorePosition() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _book = prefs.getString('reader_last_book') ?? 'jhn';
      _chapter = prefs.getInt('reader_last_chapter') ?? 3;
      _loaded = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded) {
      return const Scaffold(
        backgroundColor: AppColors.deepSlate,
        body: Center(child: CircularProgressIndicator()),
      );
    }
    return ReaderScreen(
      initialBook: _book,
      initialChapter: _chapter,
    );
  }
}

// ── Auth Notifier ─────────────────────────────────────────────────────────────

class _AuthNotifier extends ChangeNotifier {
  late final StreamSubscription<dynamic> _sub;
  _AuthNotifier(Stream<dynamic> stream) {
    _sub = stream.listen((_) => notifyListeners());
  }
  @override
  void dispose() {
    _sub.cancel();
    super.dispose();
  }
}
