import { render, screen, waitFor } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { beforeEach, expect, test, vi } from 'vitest'
import App from '../src/App'
import type { Task } from '../src/types/task'

let tasks: Task[]
let nextId: number
const fetchMock = vi.fn<typeof fetch>()

function json(data: unknown, status = 200) {
  return new Response(JSON.stringify(data), {
    status,
    headers: { 'Content-Type': 'application/json' },
  })
}

// 실제 백엔드 대신 HTTP 응답을 준비합니다. 화면과 API 함수는 그대로 실행합니다.
async function fakeApi(input: RequestInfo | URL, options?: RequestInit): Promise<Response> {
  const url = String(input)
  const method = options?.method ?? 'GET'
  const id = Number(url.split('/').at(-1))

  if (method === 'GET' && url === '/api/tasks') return json(tasks)
  if (method === 'POST' && url === '/api/tasks') {
    const body = JSON.parse(String(options?.body)) as { title: string }
    const task = { id: nextId++, title: body.title, completed: false }
    tasks.push(task)
    return json(task, 201)
  }
  if (method === 'PATCH') {
    const task = tasks.find((item) => item.id === id)
    if (!task) return json({ detail: 'Not found' }, 404)
    const body = JSON.parse(String(options?.body)) as { completed: boolean }
    task.completed = body.completed
    return json(task)
  }
  if (method === 'DELETE') {
    tasks = tasks.filter((task) => task.id !== id)
    return new Response(null, { status: 204 })
  }
  return json({ detail: 'Not found' }, 404)
}

beforeEach(() => {
  tasks = [{ id: 1, title: 'API 만들기', completed: false }]
  nextId = 2
  fetchMock.mockImplementation(fakeApi)
  vi.stubGlobal('fetch', fetchMock)
})

test('서버에서 받은 할 일 목록과 개수를 표시한다', async () => {
  tasks.push({ id: 2, title: 'Git 복습하기', completed: true })
  render(<App />)

  expect(await screen.findByText('API 만들기')).toBeVisible()
  expect(screen.getByRole('checkbox', { name: 'Git 복습하기 완료 여부' })).toBeChecked()
  expect(screen.getByText(/전체/)).toHaveTextContent('전체 2개/완료 1개')
})

test('새 할 일을 저장하고 입력칸을 비운다', async () => {
  const user = userEvent.setup()
  render(<App />)
  await screen.findByText('API 만들기')

  await user.type(screen.getByRole('textbox', { name: '새 할 일' }), '  Docker 공부하기  ')
  await user.click(screen.getByRole('button', { name: '추가' }))

  expect(await screen.findByText('Docker 공부하기')).toBeVisible()
  expect(screen.getByRole('textbox', { name: '새 할 일' })).toHaveValue('')
  expect(screen.getByText(/전체/)).toHaveTextContent('전체 2개/완료 0개')
})

test('체크박스로 완료와 미완료 상태를 변경한다', async () => {
  const user = userEvent.setup()
  render(<App />)
  const checkbox = await screen.findByRole('checkbox', { name: 'API 만들기 완료 여부' })

  await user.click(checkbox)
  await waitFor(() => expect(checkbox).toBeChecked())
  expect(screen.getByText(/전체/)).toHaveTextContent('완료 1개')

  await waitFor(() => expect(checkbox).toBeEnabled())
  await user.click(checkbox)
  await waitFor(() => expect(checkbox).not.toBeChecked())
  expect(screen.getByText(/전체/)).toHaveTextContent('완료 0개')
})

test('삭제 후 목록을 갱신하고 빈 목록을 표시한다', async () => {
  const user = userEvent.setup()
  render(<App />)
  await screen.findByText('API 만들기')

  await user.click(screen.getByRole('button', { name: 'API 만들기 삭제' }))

  expect(await screen.findByText('아직 등록한 할 일이 없어요.')).toBeVisible()
  expect(screen.queryByText('API 만들기')).not.toBeInTheDocument()
})

test('저장 실패를 알리고 입력한 제목을 유지한다', async () => {
  const user = userEvent.setup()
  render(<App />)
  await screen.findByText('API 만들기')
  fetchMock.mockResolvedValueOnce(json({ detail: 'Server error' }, 500))

  await user.type(screen.getByRole('textbox', { name: '새 할 일' }), '실습 준비')
  await user.click(screen.getByRole('button', { name: '추가' }))

  expect(await screen.findByRole('alert')).toHaveTextContent('요청을 처리하지 못했습니다.')
  expect(screen.getByRole('textbox', { name: '새 할 일' })).toHaveValue('실습 준비')
  expect(screen.queryByText('실습 준비')).not.toBeInTheDocument()
})

test('연결 실패 후 목록 새로고침으로 다시 불러올 수 있다', async () => {
  const user = userEvent.setup()
  fetchMock.mockRejectedValueOnce(new TypeError('Failed to fetch'))
  render(<App />)
  expect(await screen.findByRole('alert')).toHaveTextContent('서버에 연결할 수 없습니다.')

  await user.click(screen.getByRole('button', { name: '목록 새로고침' }))

  expect(await screen.findByText('API 만들기')).toBeVisible()
  expect(screen.queryByRole('alert')).not.toBeInTheDocument()
})

test('저장 후 조회만 실패하면 재등록하지 않고 목록을 다시 조회한다', async () => {
  const user = userEvent.setup()
  render(<App />)
  await screen.findByText('API 만들기')
  fetchMock.mockImplementationOnce(fakeApi).mockRejectedValueOnce(new TypeError('Failed to fetch'))

  await user.type(screen.getByRole('textbox', { name: '새 할 일' }), '자료 읽기')
  await user.click(screen.getByRole('button', { name: '추가' }))

  expect(await screen.findByRole('alert')).toHaveTextContent('변경 사항은 저장했지만')
  expect(screen.getByRole('textbox', { name: '새 할 일' })).toHaveValue('')
  await user.click(screen.getByRole('button', { name: '목록 새로고침' }))
  expect(await screen.findByText('자료 읽기')).toBeVisible()
  expect(screen.getAllByRole('checkbox')).toHaveLength(2)
})
