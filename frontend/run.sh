docker run --rm -it -p 127.0.0.1:8080:8080 -u=node:node -w /app -v "$(pwd):/app" --tmpfs /app/node_modules:exec,uid=1000,gid=1000 node:18-bullseye-slim sh -c "npm ci && npm start"
