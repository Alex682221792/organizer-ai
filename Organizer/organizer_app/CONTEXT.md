# Organizer App — Contexto del Proyecto

> Documento de referencia para retomar el desarrollo en una nueva sesión de Claude.

---

## ¿Qué es esto?

Una app Flutter para macOS que funciona como **Kanban dashboard de gestión de tareas impulsado por Claude AI agents**. El objetivo es poder crear tareas que se guardan como archivos `.md` con prompts refinados, organizarlas visualmente en un tablero Kanban, y ejecutarlas automáticamente mediante Claude Scheduled Tasks cada hora.

---

## Ubicación del proyecto

```
/Volumes/TOSHIBA EXTERNAL_USB/personal-repos/organizer-ai/Organizer/organizer_app/
```

Flutter está en: `/Users/alex/flutter/flutter`  
Xcode está en: `/Volumes/TOSHIBA EXTERNAL_USB/Applications/Xcode.app`

Para correr la app:
```bash
sudo xcode-select --switch "/Volumes/TOSHIBA EXTERNAL_USB/Applications/Xcode.app/Contents/Developer"
cd "/Volumes/TOSHIBA EXTERNAL_USB/personal-repos/organizer-ai/Organizer/organizer_app"
flutter run -d macos
```

---

## Stack técnico

| Elemento | Detalle |
|---|---|
| Framework | Flutter (macOS only) |
| State management | BLoC (flutter_bloc ^8.1.6) |
| DI | get_it ^7.7.0 |
| File system | dart:io (sin base de datos — todo en archivos) |
| Folder picker | file_picker ^8.0.0 |
| IDs | uuid ^4.4.0 |
| Persistencia de rutas | shared_preferences ^2.2.3 |

---

## Estructura de archivos del proyecto

```
lib/
├── main.dart                          # Entry point, llama setupInjection() + runApp()
├── app.dart                           # OrganizerApp: MaterialApp + MultiBlocProvider
├── injection_container.dart           # get_it: registra repos y BLoCs
├── core/
│   ├── constants/app_constants.dart   # Nombres de archivos, carpetas, prefs keys
│   └── theme/app_theme.dart           # Tema claro/oscuro (primary: #6366f1 indigo)
├── data/
│   ├── models/
│   │   ├── project_model.dart         # id, name, description, folderPath, color, createdAt
│   │   ├── task_model.dart            # id, projectId, title, status, instructions, runCount, needsInput
│   │   ├── task_status.dart           # enum: backlog|pending|inProgress|review|blocked|completed|cancelled
│   │   └── thread_message.dart        # role (user|agent), content, timestamp
│   └── repositories/
│       ├── project_repository.dart    # CRUD proyectos via shared_prefs + project.json
│       └── task_repository.dart       # CRUD tareas, read/write task.md, thread.jsonl, obs/
└── presentation/
    ├── blocs/
    │   ├── projects/                  # ProjectsBloc: LoadProjects, CreateProject, DeleteProject, SelectProject, PickProjectFolder
    │   └── tasks/                     # TasksBloc: LoadTasks, CreateTask, UpdateTaskStatus, DeleteTask, SelectTask, ClearSelectedTask
    ├── pages/
    │   └── home_page.dart             # Layout 3 columnas: sidebar | kanban | detail panel
    ├── widgets/
    │   ├── project_sidebar.dart       # Lista de proyectos (220px), botón nuevo proyecto
    │   ├── kanban_board.dart          # 7 columnas en scroll horizontal
    │   ├── kanban_column.dart         # Columna individual con header + badge + cards
    │   └── task_card.dart             # Card compacta: título, status badge, fecha, needsInput icon
    ├── panels/
    │   └── task_detail_panel.dart     # Panel derecho (360px): 3 tabs (Prompt | Observaciones | Conversación)
    └── dialogs/
        ├── create_project_dialog.dart  # Nombre + descripción + folder picker + color picker
        └── create_task_dialog.dart     # Título + instrucciones → se guarda en task.md
```

---

## Estructura de archivos en disco (por proyecto)

```
{carpeta-del-proyecto}/
├── project.json          ← metadata: id, name, description, color, createdAt
├── queue.json            ← tareas pendientes + recent_context por tarea (para agentes)
├── shared_chat.jsonl     ← chat compartido entre todos los agentes (JSON Lines)
└── tasks/
    └── {uuid}/
        ├── task.md       ← prompt refinado (lo que lee el agente Claude)
        ├── meta.json     ← estado, fechas, runCount, needsInput, instructions
        ├── thread.jsonl  ← historial legacy (ya no se usa en la UI principal)
        └── obs/          ← archivos escritos por el agente durante su ejecución
```

La lista de rutas de proyectos se persiste en `shared_preferences` con la key `project_paths`.

### Formato de mensaje en shared_chat.jsonl

```json
{
  "id": "uuid-v4",
  "timestamp": "2026-05-25T10:00:00.000Z",
  "role": "agent | user | system",
  "agent_id": "agent-uuid (opcional)",
  "agent_name": "Nombre del agente o 'Usuario'",
  "task_id": "task-uuid (null si es mensaje general)",
  "task_title": "Título de la tarea (opcional)",
  "type": "observation | update | decision | question | note | system",
  "content": "Texto del mensaje"
}
```

Los agentes deben:
1. Leer `queue.json` → cada tarea pendiente incluye `recent_context` con los últimos 10 mensajes del shared chat para esa tarea
2. Al observar algo relevante, escribir un JSON line en `shared_chat.jsonl` con `task_id` de la tarea en curso
3. Otros agentes pueden leer `shared_chat.jsonl` filtrando por `task_id` para obtener contexto antes de iniciar

---

## Estados de tarea (TaskStatus)

| Estado | jsonValue | Color UI |
|---|---|---|
| Backlog | `backlog` | Gris |
| Pendiente | `pending` | Ámbar |
| En Curso | `in_progress` | Azul |
| Revisión | `review` | Púrpura |
| Bloqueado | `blocked` | Rojo |
| Completado | `completed` | Verde |
| Cancelado | `cancelled` | Gris |

---

## Mecanismo de conversación con el agente

**Opción A (activa, implementada):** Chat en contexto dentro del panel de detalle de la tarea.
- Tab "Conversación" muestra mensajes del `thread.jsonl`
- El usuario escribe y se guarda con `role: "user"`
- El agente escribe con `role: "agent"`
- Al presionar "Editar" en el tab Prompt se puede actualizar el `task.md` y la tarea vuelve a Pendiente

**Opción B (a implementar):** Refinamiento automático asíncrono.
- El agente escribe `## NEEDS_INPUT:` en el `obs/run-N.md`
- La app detecta el flag, mueve la tarea a "Revisión" y notifica
- El usuario responde → se escribe en `meta.json → human_feedback`
- El próximo ciclo hourly del agente lee el feedback y re-ejecuta

---

## Integración con Claude Scheduled Tasks (pendiente)

El objetivo es tener una tarea programada que corra cada hora y:
1. Escanee todas las carpetas de proyectos registradas
2. Lea los `meta.json` buscando `status: "pending"`
3. Lance un subagente por cada tarea pendiente
4. El subagente lee `task.md` + `thread.jsonl` como contexto
5. Ejecuta (puede hacer web search, análisis, creación de docs)
6. Escribe resultados en `obs/run-{n}-{timestamp}.md`
7. Actualiza `meta.json` con nuevo status y `runCount + 1`
8. Si necesita input humano: escribe flag `needsInput: true` en `meta.json`

---

## Estado actual del build (último progreso)

El proyecto compila. Problemas resueltos durante el setup:
- ✅ Scaffolding macOS creado manualmente (project.pbxproj, Swift files, xib, entitlements)
- ✅ Xcode apuntado al path correcto en disco externo
- ✅ Podfile limpiado (removido target RunnerTests inexistente)
- ✅ Paths de xcconfig corregidos (`../../Flutter/` desde `Runner/Configs/`)
- ✅ XCFileLists creados en `macos/build/ephemeral/`
- ✅ `Runner.xcscheme` creado en `xcshareddata/xcschemes/`
- ✅ `.app_filename` = `Organizer.app` en `Flutter/ephemeral/`
- ⚠️ Último error reportado: `PathNotFoundException` buscando `organizer_app.app` en lugar de `Organizer.app` (ya corregido con `.app_filename`)

Pendiente verificar que la app levante completamente con la UI funcionando.

---

## Próximos features a implementar

1. **Integración Claude API** — al crear tarea, refinar las instrucciones con Claude antes de guardar `task.md`
2. **Scheduled Task script** — script que el agente programado ejecuta cada hora
3. **Notificaciones macOS** — alertar cuando `needsInput: true`
4. **File watcher** — detectar cambios en el file system y refrescar la UI automáticamente
5. **Re-ejecutar tarea** — botón en el panel de detalle que vuelve la tarea a "Pendiente"
