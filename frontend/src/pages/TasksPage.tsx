import { TaskForm } from '../components/TaskForm'
import { TaskList } from '../components/TaskList'
import { useTasks } from '../hooks/useTasks'

export function TasksPage() {
  const { tasks, isLoading, isSaving, error, refreshTasks, addTask, toggleTask, removeTask } =
    useTasks()
  const completedCount = tasks.filter((task) => task.completed).length
  const busy = isLoading || isSaving

  return (
    <main className="tasks-page">
      <header className="page-header">
        <p className="eyebrow">MY TASKS</p>
        <h1>할 일 목록</h1>
        <p>해야 할 일을 적고, 끝난 일은 체크해 보세요.</p>
      </header>

      <section className="task-panel" aria-label="할 일 관리">
        <TaskForm disabled={busy} onAdd={addTask} />

        <div className="list-heading">
          <p className="task-summary" aria-live="polite">
            전체 <strong>{tasks.length}</strong>개
            <span className="summary-separator" aria-hidden="true">/</span>
            완료 <strong>{completedCount}</strong>개
          </p>
          <button
            className="refresh-button"
            type="button"
            onClick={() => void refreshTasks()}
            disabled={busy}
          >
            목록 새로고침
          </button>
        </div>

        {error && <p className="error-message" role="alert">{error}</p>}
        {isLoading ? (
          <p className="loading-message" role="status">목록을 불러오는 중이에요.</p>
        ) : (
          <TaskList
            tasks={tasks}
            disabled={busy}
            onToggle={toggleTask}
            onDelete={removeTask}
          />
        )}
        <p className="save-status" role="status">{isSaving ? '변경 사항을 저장하는 중이에요.' : ''}</p>
      </section>
    </main>
  )
}
