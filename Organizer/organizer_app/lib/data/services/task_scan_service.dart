import 'dart:io';
import 'package:path/path.dart' as p;
import '../models/project_model.dart';
import '../models/scanned_task.dart';
import '../../core/constants/app_constants.dart';

// Scans a project directory for .md/.txt files that contain task definitions
// written by agents outside the standard tasks/ folder structure.
//
// Supported formats:
//   1. YAML frontmatter with a `title:` key (highest confidence)
//   2. Markdown heading `# Task: <title>` or `## Task: <title>`
//   3. Plain-text first line starting with `TASK:` (for .txt files)
//   4. Any markdown `#` or `##` heading (fallback — uses heading as title)
//   5. No heading — uses the filename (without extension) as the title
class TaskScanService {
  static const _maxFileSizeBytes = 200 * 1024;

  static const _ignoredFilenames = {
    'readme.md',
    'changelog.md',
    'license.md',
    'contributing.md',
    'context.md',
    'todo.md',
  };

  Future<List<ScannedTask>> scan(ProjectModel project) async {
    final projectDir = Directory(project.folderPath);
    if (!await projectDir.exists()) return [];

    final tasksPath = p.normalize(
        p.join(project.folderPath, AppConstants.tasksFolder));
    final found = <ScannedTask>[];

    await for (final entity
        in projectDir.list(recursive: true, followLinks: false)) {
      if (entity is! File) continue;
      final path = p.normalize(entity.path);

      // Skip anything inside tasks/
      if (p.isWithin(tasksPath, path)) continue;

      // Skip hidden directories (e.g. .git, .claude)
      final segments = p.split(p.relative(path, from: project.folderPath));
      if (segments.any((s) => s.startsWith('.'))) continue;

      final ext = p.extension(path).toLowerCase();
      if (ext != '.md' && ext != '.txt') continue;

      final filename = p.basename(path).toLowerCase();
      if (_ignoredFilenames.contains(filename)) continue;

      try {
        final stat = await entity.stat();
        if (stat.size > _maxFileSizeBytes) continue;

        final content = await entity.readAsString();
        final task = _parse(content, path);
        if (task != null) found.add(task);
      } catch (_) {
        // skip unreadable files
      }
    }

    return found;
  }

  ScannedTask? _parse(String content, String filePath) {
    final trimmed = content.trim();
    if (trimmed.isEmpty) return null;

    // 1. YAML frontmatter
    if (trimmed.startsWith('---')) {
      final task = _parseFrontmatter(trimmed, filePath);
      if (task != null) return task;
    }

    // 2. Markdown # Task: / ## Task:
    final lines = trimmed.split('\n');
    final firstLine = lines.first.trim();
    final taskHeadingMatch =
        RegExp(r'^#{1,2}\s*[Tt]ask:\s*(.+)$').firstMatch(firstLine);
    if (taskHeadingMatch != null) {
      final title = taskHeadingMatch.group(1)!.trim();
      if (title.isNotEmpty) {
        return ScannedTask(
          title: title,
          instructions: lines.skip(1).join('\n').trim(),
          sourcePath: filePath,
        );
      }
    }

    // 3. Plain-text TASK: marker (.txt files only)
    if (p.extension(filePath).toLowerCase() == '.txt') {
      final plainMatch =
          RegExp(r'^[Tt][Aa][Ss][Kk]:\s*(.+)$').firstMatch(firstLine);
      if (plainMatch != null) {
        final title = plainMatch.group(1)!.trim();
        if (title.isNotEmpty) {
          return ScannedTask(
            title: title,
            instructions: lines.skip(1).join('\n').trim(),
            sourcePath: filePath,
          );
        }
      }
    }

    // 4. Any markdown # or ## heading (fallback for .md files)
    if (p.extension(filePath).toLowerCase() == '.md') {
      final headingMatch =
          RegExp(r'^#{1,2}\s+(.+)$').firstMatch(firstLine);
      if (headingMatch != null) {
        final title = headingMatch.group(1)!.trim();
        if (title.isNotEmpty) {
          return ScannedTask(
            title: title,
            instructions: lines.skip(1).join('\n').trim(),
            sourcePath: filePath,
          );
        }
      }

      // 5. No heading — use the filename as title
      final filename = p.basenameWithoutExtension(filePath);
      return ScannedTask(
        title: filename,
        instructions: trimmed,
        sourcePath: filePath,
      );
    }

    return null;
  }

  ScannedTask? _parseFrontmatter(String content, String filePath) {
    // Expect content to start with ---\n
    final rest = content.substring(3);
    final closeIdx = rest.indexOf('\n---');
    if (closeIdx == -1) return null;

    final frontmatter = rest.substring(0, closeIdx);
    final body = rest.substring(closeIdx + 4).trim();

    String? title;
    String? instructions;
    bool collectingInstructions = false;
    final instructionLines = <String>[];

    for (final line in frontmatter.split('\n')) {
      if (collectingInstructions) {
        // Block scalar lines must be indented
        if (line.startsWith('  ') || line.startsWith('\t')) {
          instructionLines.add(line.trimLeft());
          continue;
        } else {
          collectingInstructions = false;
        }
      }

      final colonIdx = line.indexOf(':');
      if (colonIdx == -1) continue;
      final key = line.substring(0, colonIdx).trim().toLowerCase();
      final value = line.substring(colonIdx + 1).trim();

      switch (key) {
        case 'title':
          if (value.isNotEmpty) title = value;
        case 'instructions':
          if (value == '|' || value.isEmpty) {
            collectingInstructions = true;
          } else {
            instructions = value;
          }
      }
    }

    if (collectingInstructions && instructionLines.isNotEmpty) {
      instructions = instructionLines.join('\n');
    }

    if (title == null || title.isEmpty) return null;

    return ScannedTask(
      title: title,
      instructions: instructions?.isNotEmpty == true ? instructions! : body,
      sourcePath: filePath,
    );
  }
}
