from sqlalchemy import Column, Integer, Float, String, JSON, Index
from database import Base

class Creature(Base):
    __tablename__ = "creatures"

    id = Column(Integer, primary_key=True, index=True)
    x = Column(Float, index=True)
    y = Column(Float, index=True)
    genes = Column(JSON)
    energy = Column(Float, default=100)
    generation = Column(Integer, default=1)

    __table_args__ = (
        Index("idx_chunk_position", "x", "y"),
    )
