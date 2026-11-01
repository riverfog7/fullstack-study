export type Task = {
  id: number
  title: string
  completed: boolean
}

export type TaskCreate = {
  title: string
}

export type TaskUpdate = {
  completed: boolean
}
