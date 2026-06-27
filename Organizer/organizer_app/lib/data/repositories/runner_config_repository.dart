import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as p;
import '../../core/constants/app_constants.dart';
import '../models/runner_config.dart';

class RunnerConfigRepository {
  String get _configDir =>
      p.join(Platform.environment['HOME'] ?? '', AppConstants.runnerConfigDir);

  String get _configPath =>
      p.join(_configDir, AppConstants.runnerConfigFile);

  String get _scriptPath =>
      p.join(Platform.environment['HOME'] ?? '', '.local', 'bin', AppConstants.runnerScriptName);

  String get _launchAgentPath => p.join(
        Platform.environment['HOME'] ?? '',
        'Library',
        'LaunchAgents',
        '${AppConstants.launchAgentId}.plist',
      );

  Future<RunnerConfig> load() async {
    try {
      final file = File(_configPath);
      if (!await file.exists()) return const RunnerConfig();
      final content = await file.readAsString();
      return RunnerConfig.fromJson(jsonDecode(content) as Map<String, dynamic>);
    } catch (_) {
      return const RunnerConfig();
    }
  }

  Future<void> save(RunnerConfig config) async {
    final dir = Directory(_configDir);
    if (!await dir.exists()) await dir.create(recursive: true);
    await File(_configPath).writeAsString(
      const JsonEncoder.withIndent('  ').convert(config.toJson()),
    );
  }

  Future<bool> isLaunchAgentInstalled() async {
    return File(_launchAgentPath).exists();
  }

  Future<void> installRunner(RunnerConfig config) async {
    await _writeScript(config.claudePath);
    await _writeLaunchAgent();
    await _loadLaunchAgent();
    await save(config);
  }

  Future<void> uninstallRunner() async {
    await _unloadLaunchAgent();
    final plist = File(_launchAgentPath);
    if (await plist.exists()) await plist.delete();
  }

  Future<void> _writeScript(String claudePath) async {
    final binDir = Directory(p.dirname(_scriptPath));
    if (!await binDir.exists()) await binDir.create(recursive: true);

    final configPath = _configPath;
    final configDir = _configDir;
    const bundleId = AppConstants.bundleId;

    final script = '''#!/usr/bin/env bash
set -euo pipefail

# ---- Fixed log path — all output (stdout + stderr) consolidated here --------
LOG="$configDir/runner.log"
mkdir -p "$configDir"
exec >> "\$LOG" 2>&1

log() { echo "[\$(date '+%Y-%m-%d %H:%M:%S')] [organizer-runner] \$*"; }

notify() {
  osascript -e "display notification \\"\$1\\" with title \\"Organizer\\"" 2>/dev/null || true
}

# ---- Config -----------------------------------------------------------------
CONFIG="$configPath"
BUNDLE_ID="$bundleId"

if [ ! -f "\$CONFIG" ]; then log "No config file found."; exit 0; fi

ENABLED=\$(python3 -c "import json; print(json.load(open('\$CONFIG')).get('enabled', False))" 2>/dev/null || echo False)
[ "\$ENABLED" = "True" ] || exit 0

INTERVAL=\$(python3 -c "import json; print(json.load(open('\$CONFIG')).get('intervalMinutes', 60))" 2>/dev/null || echo 60)
LAST_RUN=\$(python3 -c "import json; print(json.load(open('\$CONFIG')).get('lastRun') or '')" 2>/dev/null || echo "")
CLAUDE=\$(python3 -c "import json; print(json.load(open('\$CONFIG')).get('claudePath', ''))" 2>/dev/null || echo "")

# ---- Interval check ---------------------------------------------------------
NOW=\$(date +%s)
if [ -n "\$LAST_RUN" ]; then
  LAST_TS=\$(python3 -c "import datetime; print(int(datetime.datetime.fromisoformat('\$LAST_RUN'.replace('Z','+00:00')).timestamp()))" 2>/dev/null || echo 0)
  ELAPSED=\$(( NOW - LAST_TS ))
  REQUIRED=\$(( INTERVAL * 60 ))
  [ "\$ELAPSED" -ge "\$REQUIRED" ] || exit 0
fi

if [ -z "\$CLAUDE" ] || [ ! -x "\$CLAUDE" ]; then
  log "claude not found at: \$CLAUDE"
  notify "Error: claude CLI not found at \$CLAUDE"
  exit 1
fi

# Write lastRun immediately to prevent overlapping concurrent runs
python3 -c "
import json, datetime
with open('\$CONFIG') as f: d = json.load(f)
d['lastRun'] = datetime.datetime.now(datetime.timezone.utc).isoformat()
with open('\$CONFIG', 'w') as f: json.dump(d, f, indent=2)
" || true

# ---- Read project paths via cfprefsd (always current, no stale disk reads) --
PROJECT_PATHS_RAW=\$(defaults read "\$BUNDLE_ID" flutter.project_paths 2>/dev/null | grep -oE '"[^"]+"' | tr -d '"' || true)

if [ -z "\$PROJECT_PATHS_RAW" ]; then
  log "No projects registered."
  exit 0
fi

log "Scanning projects..."
notify "Iniciando escaneo de tareas pendientes..."
TOTAL_TASKS=0

while IFS= read -r PROJECT_DIR; do
  [ -z "\$PROJECT_DIR" ] && continue
  [ -f "\$PROJECT_DIR/project.json" ] || continue
  [ -f "\$PROJECT_DIR/queue.json" ] || continue

  SCHED=\$(python3 -c "import json; print(json.load(open('\$PROJECT_DIR/project.json')).get('schedulerEnabled', True))" 2>/dev/null || echo True)
  [ "\$SCHED" = "True" ] || continue

  PROJECT_NAME=\$(python3 -c "import json; print(json.load(open('\$PROJECT_DIR/project.json')).get('name', 'project'))" 2>/dev/null || echo "project")

  ATTEMPTED_IDS=""
  while true; do
    # Count pending tasks — use temp file so Python code has no bash quoting constraints
    TMPPY=\$(mktemp /tmp/orgXXXXXXXX)
    cat > "\$TMPPY" << 'PYEOF'
import json, sys
with open(sys.argv[1]) as f:
    q = json.load(f)
attempted = set(sys.argv[2].split()) if sys.argv[2].strip() else set()
pending = [t for t in q.get('pending', []) if t['id'] not in attempted]
print(len(pending))
PYEOF
    COUNT=\$(python3 -u "\$TMPPY" "\$PROJECT_DIR/queue.json" "\$ATTEMPTED_IDS" 2>/dev/null || echo 0)
    rm -f "\$TMPPY"

    [ "\${COUNT:-0}" -gt 0 ] || break

    # Get IDs of current batch
    TMPPY=\$(mktemp /tmp/orgXXXXXXXX)
    cat > "\$TMPPY" << 'PYEOF'
import json, sys
with open(sys.argv[1]) as f:
    q = json.load(f)
attempted = set(sys.argv[2].split()) if sys.argv[2].strip() else set()
pending = [t for t in q.get('pending', []) if t['id'] not in attempted]
print(' '.join(t['id'] for t in pending))
PYEOF
    NEW_IDS=\$(python3 -u "\$TMPPY" "\$PROJECT_DIR/queue.json" "\$ATTEMPTED_IDS" 2>/dev/null || echo "")
    rm -f "\$TMPPY"

    PREV_ATTEMPTED="\$ATTEMPTED_IDS"
    ATTEMPTED_IDS="\$ATTEMPTED_IDS \$NEW_IDS"

    log "Project: \$PROJECT_DIR — \$COUNT pending task(s)"
    notify "\$PROJECT_NAME: ejecutando \$COUNT tarea(s)..."
    TOTAL_TASKS=\$(( TOTAL_TASKS + COUNT ))

    # Task runner
    TMPPY=\$(mktemp /tmp/orgXXXXXXXX)
    cat > "\$TMPPY" << 'PYEOF'
import json, subprocess, os, sys, datetime

project_dir = sys.argv[1]
claude_bin = sys.argv[2]
queue_file = sys.argv[3]
prev_attempted_str = sys.argv[4] if len(sys.argv) > 4 else ''

with open(queue_file) as f:
    q = json.load(f)
prev_attempted = set(prev_attempted_str.split()) if prev_attempted_str.strip() else set()
tasks = [t for t in q.get('pending', []) if t['id'] not in prev_attempted]

for task in tasks:
  task_id = task.get('id')
  if not task_id:
    continue
  task_dir = os.path.join(project_dir, 'tasks', task_id)
  meta_file = os.path.join(task_dir, 'meta.json')
  prompt_file = os.path.join(task_dir, 'task.md')
  agent_prompts_file = os.path.join(task_dir, 'agent_prompts.json')

  if not os.path.exists(prompt_file):
    print(f'[organizer-runner] task.md not found for {task_id}, skipping')
    continue

  with open(prompt_file) as f:
    task_content = f.read()

  agent_prompts = {}
  if os.path.exists(agent_prompts_file):
    try:
      with open(agent_prompts_file) as f:
        agent_prompts = json.load(f)
    except Exception:
      pass

  agent_ids = task.get('agent_ids', [])
  agents_to_run = [(aid, agent_prompts.get(aid)) for aid in agent_ids] if agent_ids else [('default', None)]

  if os.path.exists(meta_file):
    try:
      with open(meta_file) as f:
        meta = json.load(f)
      meta['status'] = 'in_progress'
      meta['updatedAt'] = datetime.datetime.now().isoformat()
      with open(meta_file, 'w') as f:
        json.dump(meta, f, indent=2)
      print(f'[organizer-runner] Task {task_id} -> in_progress')
    except Exception as e:
      print(f'[organizer-runner] Failed to set in_progress for {task_id}: {e}')

  task_success = True
  for agent_id, system_prompt in agents_to_run:
    if system_prompt:
      full_prompt = '<system>\\n' + system_prompt + '\\n</system>\\n\\n' + task_content
    else:
      full_prompt = task_content

    working_dir = task.get('working_dir') or project_dir
    print(f'[organizer-runner] Task {task_id} — agent {agent_id} — cwd: {working_dir}')
    output = ''
    stderr_out = ''
    try:
      result = subprocess.run(
        [claude_bin, '--print', '--dangerously-skip-permissions', '-p', full_prompt],
        cwd=working_dir,
        capture_output=True,
        text=True,
        timeout=600
      )
      output = result.stdout
      stderr_out = result.stderr or ''
      if result.returncode != 0:
        task_success = False
        if stderr_out:
          output = (output or '') + '\\n\\n[exit ' + str(result.returncode) + '] ' + stderr_out
        print(f'[organizer-runner] Task {task_id} exited with code {result.returncode}: {stderr_out[:300]}')
    except subprocess.TimeoutExpired as e:
      partial = e.stdout if isinstance(e.stdout, str) else (e.stdout or b'').decode('utf-8', errors='replace')
      output = partial + '\\n\\n[timeout: task exceeded 10-min limit]'
      task_success = False
      print(f'[organizer-runner] Task {task_id} timed out after 600s')
    except Exception as e:
      output = '[error: ' + str(e) + ']'
      task_success = False
      print(f'[organizer-runner] Task {task_id} error: {e}')

    thread_file = os.path.join(task_dir, 'thread.jsonl')
    with open(thread_file, 'a') as f:
      entry = {
        'role': 'assistant',
        'agent_id': agent_id,
        'content': output,
        'ts': datetime.datetime.now().isoformat(),
        'success': task_success,
      }
      f.write(json.dumps(entry) + '\\n')
    status_str = 'ok' if task_success else 'FAILED'
    print(f'[organizer-runner] Task {task_id} agent {agent_id} finished — {status_str} — {len(output)} chars output')

  if os.path.exists(meta_file):
    try:
      with open(meta_file) as f:
        meta = json.load(f)
      final_status = 'completed' if task_success else 'pending'
      meta['status'] = final_status
      meta['runCount'] = meta.get('runCount', 0) + 1
      meta['updatedAt'] = datetime.datetime.now().isoformat()
      with open(meta_file, 'w') as f:
        json.dump(meta, f, indent=2)
      retry_note = '' if task_success else ' (will retry next run)'
      print(f'[organizer-runner] Task {task_id} -> {final_status}{retry_note}')
    except Exception as e:
      print(f'[organizer-runner] Failed to update meta for {task_id}: {e}')
PYEOF
    python3 -u "\$TMPPY" "\$PROJECT_DIR" "\$CLAUDE" "\$PROJECT_DIR/queue.json" "\$PREV_ATTEMPTED" || log "Task runner failed"
    rm -f "\$TMPPY"

    # Resync queue.json after each batch
    TMPPY=\$(mktemp /tmp/orgXXXXXXXX)
    cat > "\$TMPPY" << 'PYEOF'
import json, os, datetime, sys

project_dir = sys.argv[1]
tasks_dir = os.path.join(project_dir, 'tasks')
if not os.path.isdir(tasks_dir):
  sys.exit(0)

all_tasks = []
for tid in os.listdir(tasks_dir):
  meta_path = os.path.join(tasks_dir, tid, 'meta.json')
  if os.path.exists(meta_path):
    try:
      with open(meta_path) as f:
        all_tasks.append(json.load(f))
    except Exception:
      pass

completed_ids = {t['id'] for t in all_tasks if t.get('status') == 'completed'}
pending = []
blocked = []
needs_input = []

for t in sorted(all_tasks, key=lambda x: x.get('updatedAt', ''), reverse=True):
  status = t.get('status')
  blocked_by = t.get('blockedBy', [])
  is_blocked = any(bid not in completed_ids for bid in blocked_by)
  if status == 'pending':
    if is_blocked:
      blocked.append({'id': t['id'], 'title': t['title'], 'blocked_by': blocked_by})
    else:
      pending.append({'id': t['id'], 'title': t['title'], 'agent_ids': t.get('agentIds', []), 'run_count': t.get('runCount', 0)})
  if t.get('needsInput'):
    needs_input.append({'id': t['id'], 'title': t['title'], 'agent_ids': t.get('agentIds', [])})

queue = {
  'updated_at': datetime.datetime.now().isoformat(),
  'pending': pending,
  'blocked': blocked,
  'needs_input': needs_input,
}
with open(os.path.join(project_dir, 'queue.json'), 'w') as f:
  json.dump(queue, f, indent=2)
print(f'[organizer-runner] queue.json synced: {len(pending)} pending, {len(blocked)} blocked')
PYEOF
    python3 -u "\$TMPPY" "\$PROJECT_DIR" || log "Queue sync failed"
    rm -f "\$TMPPY"

  done  # inner while (dependency chain resolution)
done <<< "\$PROJECT_PATHS_RAW"

log "Done. Total tasks processed: \$TOTAL_TASKS"
if [ "\$TOTAL_TASKS" -gt 0 ]; then
  notify "Completado: \$TOTAL_TASKS tarea(s) procesada(s)"
else
  notify "Escaneo completado — sin tareas pendientes"
fi
''';

    final scriptFile = File(_scriptPath);
    await scriptFile.writeAsString(script);
    await Process.run('chmod', ['+x', _scriptPath]);
  }

  Future<void> _writeLaunchAgent() async {
    final plist = '''<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
  "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key>
  <string>${AppConstants.launchAgentId}</string>
  <key>ProgramArguments</key>
  <array>
    <string>/bin/bash</string>
    <string>$_scriptPath</string>
  </array>
  <key>StartInterval</key>
  <integer>300</integer>
  <key>RunAtLoad</key>
  <false/>
  <key>StandardOutPath</key>
  <string>${p.join(Platform.environment['HOME'] ?? '', AppConstants.runnerConfigDir, 'runner.log')}</string>
  <key>StandardErrorPath</key>
  <string>${p.join(Platform.environment['HOME'] ?? '', AppConstants.runnerConfigDir, 'runner-error.log')}</string>
</dict>
</plist>
''';

    final launchAgentsDir = Directory(p.dirname(_launchAgentPath));
    if (!await launchAgentsDir.exists()) {
      await launchAgentsDir.create(recursive: true);
    }
    await File(_launchAgentPath).writeAsString(plist);
  }

  Future<void> _loadLaunchAgent() async {
    await Process.run('launchctl', ['unload', _launchAgentPath]);
    final result = await Process.run('launchctl', ['load', _launchAgentPath]);
    if (result.exitCode != 0) {
      throw Exception('Failed to load LaunchAgent: ${result.stderr}');
    }
  }

  Future<void> _unloadLaunchAgent() async {
    await Process.run('launchctl', ['unload', _launchAgentPath]);
  }
}
