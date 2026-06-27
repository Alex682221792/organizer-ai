enum TaskStatus {
  backlog,
  pending,
  inProgress,
  review,
  blocked,
  completed,
  cancelled;

  String get displayName => switch (this) {
        TaskStatus.backlog => 'Backlog',
        TaskStatus.pending => 'Pendiente',
        TaskStatus.inProgress => 'En Curso',
        TaskStatus.review => 'Revisión',
        TaskStatus.blocked => 'Bloqueado',
        TaskStatus.completed => 'Completado',
        TaskStatus.cancelled => 'Cancelado',
      };

  String get jsonValue => switch (this) {
        TaskStatus.backlog => 'backlog',
        TaskStatus.pending => 'pending',
        TaskStatus.inProgress => 'in_progress',
        TaskStatus.review => 'review',
        TaskStatus.blocked => 'blocked',
        TaskStatus.completed => 'completed',
        TaskStatus.cancelled => 'cancelled',
      };

  static TaskStatus fromJson(String value) => switch (value) {
        'backlog' => TaskStatus.backlog,
        'pending' => TaskStatus.pending,
        'in_progress' => TaskStatus.inProgress,
        'review' => TaskStatus.review,
        'blocked' => TaskStatus.blocked,
        'completed' => TaskStatus.completed,
        'cancelled' => TaskStatus.cancelled,
        _ => TaskStatus.backlog,
      };
}
