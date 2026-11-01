import type { Task } from '../types/task'

type TaskItemProps = {
  task: Task
  disabled: boolean
  onToggle: (task: Task) => Promise<boolean>
  onDelete: (id: number) => Promise<boolean>
}

export function TaskItem({ task, disabled, onToggle, onDelete }: TaskItemProps) {
  return (
    <li className={`task-item${task.completed ? ' is-completed' : ''}`}>
      <label className="task-check">
        <input
          type="checkbox"
          checked={task.completed}
          onChange={() => void onToggle(task)}
          disabled={disabled}
          aria-label={`${task.title} 완료 여부`}
        />
        <span className="task-title">{task.title}</span>
      </label>
      <button
        className="delete-button"
        type="button"
        onClick={() => void onDelete(task.id)}
        disabled={disabled}
        aria-label={`${task.title} 삭제`}
      >
        삭제
      </button>
    </li>
  )
}
