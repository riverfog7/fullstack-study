import type { Task, TaskCreate, TaskUpdate } from '../types/task'

const API_URL = '/api/tasks'

// 화면 코드는 HTTP 요청 방법을 몰라도 이 함수들을 사용할 수 있습니다.
async function request(path = '', options: RequestInit = {}): Promise<Response> {
  let response: Response

  try {
    response = await fetch(`${API_URL}${path}`, options)
  } catch (error) {
    if (error instanceof Error && error.name === 'AbortError') throw error
    throw new Error('서버에 연결할 수 없습니다. 잠시 후 다시 시도해 주세요.', { cause: error })
  }

  if (!response.ok) {
    if (response.status === 404) throw new Error('해당 할 일을 찾을 수 없습니다.')
    if (response.status === 422) throw new Error('할 일 제목은 1~100자로 입력해 주세요.')
    throw new Error('요청을 처리하지 못했습니다. 잠시 후 다시 시도해 주세요.')
  }

  return response
}

export async function listTasks(signal?: AbortSignal): Promise<Task[]> {
  const response = await request('', { signal })
  return response.json()
}

export async function createTask(task: TaskCreate): Promise<Task> {
  const response = await request('', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(task),
  })
  return response.json()
}

export async function updateTask(id: number, task: TaskUpdate): Promise<Task> {
  const response = await request(`/${id}`, {
    method: 'PATCH',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(task),
  })
  return response.json()
}

export async function deleteTask(id: number): Promise<void> {
  // 204 응답에는 본문이 없으므로 response.json()을 호출하지 않습니다.
  await request(`/${id}`, { method: 'DELETE' })
}
