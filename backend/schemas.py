from pydantic import BaseModel
from typing import Dict

class CreatureCreate(BaseModel):
    x: float
    y: float
    genes: Dict[str, float]

class CreatureOut(CreatureCreate):
    id: int
    energy: float
    generation: int

    class Config:
        from_attributes = True
