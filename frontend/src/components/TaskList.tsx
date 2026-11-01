import type { Task } from '../types/task'
import { TaskItem } from './TaskItem'

type TaskListProps = {
  tasks: Task[]
  disabled: boolean
  onToggle: (task: Task) => Promise<boolean>
  onDelete: (id: number) => Promise<boolean>
}

export function TaskList({ tasks, disabled, onToggle, onDelete }: TaskListProps) {
  if (tasks.length === 0) {
    return (
      <div className="empty-state">
        <p>아직 등록한 할 일이 없어요.</p>
        <span>첫 번째 할 일을 추가해 보세요.</span>
      </div>
    )
  }

  return (
    <ul className="task-list" aria-label="할 일 목록">
      {tasks.map((task) => (
        <TaskItem
          key={task.id}
          task={task}
          disabled={disabled}
          onToggle={onToggle}
          onDelete={onDelete}
        />
      ))}
    </ul>
  )
}
