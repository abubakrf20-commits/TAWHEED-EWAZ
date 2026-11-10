/// Raw-SQL schema for the task auxiliary tables (completion history +
/// subtasks). These tables are intentionally NOT Drift `@Table` classes so no
/// `build_runner` regeneration is needed: they are created with
/// `CREATE TABLE IF NOT EXISTS` (fresh installs + v31 upgrade) and accessed
/// through raw `customSelect`/`customStatement` in [TaskAuxDao].
class TaskAuxTables {
  TaskAuxTables._();

  static const String completionLog = 'task_completion_log';
  static const String subtask = 'task_subtask';

  static const List<String> createStatements = <String>[
    'CREATE TABLE IF NOT EXISTS task_completion_log (id INTEGER PRIMARY KEY AUTOINCREMENT, task_id TEXT NOT NULL, completed_at INTEGER NOT NULL)',
    'CREATE INDEX IF NOT EXISTS idx_completion_log_task ON task_completion_log (task_id)',
    'CREATE TABLE IF NOT EXISTS task_subtask (id TEXT NOT NULL PRIMARY KEY, task_id TEXT NOT NULL, title TEXT NOT NULL, is_completed INTEGER NOT NULL DEFAULT 0, position INTEGER NOT NULL DEFAULT 0)',
    'CREATE INDEX IF NOT EXISTS idx_subtask_task ON task_subtask (task_id)',
  ];
}
