import asyncio
import random
import time
import traceback
from fastapi import FastAPI, Depends, WebSocket
import json
from sqlalchemy.orm import Session
from database import SessionLocal, engine
from spawner import spawn_creatures
import models
from schemas import CreatureCreate, CreatureOut
from collections import defaultdict
from fastapi.middleware.cors import CORSMiddleware
from sqlalchemy.orm import Session
from models import Creature
from database import SessionLocal
import math
import uvloop

asyncio.set_event_loop_policy(uvloop.EventLoopPolicy())

last_time = time.time()

MAX_CREATURES_PER_CHUNK = 200
REPRODUCTION_ENERGY_COST = 60.0
REPRODUCTION_COOLDOWN_TIME = 20.0
REPRODUCTION_RADIUS = 30.0
MAX_CREATURES_PER_MESSAGE = 50
MUTATION_AMOUNT = 0.1
DENSITY_LIMIT = 5

models.Base.metadata.create_all(bind=engine)

app = FastAPI()

websocket_chunk_map = {}

active_chunks = {}
CHUNK_TIMEOUT = 10

def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

##  LEGACY HTTP ENDPOINT
"""@app.post("/spawn", response_model=CreatureOut)
def spawn(creature: CreatureCreate, db: Session = Depends(get_db)):
    db_creature = models.Creature(**creature.dict())
    db.add(db_creature)
    db.commit()
    db.refresh(db_creature)
    return db_creature

@app.get("/chunks/{chunk_x}/{chunk_y}", response_model=list[CreatureOut])
def get_chunk(chunk_x: int, chunk_y: int, db: Session = Depends(get_db)):
    return load_chunk(chunk_x, chunk_y, db)"""

def load_chunk(chunk_x, chunk_y, db):
    size = 512  # Chunk size
    x_min = chunk_x * size
    y_min = chunk_y * size
    x_max = x_min + size
    y_max = y_min + size

    collected = db.query(models.Creature).filter(
        models.Creature.x >= x_min,
        models.Creature.x < x_max,
        models.Creature.y >= y_min,
        models.Creature.y < y_max
    ).all()

    if not collected:
        collected = spawn_creatures(chunk_x, chunk_y, db)

    if len(collected) > MAX_CREATURES_PER_CHUNK:
        collected = sorted(collected, key=lambda c: c.energy, reverse=True)[:MAX_CREATURES_PER_CHUNK]
        keep = collected[:MAX_CREATURES_PER_CHUNK]
        remove = collected[MAX_CREATURES_PER_CHUNK:]
        ids_to_delete = [c.id for c in remove]
        print("Deleting excess creatures:", ids_to_delete)
        if ids_to_delete:
            db.query(models.Creature).filter(models.Creature.id.in_(ids_to_delete)).delete(synchronize_session=False)
            db.commit()
        collected = keep
    return collected

@app.websocket("/ws")
async def websocket_endpoint(websocket: WebSocket):
    await websocket.accept()
    watched_chunks = set()
    websocket_chunk_map[websocket] = watched_chunks
    print("WebSocket client connected")
    db = SessionLocal()
    try:
        while True:
            msg = await websocket.receive_text()
            if msg.startswith("get_chunk"):
                _, x_str, y_str = msg.split()
                chunk_x = int(x_str)
                chunk_y = int(y_str)

                now = time.time()
                chunk_key = (chunk_x, chunk_y)

                watched_chunks.add(chunk_key)

                if chunk_key not in active_chunks:
                    creatures = load_chunk(chunk_x, chunk_y, db)
                    rounded_creatures = [round_creature(CreatureOut.from_orm(c).dict()) for c in creatures]
                    active_chunks[chunk_key] = {'creatures': rounded_creatures, 'last_access': now, 'watchers': 1}
                    for c in active_chunks[chunk_key]["creatures"]:
                        c['reproduction_cooldown'] = c.get('reproduction_cooldown', 0)
                else:
                    active_chunks[chunk_key]['watchers'] += 1
                active_chunks[chunk_key]['last_access'] = now

                serialized_chunk = [round_creature(dict(c)) for c in active_chunks[chunk_key]['creatures']]
                for batch in chunk_batches(serialized_chunk):
                    msg_dict = {
                        "type": "chunk",
                        "chunk_x": chunk_x,
                        "chunk_y": chunk_y,
                        "creatures": batch["creatures"],
                        "batch_index": batch["batch_index"],
                        "batch_count": batch["batch_count"],
                    }
                    msg_json = json.dumps(msg_dict)
                    await websocket.send_text(msg_json)
            
            elif msg.startswith("unwatch_chunk"):
                _, x_str, y_str = msg.split()
                chunk_x, chunk_y = int(x_str), int(y_str)
                chunk_key = (chunk_x, chunk_y)
                if chunk_key in active_chunks:
                    active_chunks[chunk_key]['watchers'] = max(0, active_chunks[chunk_key]['watchers'] - 1)
                watched_chunks.discard(chunk_key)

    except Exception as e:
        print("WebSocket disconnected:", e)
        traceback.print_exc()

    finally:
        for chunk_key in watched_chunks:
            if chunk_key in active_chunks:
                active_chunks[chunk_key]['watchers'] = max(0, active_chunks[chunk_key]['watchers'] - 1)
        websocket_chunk_map.pop(websocket, None)
        db.close()
        print("database closed")

@app.on_event("startup")
async def start_simulation():
    asyncio.create_task(simulation_loop())

async def simulation_loop():
    while True:
        last_time = time.time()
        db = SessionLocal()
        try:
            now = asyncio.get_event_loop().time()
            for chunk_key, chunk_data in list(active_chunks.items()):
                if chunk_data['watchers'] > 0:
                    dead_ids = simulate_chunk(chunk_data['creatures'], db)
                    chunk_data['last_access'] = now
                    if 'dead_ids' not in chunk_data:
                        chunk_data['dead_ids'] = []
                    chunk_data['dead_ids'].extend(dead_ids)
                elif now - chunk_data['last_access'] > CHUNK_TIMEOUT:
                    save_chunk_to_db(chunk_key, chunk_data['creatures'], chunk_data.get('dead_ids', []))
                    del active_chunks[chunk_key]
            for websocket, watched_chunks in list(websocket_chunk_map.items()):
                for chunk_x, chunk_y in list(watched_chunks):
                    creatures = active_chunks.get((chunk_x, chunk_y), {}).get('creatures', [])
                    rounded_creatures = [round_creature(dict(c)) for c in creatures]
                    for batch in chunk_batches(rounded_creatures):
                        try:
                            await websocket.send_text(json.dumps({
                                "type": "chunk_update",
                                "chunk_x": chunk_x,
                                "chunk_y": chunk_y,
                                "creatures": batch["creatures"],
                                "batch_index": batch["batch_index"],
                                "batch_count": batch["batch_count"],
                                "dead_ids": chunk_data.get('dead_ids', [])
                            }))
                        except Exception as e:
                            print(f"Error sending chunk update to websocket: {e}")
                            websocket_chunk_map.pop(websocket, None)
        finally:
            db.close()
        elapsed = time.time() - last_time
        await asyncio.sleep(max(0, 0.8 - elapsed))
        if time.time() - last_time > 0.81:
            print("Simulation loop took too long: " + str(time.time()-last_time))

def local_density(x, y, creatures, radius=30):
    count = 0
    for c in creatures:
        if (c['x'] - x) ** 2 + (c['y'] - y) ** 2 < radius ** 2:
            count += 1
    return count

def simulate_chunk(creature_list, db):
    dead_ids = []
    new_creatures = []
    child_objs = []
    for i, c in enumerate(creature_list[:]):
        c['reproduction_cooldown'] = max(0, c.get('reproduction_cooldown', 0) - 0.5)
        if c['energy'] < REPRODUCTION_ENERGY_COST or c['reproduction_cooldown'] > 0:
            continue
        if can_spawn_in_chunk(int(c['x'] // 512), int(c['y'] // 512), db, MAX_CREATURES_PER_CHUNK) == False:
            continue

        eligible_mates = [
            mate for j, mate in enumerate(creature_list)
            if i != j and
               mate['energy'] >= REPRODUCTION_ENERGY_COST and
               mate.get('reproduction_cooldown', 0) <= 0 and
               (c['x'] - mate['x']) ** 2 + (c['y'] - mate['y']) ** 2 < REPRODUCTION_RADIUS**2
        ]
        if eligible_mates:
            mate = random.choice(eligible_mates)

            proposed_x = (c['x'] + mate['x']) / 2 + random.uniform(-10, 10)
            proposed_y = (c['y'] + mate['y']) / 2 + random.uniform(-10, 10)

            if local_density(proposed_x, proposed_y, creature_list, radius=50) > DENSITY_LIMIT:
                continue

            dx = c['x'] - mate['x']
            dy = c['y'] - mate['y']

            if dx*dx + dy*dy < REPRODUCTION_RADIUS**2:
                child_genes = {}
                for key in c['genes']:
                    gene_a = c['genes'][key]
                    gene_b = mate['genes'].get(key, gene_a)
                    avg = (gene_a + gene_b) / 2
                    mutation = random.uniform(-MUTATION_AMOUNT, MUTATION_AMOUNT)
                    mutated = avg + mutation
                    if key == "move_angle":
                        mutated = mutated % (2 * math.pi)
                    else:
                        mutated = min(max(mutated, 0), 1)
                    child_genes[key] = mutated
                parent_dist = ((c['x'] - mate['x']) ** 2 + (c['y'] - mate['y']) ** 2) ** 0.5
                jitter = max(10, parent_dist * 0.5)
                spawn_x = (c['x'] + mate['x']) / 2 + random.uniform(-jitter, jitter)
                spawn_y = (c['y'] + mate['y']) / 2 + random.uniform(-jitter, jitter)
                child_obj = Creature(
                    x=spawn_x,
                    y=spawn_y,
                    genes=child_genes,
                    energy=100.0,
                    generation=max(c.get("generation", 1), mate.get("generation", 1)) + 1
                )
                child_objs.append(child_obj)
                c['energy'] -= REPRODUCTION_ENERGY_COST / 2
                mate['energy'] -= REPRODUCTION_ENERGY_COST / 2
                c['reproduction_cooldown'] = REPRODUCTION_COOLDOWN_TIME
                mate['reproduction_cooldown'] = REPRODUCTION_COOLDOWN_TIME
                break

        move_angle = c['genes'].get('move_angle', random.uniform(0, 2 * math.pi))
        move_jitter = c['genes'].get('move_jitter', 0.2)
        speed = c['genes'].get('speed', 10.0)

        if random.random() < 0.1:
            move_angle += random.uniform(-move_jitter, move_jitter)
            if move_angle < 0:
                move_angle += 2 * math.pi
            elif move_angle > 2 * math.pi:
                move_angle -= 2 * math.pi
        
        c['genes']['move_angle'] = move_angle

        dx = math.cos(move_angle) * speed * 8
        dy = math.sin(move_angle) * speed * 8

        c['x'] += dx
        c['y'] += dy

        c['energy'] -= 0.4

        if c['energy'] <= 0:
            if 'id' in c:
                dead_ids.append(c['id'])
            creature_list.remove(c)
    
    if child_objs:
        db.add_all(child_objs)
        db.commit()
        for child_obj in child_objs:
            db.refresh(child_obj)
            child_dict = CreatureOut.from_orm(child_obj).dict()
            child_dict['reproduction_cooldown'] = REPRODUCTION_COOLDOWN_TIME
            new_creatures.append(child_dict)
    creature_list.extend(new_creatures)
    
    return dead_ids

def can_spawn_in_chunk(chunk_x, chunk_y, db, max_creatures):
    size = 512
    x_min, y_min = chunk_x * size, chunk_y * size
    x_max, y_max = x_min + size, y_min + size
    count = db.query(models.Creature).filter(
        models.Creature.x >= x_min,
        models.Creature.x < x_max,
        models.Creature.y >= y_min,
        models.Creature.y < y_max
    ).count()
    return count < max_creatures

def save_chunk_to_db(chunk_key, creature_list, dead_ids=None):
    if not creature_list and not dead_ids:
        return

    db = SessionLocal()
    try:
        update_data = []
        for c in creature_list:
            if 'id' in c:
                update_data.append({
                    "id": c["id"],
                    "x": c["x"],
                    "y": c["y"],
                    "genes": c["genes"],
                    "energy": c["energy"],
                })

        if update_data:
            db.bulk_update_mappings(Creature, update_data)
        if dead_ids:
            db.query(Creature).filter(Creature.id.in_(dead_ids)).delete(synchronize_session=False)
        db.commit()
    except Exception as e:
        print(f"Error saving chunk {chunk_key}: {e}")
        db.rollback()

    finally:
        db.close()

def chunk_batches(creatures):
    total = (len(creatures) + MAX_CREATURES_PER_MESSAGE - 1) // MAX_CREATURES_PER_MESSAGE
    for idx, i in enumerate(range(0, len(creatures), MAX_CREATURES_PER_MESSAGE)):
        yield {'batch_index': idx, 'batch_count': total, 'creatures': creatures[i:i+MAX_CREATURES_PER_MESSAGE]}

def round_creature(c):
    c['x'] = round(c['x'], 3)
    c['y'] = round(c['y'], 3)
    c['energy'] = round(c['energy'], 2)
    c['genes'] = {k: round(v, 4) for k, v in c['genes'].items()}
    return c
