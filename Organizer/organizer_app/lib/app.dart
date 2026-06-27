import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'core/theme/app_theme.dart';
import 'injection_container.dart';
import 'presentation/blocs/agents/agents_bloc.dart';
import 'presentation/blocs/folders/folders_bloc.dart';
import 'presentation/blocs/projects/projects_bloc.dart';
import 'presentation/blocs/projects/projects_event.dart';
import 'presentation/blocs/tasks/tasks_bloc.dart';
import 'presentation/pages/home_page.dart';

class OrganizerApp extends StatelessWidget {
  const OrganizerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider<ProjectsBloc>(
          create: (_) => getIt<ProjectsBloc>()..add(const LoadProjects()),
        ),
        BlocProvider<TasksBloc>(
          create: (_) => getIt<TasksBloc>(),
        ),
        BlocProvider<AgentsBloc>(
          create: (_) => getIt<AgentsBloc>(),
        ),
        BlocProvider<FoldersBloc>(
          create: (_) => getIt<FoldersBloc>(),
        ),
      ],
      child: MaterialApp(
        title: 'Organizer',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        darkTheme: AppTheme.dark,
        themeMode: ThemeMode.system,
        home: const HomePage(),
      ),
    );
  }
}
