import { useState } from 'react'
import type { FormEvent } from 'react'

type TaskFormProps = {
  disabled: boolean
  onAdd: (title: string) => Promise<boolean>
}

export function TaskForm({ disabled, onAdd }: TaskFormProps) {
  const [title, setTitle] = useState('')

  async function handleSubmit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault()
    if (!title.trim() || disabled) return

    const saved = await onAdd(title)
    if (saved) setTitle('')
  }

  return (
    <form className="task-form" onSubmit={handleSubmit}>
      <label htmlFor="task-title">새 할 일</label>
      <div className="task-input-row">
        <input
          id="task-title"
          name="title"
          value={title}
          onChange={(event) => setTitle(event.target.value)}
          placeholder="예: Docker 실습 준비하기"
          maxLength={100}
          required
          disabled={disabled}
          autoComplete="off"
        />
        <button className="add-button" type="submit" disabled={disabled || !title.trim()}>
          추가
        </button>
      </div>
      <p className="input-hint">100자까지 입력할 수 있어요.</p>
    </form>
  )
}
