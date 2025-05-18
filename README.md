# Overseer

This repository contains the Overseer GitHub Action along with a Docker setup
for running the action together with local MCP servers.

## Running with Docker Compose

Build and start the container which exposes the sequential-thinking, memory and
filesystem MCP servers on ports `7000-7005`:

```sh
docker-compose up --build
```

Once running, you can execute the action inside the container by invoking:

```sh
docker exec -it overseer_overseer_1 node dist/index.js
```

The action will reach the MCPs via `localhost`.
