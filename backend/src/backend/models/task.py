from pydantic import BaseModel, ConfigDict, Field


class TaskCreate(BaseModel):
    model_config = ConfigDict(str_strip_whitespace=True)

    title: str = Field(min_length=1, max_length=100)


class TaskUpdate(BaseModel):
    completed: bool = Field(strict=True)


class TaskRead(BaseModel):
    id: int
    title: str
    completed: bool
