import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sqflite/sqflite.dart';
import '../../core/lifecycle/resource_manager.dart';
import '../../data/database/projects_database.dart';
import 'studio_dashboard_page.dart';

/// Independent application shell for AI Engineering Studio.
/// Has its own lifecycle, memory allocation, and project database.
/// Closing this application does not terminate SyncTask or affect task reminders.
class StudioApp extends StatefulWidget {
  final Database? projectsDb;

  const StudioApp({super.key, this.projectsDb});

  @override
  State<StudioApp> createState() => _StudioAppState();
}

class _StudioAppState extends State<StudioApp> {
  Database? _db;
  bool _initializing = true;

  @override
  void initState() {
    super.initState();
    _initStudio();
  }

  Future<void> _initStudio() async {
    if (widget.projectsDb != null) {
      _db = widget.projectsDb;
      setState(() => _initializing = false);
      return;
    }

    try {
      final db = await ProjectsDatabase.open();
      if (mounted) {
        setState(() {
          _db = db;
          _initializing = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _initializing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<ResourceManager>.value(
          value: ResourceManager(),
        ),
      ],
      child: MaterialApp(
        title: 'Sky Suite — AI Engineering Studio',
        debugShowCheckedModeBanner: false,
        themeMode: ThemeMode.dark,
        theme: ThemeData(
          brightness: Brightness.dark,
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF6366F1),
            brightness: Brightness.dark,
            surface: const Color(0xFF0F172A),
          ),
          scaffoldBackgroundColor: const Color(0xFF0F172A),
          useMaterial3: true,
          cardTheme: const CardThemeData(
            color: Color(0xFF1E293B),
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.all(Radius.circular(14)),
            ),
          ),
        ),
        home: _initializing
            ? const Scaffold(
                body: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(color: Color(0xFF6366F1)),
                      SizedBox(height: 16),
                      Text('Initializing AI Engineering Studio...'),
                    ],
                  ),
                ),
              )
            : StudioDashboardPage(projectsDb: _db!),
      ),
    );
  }
}
