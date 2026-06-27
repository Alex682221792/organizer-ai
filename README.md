# Organizer AI

A **Kanban task organizer** with **Claude AI agent integration** built with Flutter. Manage projects, organize tasks with AI assistance, and automate workflows using the Claude CLI.

## Features

- **📋 Project Management**: Create and manage multiple projects with custom configurations
- **🎯 Kanban Board**: Organize tasks using a visual Kanban board with task statuses
- **🤖 AI Agents**: Integrate Claude AI agents to refine, analyze, and process tasks
- **⚙️ Task Automation**: Schedule and run tasks with custom Claude CLI commands
- **📁 Folder Organization**: Organize tasks into logical folders within projects
- **🔍 Task Scanning**: Automatically detect and import tasks from your project folders
- **💬 AI Refinement**: Use Claude to refine task descriptions and improve clarity
- **📊 Task Threading**: Maintain conversation history and context for each task
- **🌓 Dark Mode**: Full dark and light theme support with system preference detection

## Requirements

- **Flutter**: 3.10.0 or higher
- **Dart**: 3.0.0 or higher
- **macOS**: For the native macOS build
- **Claude CLI**: Required for task automation features

## Installation

### 1. Clone the Repository
```bash
cd /Volumes/TOSHIBA\ EXTERNAL_USB/personal-repos/organizer-ai/Organizer/organizer_app
```

### 2. Install Dependencies
```bash
flutter pub get
```

### 3. Run the Application
```bash
flutter run -d macos
```

### 4. Build for Release (Optional)
```bash
flutter build macos --release
```

## Project Structure

```
organizer_app/
├── lib/
│   ├── main.dart                    # Application entry point
│   ├── app.dart                     # Root widget with BLoC setup
│   ├── injection_container.dart     # Dependency injection configuration
│   ├── core/
│   │   ├── constants/               # App-wide constants
│   │   └── theme/                   # Theme definitions
│   ├── data/
│   │   ├── models/                  # Data models
│   │   │   ├── project_model.dart
│   │   │   ├── task_model.dart
│   │   │   ├── folder_model.dart
│   │   │   ├── agent_model.dart
│   │   │   ├── runner_config.dart
│   │   │   └── ...
│   │   ├── repositories/            # Data access layer
│   │   │   ├── project_repository.dart
│   │   │   ├── task_repository.dart
│   │   │   ├── agent_repository.dart
│   │   │   └── ...
│   │   └── services/                # Business logic services
│   │       ├── task_runner_service.dart
│   │       ├── task_scan_service.dart
│   │       ├── refinement_service.dart
│   │       └── ...
│   └── presentation/
│       ├── blocs/                   # State management with BLoC
│       │   ├── projects/
│       │   ├── tasks/
│       │   ├── agents/
│       │   └── folders/
│       ├── pages/                   # Application pages/screens
│       │   └── home_page.dart
│       ├── panels/                  # UI panels and components
│       ├── widgets/                 # Reusable widgets
│       └── dialogs/                 # Dialog components
├── pubspec.yaml                     # Project dependencies
├── analysis_options.yaml            # Dart analysis configuration
└── ...
```

## Architecture

The project follows a **Clean Architecture** pattern with clear separation of concerns:

### Layers

1. **Presentation Layer** (`presentation/`)
   - BLoC for state management
   - Pages and UI widgets
   - Handles user interactions

2. **Data Layer** (`data/`)
   - Models: Data structures and entities
   - Repositories: Data access logic
   - Services: Business logic implementation

3. **Core Layer** (`core/`)
   - Application constants
   - Theme configuration
   - Utility functions

## Key Dependencies

- **flutter_bloc**: State management
- **get_it**: Service locator for dependency injection
- **shared_preferences**: Local storage for app settings
- **file_picker**: File selection functionality
- **uuid**: Unique identifier generation
- **intl**: Internationalization support
- **equatable**: Value equality comparison

## Usage

### Creating a Project

1. Launch the application
2. Click "New Project" or use the project creation dialog
3. Enter project details (name, description, color)
4. Select a folder location on your filesystem
5. Click "Create"

### Managing Tasks

1. Open a project
2. Create folders to organize your tasks (optional)
3. Add tasks with:
   - Title and description
   - Assigned agents
   - Folder location
4. Use the Kanban board to manage task status

### Running Tasks with Claude AI

1. Configure Claude CLI path in Settings
   - Go to Scheduler settings
   - Set the path to your Claude CLI binary
2. Select a task and click "Run"
3. Choose agents to process the task
4. View results in the observation files

### Using AI Refinement

1. Select a task
2. Click "Refine" to use Claude to improve the task description
3. Review and accept the refined version

## Configuration

### Runner Configuration

The app stores runner configuration in:
```
~/.config/organizer/runner.json
```

This includes:
- Claude CLI path
- Custom runner settings
- Automation preferences

### Project Configuration

Each project stores its metadata in:
```
<project-folder>/project.json
```

This includes:
- Project name and description
- Created/updated timestamps
- Color scheme
- Custom configuration

### Task Structure

Tasks are organized as:
```
<project-folder>/tasks/<task-id>/
├── meta.json            # Task metadata
├── task.md              # Task description/prompt
├── thread.jsonl         # Conversation history
├── obs/                 # Task observations/results
└── agent_prompts.json   # Custom agent prompts
```

## Development

### Code Style

- Follow Dart language conventions
- Use meaningful variable and function names
- Keep functions focused and testable
- Use type annotations

### State Management

The project uses **BLoC** pattern for state management:
- Each major feature has its own BLoC
- Events trigger state changes
- UI listens to state changes via BlocBuilder

### Adding New Features

1. Create models in `data/models/`
2. Create repository/service in `data/repositories/` or `data/services/`
3. Create BLoC in `presentation/blocs/`
4. Create UI components in `presentation/pages/` or `presentation/widgets/`
5. Connect with dependency injection in `injection_container.dart`

## Security

✅ **No secrets stored in codebase**
- All sensitive configuration is managed externally
- Claude CLI path is user-configurable
- No hardcoded API keys or credentials

## Troubleshooting

### Claude CLI Not Found
- Ensure Claude CLI is installed on your system
- Configure the correct path in Scheduler settings
- Verify the path is accessible and executable

### Tasks Not Running
- Check Claude CLI configuration
- Verify project folder has write permissions
- Check task.md file exists in task directory
- Review error logs in observation files

### Performance Issues
- Limit the number of open projects
- Clear cached observations periodically
- Ensure sufficient disk space for task results

## Contributing

This is a personal project. For development:

1. Make sure Flutter is properly installed
2. Run `flutter pub get` to install dependencies
3. Follow the existing code structure and patterns
4. Test changes locally before committing
5. Update this README if adding new features

## License

Private project - Not for public distribution.

## Author

Created with Flutter and Claude AI integration for intelligent task management and automation.

---

**Last Updated**: June 2026
