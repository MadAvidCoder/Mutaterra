# Mutaterra
An infinite evolution focused creature simulation. Check out the global infinite canvas here: [https://madavidcoder.github.io/Mutaterra/](https://madavidcoder.github.io/Mutaterra/).

## Controls
Use arrow keys or drag to move around the (infinite) canvas. Scroll to zoom in and out. Press 'S' to spawn a random creature at the mouse location, and press 'F' to add food at the mouse location. You can click on a creature to view statistics and its genes. You can also tag it with a name, by editing its ID.

All creatures are synced to all clients via an authoritative backend, and information is stored in a database.

## Tech Stack
- Frontend Hosting: [Github Pages](https://pages.github.com/)
- Frontend: [Godot Engine](https://godotengine.org/)
- Communication: [Websockets](https://websocket.org/)
- Backend Server: [Fast API](https://fastapi.tiangolo.com/) ([Python](https://www.python.org/))
- Backend Database: [PostrgeSQL](https://www.postgresql.org/)
- Backend Hosting: [Nest](https://hackclub.app/)
