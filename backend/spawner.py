import random
from models import Creature
from sqlalchemy.orm import Session
import math

CHUNK_SIZE = 512

def spawn_creatures(x: int, y: int, db: Session, count: int = 5):
    x_min, x_max = x * CHUNK_SIZE, (x + 1) * CHUNK_SIZE
    y_min, y_max = y * CHUNK_SIZE, (y + 1) * CHUNK_SIZE

    creatures = []
    for _ in range(count):
        creature = Creature(
            x=random.uniform(x_min, x_max),
            y=random.uniform(y_min, y_max),
            genes={
                "speed": random.random(),
                "size": random.random(),
                "color":random.random(),
                "move_angle": random.uniform(0, 2*math.pi),
                "move_jitter": random.uniform(0, 0.5)
            },
            energy=100.0,
            generation=0
        )
        creatures.append(creature)

    db.add_all(creatures)
    db.commit()
    return creatures
