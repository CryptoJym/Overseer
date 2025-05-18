# Build stage
FROM node:18-alpine AS builder
WORKDIR /app
COPY package.json ./
RUN npm install --production
COPY dist ./dist
COPY mcp ./mcp
COPY start.sh ./start.sh

# Runtime stage
FROM node:18-alpine
WORKDIR /app
COPY --from=builder /app /app
EXPOSE 7000 7001 7002 7003 7004 7005
CMD ["sh", "./start.sh"]
