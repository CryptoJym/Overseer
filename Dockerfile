FROM ghcr.io/openai/codex-universal:latest
ENV CODEX_ENV_NODE=18
RUN apt-get update && apt-get install -y nodejs npm && rm -rf /var/lib/apt/lists/*
WORKDIR /workspace
COPY package.json ./
RUN npm install
COPY . .
CMD ["bash"]
