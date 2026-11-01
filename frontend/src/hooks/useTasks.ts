import { useEffect, useState } from 'react'
import { createTask, deleteTask, listTasks, updateTask } from '../api/tasks'
import type { Task } from '../types/task'

function errorMessage(error: unknown): string {
  return error instanceof Error ? error.message : '요청을 처리하지 못했습니다.'
}

export function useTasks() {
  const [tasks, setTasks] = useState<Task[]>([])
  const [isLoading, setIsLoading] = useState(true)
  const [isSaving, setIsSaving] = useState(false)
  const [error, setError] = useState<string | null>(null)

  useEffect(() => {
    const controller = new AbortController()

    listTasks(controller.signal)
      .then((items) => {
        if (!controller.signal.aborted) setTasks(items)
      })
      .catch((reason: unknown) => {
        if (!controller.signal.aborted) setError(errorMessage(reason))
      })
      .finally(() => {
        if (!controller.signal.aborted) setIsLoading(false)
      })

    return () => controller.abort()
  }, [])

  async function refreshTasks() {
    setIsLoading(true)
    setError(null)
    try {
      setTasks(await listTasks())
    } catch (reason) {
      setError(errorMessage(reason))
    } finally {
      setIsLoading(false)
    }
  }

  // 변경 요청을 저장한 다음 서버에서 최신 목록을 다시 받습니다.
  async function saveChange(change: () => Promise<unknown>): Promise<boolean> {
    setIsSaving(true)
    setError(null)
    let saved = false

    try {
      await change()
      saved = true
      setTasks(await listTasks())
    } catch (reason) {
      setError(
        saved
          ? '변경 사항은 저장했지만 목록을 불러오지 못했습니다. 목록 새로고침을 눌러 주세요.'
          : errorMessage(reason),
      )
    } finally {
      setIsSaving(false)
    }

    return saved
  }

  function addTask(title: string) {
    return saveChange(() => createTask({ title: title.trim() }))
  }

  function toggleTask(task: Task) {
    return saveChange(() => updateTask(task.id, { completed: !task.completed }))
  }

  function removeTask(id: number) {
    return saveChange(() => deleteTask(id))
  }

  return { tasks, isLoading, isSaving, error, refreshTasks, addTask, toggleTask, removeTask }
}
