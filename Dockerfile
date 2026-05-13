# ── Stage 1: builder ──────────────────────────────────────────────────────────
FROM node:20-alpine AS builder

WORKDIR /app

# Copiar solo los manifiestos primero (cache de capas)
COPY package*.json ./

# Instalar TODAS las dependencias (incluyendo devDependencies si las hubiera)
RUN npm install --omit=dev

# ── Stage 2: runtime ──────────────────────────────────────────────────────────
FROM node:20-alpine AS runtime

# Crear directorio de trabajo con permisos correctos
WORKDIR /app

# Copiar node_modules ya instalados desde el builder
COPY --from=builder /app/node_modules ./node_modules

# Copiar el código fuente
COPY src/ ./src/

# El usuario "node" ya viene en node:20-alpine — nunca root en producción
USER node

# Puerto que expone el servidor Express (ver .env.example: PORT=3000)
EXPOSE 3000

# Healthcheck: consulta el endpoint /health del propio servidor
# --start-period: le da 30s para que la BD levante antes de fallar
HEALTHCHECK --interval=15s --timeout=5s --start-period=30s --retries=3 \
  CMD wget -qO- http://localhost:3000/health || exit 1

CMD ["node", "src/server.js"]