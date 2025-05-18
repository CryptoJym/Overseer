# Overseer Action

This repository contains the compiled GitHub Action used by Overseer.

## VM Setup for Local Overseer Action

The `setup_overseer_vm.sh` script prepares a fresh VM with everything required to run the Overseer Action completely offline after installation. It installs Node.js, the Model Context Protocol (MCP) servers, configures them to start on boot using **pm2**, and optionally installs Docker.

### Usage

Run the following on a new machine while it still has internet access:

```bash
sudo ./setup_overseer_vm.sh
```

Environment variables can adjust the behaviour:

- `INSTALL_DOCKER` – set to `no` to skip Docker installation (default `yes`).
- `DOCKER_IMAGES` – space-separated list of Docker images to pull.

After the script completes, the MCP servers listen on ports 5000–5004. You can verify they are running by inspecting the pm2 process list or repeating the smoke tests:

```bash
pm2 ls
curl http://localhost:5000
```

Once set up, the machine can operate without internet access and still provide the MCP services required by the Overseer Action.
