import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as p;
import '../models/agent_model.dart';

class RefinementResult {
  final String taskMd;
  final List<String> agentIds;
  final Map<String, String> agentSystemPrompts;

  const RefinementResult({
    required this.taskMd,
    required this.agentIds,
    required this.agentSystemPrompts,
  });
}

class RefinementService {
  String get _runnerConfigPath => p.join(
        Platform.environment['HOME'] ?? '',
        '.config',
        'organizer',
        'runner.json',
      );

  Future<String?> _getClaudePath() async {
    try {
      final file = File(_runnerConfigPath);
      if (!await file.exists()) return null;
      final content = await file.readAsString();
      final json = jsonDecode(content) as Map<String, dynamic>;
      final path = json['claudePath'] as String?;
      return (path != null && path.isNotEmpty) ? path : null;
    } catch (_) {
      return null;
    }
  }

  Map<String, String> _envWithClaudePath(String claudePath) {
    final binDir = p.dirname(claudePath);
    final env = Map<String, String>.from(Platform.environment);
    final existing = env['PATH'] ?? '';
    env['PATH'] = existing.contains(binDir) ? existing : '$binDir:$existing';

    // The macOS app sandbox changes HOME to the container path, which breaks
    // Claude CLI's auth lookup (~/.claude/). Restore the real user HOME by
    // extracting it from the claude binary path (e.g. /Users/alex/.nvm/.../claude).
    final homeMatch = RegExp(r'^(/Users/[^/]+)').firstMatch(claudePath);
    final realHome = homeMatch?.group(1);
    if (realHome != null) env['HOME'] = realHome;

    return env;
  }

  Future<RefinementResult?> refine({
    required String title,
    required String instructions,
    required List<AgentModel> agents,
  }) async {
    final claudePath = await _getClaudePath();
    if (claudePath == null || !File(claudePath).existsSync()) return null;

    final prompt = _buildPrompt(
      title: title,
      instructions: instructions,
      agents: agents,
    );

    try {
      final result = await Process.run(
        claudePath,
        ['--print', '--dangerously-skip-permissions', '-p', prompt],
        runInShell: false,
        environment: _envWithClaudePath(claudePath),
      ).timeout(const Duration(seconds: 90));

      if (result.exitCode != 0) {
        stderr.writeln('[RefinementService.refine] exit=${result.exitCode} stderr=${result.stderr}');
        return null;
      }
      return _parseResult((result.stdout as String).trim());
    } catch (e) {
      stderr.writeln('[RefinementService.refine] exception: $e');
      return null;
    }
  }

  String _buildPrompt({
    required String title,
    required String instructions,
    required List<AgentModel> agents,
  }) {
    final agentsList = agents.isEmpty
        ? '(No hay agentes definidos para este proyecto)'
        : agents.map((a) {
            final sp = a.systemPrompt;
            return '- id: ${a.id}\n'
                '  name: ${a.name}\n'
                '  description: ${a.description}\n'
                '  model: ${a.model}\n'
                '  tools: ${a.tools.isEmpty ? "none" : a.tools.join(", ")}\n'
                '  systemPrompt: ${sp != null && sp.isNotEmpty ? sp : "(sin definir — genera uno)"}';
          }).join('\n\n');

    return '''You are a task planning assistant for an AI coding agent orchestration system.

AVAILABLE AGENTS:
$agentsList

TASK TITLE: $title

RAW TASK INSTRUCTIONS:
$instructions

Your job:
1. Rewrite the instructions as a clear, structured "task.md" document an AI agent can execute. Include a title, objective, and actionable steps.
2. Select which agent(s) from the list are best suited for this task (use their exact id). You may select one or multiple.
3. For each selected agent, generate a focused system_prompt that:
   - Defines the agent role and persona specifically for THIS task context
   - Mentions available tools when relevant
   - Sets tone and output expectations
   - If the agent already has a systemPrompt, refine it for this task context

If no agents are provided, rewrite task.md and return empty agentIds and agentSystemPrompts.

Respond ONLY with a valid JSON object — no markdown fences, no preamble, nothing else:
{
  "taskMd": "# Task Title\\n\\n...",
  "agentIds": ["id1"],
  "agentSystemPrompts": {
    "id1": "You are a..."
  }
}''';
  }

  Future<String?> generateAgentSystemPrompt({
    required String name,
    required String description,
    required String model,
    required List<String> tools,
  }) async {
    final claudePath = await _getClaudePath();
    if (claudePath == null || !File(claudePath).existsSync()) return null;

    final toolsStr = tools.isEmpty ? 'none' : tools.join(', ');
    final prompt =
        'You are an expert at writing system prompts for AI coding agents.\n\n'
        'Generate a concise, focused system prompt for an agent with these properties:\n'
        '- Name: $name\n'
        '- Description: $description\n'
        '- Model: $model\n'
        '- Available tools: $toolsStr\n\n'
        'The system prompt should:\n'
        '1. Define the agent\'s role and persona clearly\n'
        '2. Set tone and output expectations\n'
        '3. Reference the available tools when relevant\n'
        '4. Be concise (3-6 sentences)\n\n'
        'Respond ONLY with the system prompt text — no JSON, no markdown, no preamble.';

    try {
      final result = await Process.run(
        claudePath,
        ['--print', '--dangerously-skip-permissions', '-p', prompt],
        runInShell: false,
        environment: _envWithClaudePath(claudePath),
      ).timeout(const Duration(seconds: 60));

      if (result.exitCode != 0) {
        stderr.writeln('[RefinementService.generateAgentSystemPrompt] exit=${result.exitCode} stderr=${result.stderr}');
        return null;
      }
      final text = (result.stdout as String).trim();
      return text.isNotEmpty ? text : null;
    } catch (e) {
      stderr.writeln('[RefinementService.generateAgentSystemPrompt] exception: $e');
      return null;
    }
  }

  RefinementResult? _parseResult(String output) {
    try {
      final start = output.indexOf('{');
      final end = output.lastIndexOf('}');
      if (start == -1 || end == -1 || end <= start) return null;

      final data =
          jsonDecode(output.substring(start, end + 1)) as Map<String, dynamic>;

      return RefinementResult(
        taskMd: data['taskMd'] as String? ?? '',
        agentIds:
            (data['agentIds'] as List<dynamic>?)?.cast<String>() ?? [],
        agentSystemPrompts:
            (data['agentSystemPrompts'] as Map<String, dynamic>?)
                    ?.map((k, v) => MapEntry(k, v as String)) ??
                {},
      );
    } catch (_) {
      return null;
    }
  }
}
