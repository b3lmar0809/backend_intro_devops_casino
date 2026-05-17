# Casino Online Backend API

**Experiencia 2: Introducción a Herramientas DevOps (ISY1101)**

Plataforma backend para un casino online desarrollada con tecnologías modernas de containerización, orquestación de servicios, e implementación de prácticas DevOps. Este proyecto implementa una API REST escalable, segura y lista para deployment en infraestructura cloud (AWS EC2, ECR).

**Versión:** 1.0.0  
**Rama principal:** `dev`  
**Node.js:** v20 LTS  
**PostgreSQL:** 16+

---

## Tabla de Contenidos

1. [Stack Tecnológico](#stack-tecnológico)
2. [Estructura del Proyecto](#estructura-del-proyecto)
3. [Variables de Entorno](#variables-de-entorno)
4. [Endpoints API](#endpoints-api)
5. [Usuarios Demo y Seed](#usuarios-demo-y-seed)
6. [Ejecución Local](#ejecución-local)
7. [Containerización con Docker](#containerización-con-docker)
8. [Docker Compose](#docker-compose)
9. [Principios DevOps Implementados](#principios-devops-implementados)
10. [Seguridad](#seguridad)
11. [Deployment en AWS](#deployment-en-aws)
12. [CI/CD y GitHub Actions](#cicd-y-github-actions)
13. [Troubleshooting](#troubleshooting)
14. [Comandos Útiles](#comandos-útiles)
15. [Referencias Académicas](#referencias-académicas)

---

## Stack Tecnológico

| Tecnología | Versión | Propósito | Justificación |
|:---|:---:|:---|:---|
| **Node.js** | 20 LTS | Runtime JavaScript servidor | Ligero, alto rendimiento, ecosistema npm maduro |
| **Express** | 4.19.2+ | Framework web REST API | Minimalista, middleware pattern, flexible |
| **PostgreSQL** | 16+ | Base de datos relacional | ACID completo, transacciones, JSON, escalabilidad |
| **JWT** | 9.0.2+ | Autenticación stateless | Tokens seguros, no requiere sesión servidor |
| **bcryptjs** | 2.4.3+ | Hashing de contraseñas | Función adaptativa contra ataques de fuerza bruta |
| **pg** | 8.11.5+ | Cliente PostgreSQL | Pool de conexiones nativo, prepared statements |
| **CORS** | 2.8.5+ | Control de origen cruzado | Seguridad en cliente, configurable por entorno |
| **Docker** | 20.10+ | Containerización | Reproducibilidad, multi-stage builds, seguridad |
| **Docker Compose** | 1.29+ | Orquestación local | Ambiente dev integrado, mismo que producción |
| **Alpine Linux** | 3.18+ | Base image mínima | 5MB vs 800MB Debian, <5 vulnerabilidades |

---

## Estructura del Proyecto

```
casino-backend/
├── src/                               # Código fuente Node.js
│   ├── server.js                      # Bootstrap Express, CORS, rutas, healthcheck
│   │
│   ├── db/
│   │   ├── pool.js                    # Pool conexiones Postgres (10 máximo)
│   │   │                               # esperarBD(): reintentos hasta conectar
│   │   │                               # Conversión NUMERIC→float para JSON
│   │   │
│   │   └── seed.js                    # Usuarios demo (idempotente con ON CONFLICT)
│   │                                   # Hashing bcrypt con cost=10
│   │
│   ├── middleware/
│   │   └── auth.js                    # JWT: firmar() y requiereAuth middleware
│   │                                   # Extrae token de header Authorization
│   │                                   # Valida expiración (por defecto 8h)
│   │
│   ├── routes/
│   │   ├── auth.js                    # POST /register, POST /login
│   │   │                               # Validación mínimo 6 caracteres password
│   │   │                               # Retorna usuario + token JWT
│   │   │
│   │   ├── users.js                   # GET /me (perfil autenticado)
│   │   │                               # POST /me/depositar (transacción con BEGIN/COMMIT)
│   │   │
│   │   ├── games.js                   # POST /slots/jugar, /roulette/jugar, /blackjack/jugar
│   │   │                               # Manejo transaccional: debitar apuesta → calcular premio
│   │   │
│   │   └── transactions.js            # GET / (historial paginado, máx 200 registros)
│   │                                   # JOIN con tabla juegos para mostrar código
│   │
│   └── games/
│       ├── slots.js                   # 3 rodillos, 8 símbolos, pesos probabilísticos
│       │                               # Pago 50x para 7️⃣, hasta 5x para 🍒
│       │
│       ├── roulette.js                # Ruleta europea (0-36), 4 tipos apuestas
│       │                               # Pago 35:1 (número), 1:1 (color/paridad), 2:1 (docena)
│       │
│       └── blackjack.js               # Blackjack vs banca, hit/stand/doblar
│                                       # Soft 17 rule: banca se planta en 17
│
├── db/
│   └── init.sql                       # Schema Postgres (DDL + seed juegos)
│                                       # IF NOT EXISTS, para idempotencia
│
├── Dockerfile                         # Multi-stage: builder + runtime (node:20-alpine)
│                                       # Usuario non-root 'node'
│                                       # HEALTHCHECK con wget
│
├── package.json                       # Dependencias + scripts (start, dev)
│
├── .env.example                       # Plantilla variables entorno (NO commitear .env)
│
├── .gitignore                         # node_modules, .env, *.log, .claude/
│
└── README.md                          # Este archivo

```

### Descripción Detallada de Componentes

#### `src/server.js` — Bootstrap Express

- **Patrón 12-factor app:** Puerto, CORS_ORIGIN vienen de variables de entorno
- **Endpoint `/health`:** Verifica conectividad a BD; usado por Docker HEALTHCHECK y AWS ALB/ELB
- **Endpoint raíz `/`:** Metadatos API (versión, endpoints disponibles)
- **Middleware global:** CORS, JSON parsing (límite 1mb), error handler con 4 parámetros
- **Binding 0.0.0.0:** Obligatorio en contenedor; localhost solo escucha localmente

#### `src/db/pool.js` — Pool de Conexiones

- **Pool:** máximo 10 conexiones simultáneas (ajustar según CPU contenedor)
- **Timeout inactividad:** 30 segundos; conexiones viejas se reciclan automáticamente
- **Conversión NUMERIC:** Postgres NUMERIC→float para JSON (precision de 2 decimales en saldos)
- **esperarBD():** Reintentos exponenciales (2s × 30 = hasta 60s) esperando Postgres
- **Error handling:** Captura errores de clientes inactivos en el pool

#### `src/db/seed.js` — Seed Idempotente

**Usuarios demo con contraseñas seguras:**

| Usuario | Email | Contraseña | Saldo | Rol |
|:---|:---|:---|---:|:---|
| `demo` | demo@casino.test | demo1234 | $5000 | jugador |
| `jugador1` | jugador1@casino.test | demo1234 | $1000 | jugador |
| `admin` | admin@casino.test | admin1234 | $99999 | admin |

- **Idempotencia:** `ON CONFLICT (username) DO NOTHING` evita duplicados en reinicios
- **Hashing:** bcryptjs con cost=10 (toma ~100ms por usuario, seguro contra ataques GPU)
- **Timing:** Ejecuta al startup de server.js tras esperarBD()

#### `src/middleware/auth.js` — Autenticación JWT

- **Token:** Incluye `{ sub, username, rol }` (subject = user ID según estándar JWT)
- **Firma:** `HS256` con JWT_SECRET (variable entorno, nunca hardcodear)
- **Expiración:** Por defecto 8 horas (JWT_EXPIRES_IN)
- **Validación:** Extrae de header `Authorization: Bearer <token>`; retorna 401 si falta o es inválido
- **req.usuario:** Disponible en rutas protegidas gracias al middleware

#### `src/routes/auth.js` — Autenticación

**POST /api/auth/register**
```json
{
  "username": "nuevouser",
  "email": "user@example.com",
  "password": "mipassword123"
}
```
- Validación: password ≥6 caracteres, username/email únicos
- Respuesta 201: `{ usuario, token }`
- Código 409 (Conflict) si username/email existen

**POST /api/auth/login**
```json
{
  "username": "demo",
  "password": "demo1234"
}
```
- Valida credenciales con bcrypt.compare()
- Retorna usuario + token JWT válido 8h

#### `src/routes/users.js` — Perfil y Saldo

**GET /api/usuarios/me**
- Requiere JWT válido (middleware requiereAuth)
- Retorna: `{ id, username, email, saldo, rol, creado_en }`

**POST /api/usuarios/me/depositar**
```json
{ "monto": 500.00 }
```
- Validación: 0 < monto ≤ 100000
- **Transacción ACID:** BEGIN → UPDATE → INSERT transacción → COMMIT
- Rollback automático si falla

#### `src/routes/games.js` — Juegos y Apuestas

**POST /api/juegos/slots/jugar**
```json
{ "apuesta": 100.00 }
```
- Transacción: Debita apuesta → Ejecuta lógica slots → Acredita premio (si ganó)
- Respuesta: `{ resultado: { rodillos, premio, neto }, saldo }`

**POST /api/juegos/roulette/jugar**
```json
{
  "apuestas": [
    { "tipo": "numero", "valor": 17, "monto": 50 },
    { "tipo": "color", "valor": "rojo", "monto": 100 }
  ]
}
```
- Tipos: `numero` (35:1), `color` (1:1), `paridad` (1:1), `docena` (2:1)
- Transacción completa: debita total apuestado → resuelve → acredita retorno

**POST /api/juegos/blackjack/jugar**
```json
{ "apuesta": 200.00 }
```
- Devuelve estado inicial: `{ mazo, jugador, banca, apuesta, terminada, accion }`
- Cliente envía acciones: hit, stand, doble (en frontend/testing)

#### `src/routes/transactions.js` — Historial

**GET /api/transacciones?limit=50**
- Retorna últimas 50 transacciones (máximo 200)
- Campos: `id, tipo, monto, saldo_post, detalle, creada_en, juego` (code)
- Ordenado por fecha DESC

#### `src/games/{slots,roulette,blackjack}.js` — Lógica de Juegos

**Slots:**
- 3 rodillos con 8 símbolos: 🍒, 🍋, 🔔, ⭐, 💎, 7️⃣, 🍀, 🍇
- Pesos probabilísticos: 7️⃣ (6%), 🍇 (4%), etc.
- Pago 3 iguales: 50x (7️⃣), 25x (💎), 15x (⭐), hasta 5x (🍒)
- Pago 2 iguales: 1.5x la apuesta

**Ruleta:**
- 37 números (0-36); 18 rojos, 18 negros, 1 verde
- Tipos apuesta: número (36x), color/paridad (2x), docena (3x)
- Verde pierde todos los tipos (salvo apuestas en 0)

**Blackjack:**
- Mazo de 52 cartas; Fisher-Yates shuffle
- Soft 17: banca se detiene en 17 (no pide)
- Payouts: Blackjack (2.5x), Victoria (2x), Empate (1x), Pérdida (0x)

---

## Variables de Entorno

Todas las configuraciones sensibles se inyectan como variables de entorno siguiendo el **patrón 12-factor app**.

| Variable | Default | Descripción | Rango/Ejemplo | Contexto |
|:---|:---|:---|:---|:---|
| **PORT** | 3000 | Puerto HTTP del backend | 3000-65535 | local, docker, prod |
| **JWT_SECRET** | `cambiame-en-produccion` | Clave para firmar tokens JWT | 32+ caracteres, alfanuméricos | **CRÍTICO**: cambiar en prod |
| **JWT_EXPIRES_IN** | `8h` | Expiración tokens JWT | `8h`, `24h`, `7d` | dev/prod |
| **DB_HOST** | localhost | Hostname Postgres | `localhost`, `db` (docker), IP AWS | local/docker/prod |
| **DB_PORT** | 5432 | Puerto Postgres | 5432 | local/docker/prod |
| **DB_USER** | casino | Usuario conexión BD | cualquiera | local/docker/prod |
| **DB_PASSWORD** | casino | Contraseña BD | **CRÍTICO**: cambiar en prod | local/docker/prod |
| **DB_NAME** | casino_db | Nombre base de datos | casino_db | local/docker/prod |
| **CORS_ORIGIN** | * | Orígenes permitidos CORS | `*` (dev), `https://front.com` (prod) | dev/prod |

### Cómo Inyectar Variables

**Local (sin Docker):**
```bash
# Copiar plantilla
cp .env.example .env

# Editar .env (NO commitear)
PORT=3000
JWT_SECRET=mi_secreto_super_largo_32_caracteres_minimo
DB_HOST=localhost
...
```

**Docker Compose:**
```yaml
services:
  backend:
    environment:
      - PORT=3000
      - JWT_SECRET=${JWT_SECRET}  # desde archivo .env
      - DB_HOST=db
      - DB_PASSWORD=${DB_PASSWORD}
      - CORS_ORIGIN=http://localhost:3000
```

**AWS EC2 / ECS:**
```bash
docker run -e PORT=3000 \
           -e JWT_SECRET=... \
           -e DB_HOST=postgres.rds.amazonaws.com \
           ...
```

**AWS Secrets Manager:**
```bash
aws secretsmanager get-secret-value --secret-id casino/jwt-secret
# {JWT_SECRET="..."}
```

---

## Endpoints API

### Autenticación (`/api/auth`)

#### POST /api/auth/register

Crear nuevo usuario con saldo inicial $1000.

**Request:**
```json
{
  "username": "newuser",
  "email": "newuser@example.com",
  "password": "segurapassword123"
}
```

**Response (201 Created):**
```json
{
  "usuario": {
    "id": 4,
    "username": "newuser",
    "email": "newuser@example.com",
    "saldo": 1000.00,
    "rol": "jugador"
  },
  "token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..."
}
```

**Errores:**
- `400`: Falta username/email/password o password <6 caracteres
- `409`: username o email ya registrados
- `500`: Error servidor

---

#### POST /api/auth/login

Autenticar usuario existente.

**Request:**
```json
{
  "username": "demo",
  "password": "demo1234"
}
```

**Response (200 OK):**
```json
{
  "usuario": {
    "id": 1,
    "username": "demo",
    "email": "demo@casino.test",
    "saldo": 5000.00,
    "rol": "jugador"
  },
  "token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..."
}
```

**Errores:**
- `400`: Falta username o password
- `401`: Credenciales inválidas
- `500`: Error servidor

---

### Usuarios (`/api/usuarios`)

#### GET /api/usuarios/me

Obtener perfil del usuario autenticado.

**Headers:**
```
Authorization: Bearer <token>
```

**Response (200 OK):**
```json
{
  "id": 1,
  "username": "demo",
  "email": "demo@casino.test",
  "saldo": 5000.00,
  "rol": "jugador",
  "creado_en": "2024-05-17T10:30:00Z"
}
```

**Errores:**
- `401`: Token falta o inválido
- `404`: Usuario no encontrado
- `500`: Error servidor

---

#### POST /api/usuarios/me/depositar

Depositar dinero en la cuenta.

**Headers:**
```
Authorization: Bearer <token>
Content-Type: application/json
```

**Request:**
```json
{
  "monto": 500.00
}
```

**Response (200 OK):**
```json
{
  "saldo": 5500.00
}
```

**Errores:**
- `400`: monto inválido (≤0, >100000)
- `401`: Token inválido
- `500`: Error BD (rollback automático)

---

### Juegos (`/api/juegos`)

#### GET /api/juegos

Catálogo de juegos disponibles.

**Response (200 OK):**
```json
[
  {
    "id": 1,
    "codigo": "slots",
    "nombre": "Tragamonedas",
    "descripcion": "Maquina de 3 rodillos con 8 simbolos.",
    "apuesta_min": 10.00,
    "apuesta_max": 500.00
  },
  {
    "id": 2,
    "codigo": "roulette",
    "nombre": "Ruleta",
    "descripcion": "Ruleta europea: numero, color, par/impar, docena.",
    "apuesta_min": 10.00,
    "apuesta_max": 1000.00
  },
  {
    "id": 3,
    "codigo": "blackjack",
    "nombre": "Blackjack",
    "descripcion": "Cartas contra la banca. Hit, stand, doble.",
    "apuesta_min": 20.00,
    "apuesta_max": 2000.00
  }
]
```

---

#### POST /api/juegos/slots/jugar

Jugar a las tragamonedas.

**Headers:**
```
Authorization: Bearer <token>
```

**Request:**
```json
{
  "apuesta": 100.00
}
```

**Response (200 OK):**
```json
{
  "resultado": {
    "rodillos": ["7️⃣", "7️⃣", "7️⃣"],
    "apuesta": 100.00,
    "premio": 5000.00,
    "multiplicador": 50,
    "tipo": "tres-iguales",
    "neto": 4900.00
  },
  "saldo": 5900.00
}
```

**Errores:**
- `400`: apuesta inválida (<apuesta_min, >apuesta_max), saldo insuficiente
- `401`: Token inválido
- `404`: Juego no disponible
- `500`: Error transacción (rollback)

---

#### POST /api/juegos/roulette/jugar

Jugar a la ruleta.

**Request:**
```json
{
  "apuestas": [
    {
      "tipo": "numero",
      "valor": 17,
      "monto": 50.00
    },
    {
      "tipo": "color",
      "valor": "rojo",
      "monto": 100.00
    },
    {
      "tipo": "paridad",
      "valor": "par",
      "monto": 75.00
    }
  ]
}
```

**Response (200 OK - Ejemplo ganando número):**
```json
{
  "resultado": {
    "numero": 17,
    "color": "negro",
    "apuestas": [
      {
        "tipo": "numero",
        "valor": 17,
        "monto": 50.00,
        "gana": true,
        "retorno": 1800.00
      },
      {
        "tipo": "color",
        "valor": "rojo",
        "monto": 100.00,
        "gana": false,
        "retorno": 0.00
      },
      {
        "tipo": "paridad",
        "valor": "par",
        "monto": 75.00,
        "gana": false,
        "retorno": 0.00
      }
    ],
    "totalApostado": 225.00,
    "totalRetornado": 1800.00,
    "neto": 1575.00
  },
  "saldo": 6475.00
}
```

**Tipos Apuesta Válidos:**
| Tipo | Valor(es) | Pago | Ejemplo |
|:---|:---|:---:|:---|
| numero | 0-36 | 35:1 | `{"tipo":"numero","valor":17}` |
| color | "rojo" \| "negro" | 1:1 | `{"tipo":"color","valor":"rojo"}` |
| paridad | "par" \| "impar" | 1:1 | `{"tipo":"paridad","valor":"par"}` |
| docena | 1 \| 2 \| 3 | 2:1 | `{"tipo":"docena","valor":2}` |

---

#### POST /api/juegos/blackjack/jugar

Iniciar mano de blackjack.

**Request:**
```json
{
  "apuesta": 200.00
}
```

**Response (200 OK):**
```json
{
  "mazo": [
    {"valor": "3", "palo": "♠"},
    {"valor": "Q", "palo": "♥"},
    ...
  ],
  "jugador": [
    {"valor": "K", "palo": "♣"},
    {"valor": "8", "palo": "♥"}
  ],
  "banca": [
    {"valor": "6", "palo": "♠"},
    {"valor": "?", "palo": "?"}
  ],
  "apuesta": 200.00,
  "terminada": false,
  "accion": null
}
```

**Errores:**
- `400`: apuesta inválida
- `401`: Token inválido
- `404`: Juego no disponible
- `500`: Error transacción

---

### Transacciones (`/api/transacciones`)

#### GET /api/transacciones?limit=50

Historial de transacciones del usuario.

**Headers:**
```
Authorization: Bearer <token>
```

**Query Parameters:**
| Parámetro | Default | Máximo | Descripción |
|:---|:---:|:---:|:---|
| limit | 50 | 200 | Número de registros a retornar |

**Response (200 OK):**
```json
[
  {
    "id": 123,
    "tipo": "apuesta",
    "monto": -100.00,
    "saldo_post": 4900.00,
    "detalle": {
      "codigo": "slots"
    },
    "creada_en": "2024-05-17T15:45:30Z",
    "juego": "slots"
  },
  {
    "id": 124,
    "tipo": "premio",
    "monto": 5000.00,
    "saldo_post": 9900.00,
    "detalle": {
      "rodillos": ["7️⃣", "7️⃣", "7️⃣"],
      "premio": 5000.00
    },
    "creada_en": "2024-05-17T15:45:31Z",
    "juego": "slots"
  }
]
```

**Tipos Transacción:**
| Tipo | Descripción | Monto |
|:---|:---|:---|
| `apuesta` | Débito por apuesta | Negativo |
| `premio` | Crédito por premio ganado | Positivo |
| `deposito` | Depósito de dinero | Positivo |
| `retiro` | Retiro de dinero | Negativo |
| `ajuste` | Ajuste administrativo | Positivo/Negativo |

---

## Usuarios Demo y Seed

La función `sembrarUsuariosDemo()` se ejecuta automáticamente al startup del servidor, registrando usuarios de demostración con contraseñas seguras hasheadas.

### Usuarios Precargados

| Usuario | Email | Contraseña | Saldo Inicial | Rol | Propósito |
|:---|:---|:---|---:|:---|:---|
| `demo` | demo@casino.test | demo1234 | $5000.00 | jugador | Demo principal con saldo jugoso |
| `jugador1` | jugador1@casino.test | demo1234 | $1000.00 | jugador | Demo de jugador con saldo inicial |
| `admin` | admin@casino.test | admin1234 | $99999.00 | admin | Demo admin con saldo administrativo |

### Características del Seed

```javascript
// ON CONFLICT DO NOTHING → idempotente
INSERT INTO usuarios (...) VALUES (...)
ON CONFLICT (username) DO NOTHING
```

- **Idempotencia:** No falla ni duplica si usuarios ya existen (reinicios, redeploys)
- **Hashing seguro:** bcryptjs con cost=10 (~100ms por usuario)
- **Timing:** Ejecuta después de `esperarBD()` en server.js
- **Logging:** `[SEED] Usuarios demo verificados` en stdout

### Para Agregar Más Usuarios Demo

Editar `src/db/seed.js`:

```javascript
const DEMOS = [
  { username: 'demo',     email: 'demo@casino.test',     password: 'demo1234', saldo: 5000.00, rol: 'jugador' },
  { username: 'jugador1', email: 'jugador1@casino.test', password: 'demo1234', saldo: 1000.00, rol: 'jugador' },
  { username: 'admin',    email: 'admin@casino.test',    password: 'admin1234', saldo: 99999.00, rol: 'admin' },
  // Agregar aquí
  { username: 'vip',      email: 'vip@casino.test',      password: 'vip1234', saldo: 10000.00, rol: 'jugador' }
];
```

---

## Ejecución Local

### Requisitos Previos

- **Node.js 20+:** `node --version`
- **npm 10+:** `npm --version`
- **PostgreSQL 16+:** `psql --version` (o instalar localmente)

### Opción 1: Sin Docker (Node + Postgres locales)

#### 1.1 Clonar y Dependencias

```bash
git clone <repo-url> casino-backend
cd casino-backend
npm install
```

#### 1.2 Base de Datos

```bash
# Crear BD manualmente
psql -U postgres
CREATE DATABASE casino_db;
CREATE USER casino WITH PASSWORD 'casino';
ALTER ROLE casino CREATEDB;
\c casino_db
GRANT ALL PRIVILEGES ON DATABASE casino_db TO casino;
\i db/init.sql  # Ejecutar schema
\q
```

O usar script (Linux/Mac):
```bash
#!/bin/bash
psql -U postgres <<EOF
CREATE DATABASE casino_db;
CREATE USER casino WITH PASSWORD 'casino';
ALTER ROLE casino CREATEDB;
\c casino_db
GRANT ALL PRIVILEGES ON DATABASE casino_db TO casino;
\i $(pwd)/db/init.sql;
EOF
```

#### 1.3 Variables de Entorno

```bash
cp .env.example .env
# Editar .env si es necesario (defaults funcionan localmente)
cat .env
# PORT=3000
# DB_HOST=localhost
# ...
```

#### 1.4 Iniciar Servidor

```bash
npm start
# [API] Casino escuchando en http://0.0.0.0:3000

# O en modo desarrollo (nodemon + auto-reload)
npm run dev
```

#### 1.5 Verificar Salud

```bash
curl -X GET http://localhost:3000/health
# {"status":"ok","db":"up","uptime":12.345}
```

---

### Opción 2: Con Docker + Docker Compose (Recomendado)

#### 2.1 Construir Imagen

```bash
docker build -t casino-backend:latest .
# Dockerfile usa multi-stage:
#   Stage 1 (builder): npm install --omit=dev
#   Stage 2 (runtime): copia solo node_modules + src/
```

#### 2.2 Ejecutar Localmente

```bash
docker run -p 3000:3000 \
           -e PORT=3000 \
           -e DB_HOST=host.docker.internal \
           -e DB_USER=casino \
           -e DB_PASSWORD=casino \
           -e JWT_SECRET=dev-secret-32-characters-minimum \
           casino-backend:latest
```

**Nota:** `host.docker.internal` accede a Postgres en el host (macOS/Windows).

#### 2.3 Docker Compose (Full Stack)

Crear `docker-compose.yml`:

```yaml
version: '3.8'

services:
  # Backend Node.js
  backend:
    build:
      context: .
      dockerfile: Dockerfile
    container_name: casino-backend
    ports:
      - "3000:3000"
    environment:
      - PORT=3000
      - JWT_SECRET=dev-secret-casino-32-characters-min
      - DB_HOST=db
      - DB_PORT=5432
      - DB_USER=casino
      - DB_PASSWORD=casino
      - DB_NAME=casino_db
      - CORS_ORIGIN=http://localhost:3000
    depends_on:
      db:
        condition: service_healthy
    networks:
      - casino-network
    healthcheck:
      test: ["CMD", "wget", "-qO-", "http://localhost:3000/health"]
      interval: 15s
      timeout: 5s
      retries: 3
      start_period: 30s
    restart: unless-stopped

  # PostgreSQL 16
  db:
    image: postgres:16-alpine
    container_name: casino-db
    environment:
      - POSTGRES_PASSWORD=postgres
      - POSTGRES_USER=casino
      - POSTGRES_DB=casino_db
    volumes:
      - ./db/init.sql:/docker-entrypoint-initdb.d/01-init.sql
      - postgres_data:/var/lib/postgresql/data
    networks:
      - casino-network
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U casino -d casino_db"]
      interval: 10s
      timeout: 5s
      retries: 5
    restart: unless-stopped

networks:
  casino-network:
    driver: bridge

volumes:
  postgres_data:
    driver: local
```

Ejecutar:

```bash
docker-compose up -d

# Verificar servicios
docker-compose ps
# NAME              STATUS
# casino-backend    Up (healthy)
# casino-db         Up (healthy)

# Ver logs
docker-compose logs -f backend
docker-compose logs -f db

# Detener
docker-compose down

# Detener y eliminar volúmenes (CUIDADO: borra datos)
docker-compose down -v
```

---

## Containerización con Docker

### Dockerfile Multietapa

El `Dockerfile` implementa **multi-stage build** para optimizar la imagen final.

```dockerfile
# Etapa 1: Builder (compilación)
FROM node:20-alpine AS builder
WORKDIR /app
COPY package*.json ./
RUN npm install --omit=dev
# node_modules se queda en esta capa

# Etapa 2: Runtime (imagen final)
FROM node:20-alpine AS runtime
WORKDIR /app
COPY --from=builder /app/node_modules ./node_modules
COPY src/ ./src/

# Usuario no-root por seguridad
USER node

# Puerto que expone
EXPOSE 3000

# Health check (verifica conectividad)
HEALTHCHECK --interval=15s --timeout=5s --start-period=30s --retries=3 \
  CMD wget -qO- http://localhost:3000/health || exit 1

# Comando ejecución
CMD ["node", "src/server.js"]
```

### Ventajas Multi-Stage

| Aspecto | Beneficio |
|:---|:---|
| **Tamaño imagen** | Final ~150MB (sin builder devdeps) vs ~250MB sin multistage |
| **Seguridad** | Solo código + runtime necesario; sin herramientas compilación |
| **Velocidad build** | Builder cachea npm install; cambios src no invalidan cache |
| **Mantenibilidad** | Separación clara: compilación vs distribución |

### Seguridad en Dockerfile

| Práctica | Implementación |
|:---|:---|
| **Usuario no-root** | `USER node` (gid 1000, uid 1000) |
| **Base Alpine** | `node:20-alpine` (5MB vs 800MB Debian) |
| **Vulnerabilidades mínimas** | Alpine <5 CVEs vs Debian >20 |
| **.dockerignore** | Excluir node_modules, .git, .env, logs |
| **HEALTHCHECK** | Endpoint `/health` verifica servicio listo |

### .dockerignore

```
node_modules
package-lock.json
.env
.env.example
.git
.gitignore
.DS_Store
*.log
npm-debug.log*
coverage
.claude/
CLAUDE.md
README.md
.git
```

### Construir Imagen

```bash
# Build normal
docker build -t casino-backend:1.0.0 .

# Build sin caché (fuerza rebuild)
docker build --no-cache -t casino-backend:1.0.0 .

# Build con tag latest
docker build -t casino-backend:latest .

# Multi-architecture (AMD64 + ARM64 para Mac M1)
docker buildx build --platform linux/amd64,linux/arm64 \
  -t casino-backend:latest .
```

### Ejecutar Contenedor

```bash
# Puerto local 3000 → contenedor 3000
docker run -p 3000:3000 \
           -e PORT=3000 \
           -e JWT_SECRET=mi_secreto \
           -e DB_HOST=postgres \
           casino-backend:latest

# Modo background con logs
docker run -d \
           -p 3000:3000 \
           --name casino-api \
           -e PORT=3000 \
           casino-backend:latest

docker logs -f casino-api

# Con volumen para logs (persist)
docker run -d \
           -v $(pwd)/logs:/app/logs \
           -e LOG_DIR=/app/logs \
           casino-backend:latest
```

---

## Docker Compose

La configuración `docker-compose.yml` define todo el stack local: backend, DB, redes, volúmenes.

### Características Principales

#### 1. Servicio Backend

```yaml
backend:
  build:
    context: .
    dockerfile: Dockerfile
  ports:
    - "3000:3000"  # Mapeo puerto host → contenedor
  environment:
    - DB_HOST=db   # Nombre servicio docker-compose
    - DB_NAME=casino_db
  depends_on:
    db:
      condition: service_healthy  # Espera a que db sea healthy
  healthcheck:
    test: ["CMD", "wget", "-qO-", "http://localhost:3000/health"]
    interval: 15s
    timeout: 5s
    retries: 3
    start_period: 30s
```

#### 2. Servicio PostgreSQL

```yaml
db:
  image: postgres:16-alpine
  environment:
    - POSTGRES_USER=casino
    - POSTGRES_PASSWORD=casino
    - POSTGRES_DB=casino_db
  volumes:
    - ./db/init.sql:/docker-entrypoint-initdb.d/01-init.sql
    - postgres_data:/var/lib/postgresql/data
  healthcheck:
    test: ["CMD-SHELL", "pg_isready -U casino"]
    interval: 10s
    timeout: 5s
    retries: 5
```

**Volúmenes:**
- **Bind mount:** `./db/init.sql` → `/docker-entrypoint-initdb.d/` (ejecuta schema al init)
- **Named volume:** `postgres_data` → `/var/lib/postgresql/data` (persiste datos)

#### 3. Red Bridge

```yaml
networks:
  casino-network:
    driver: bridge
```

- **Comunicación:** `backend` accede a `db` como `db:5432` (DNS interno Docker)
- **Aislamiento:** Red privada, no accesible desde otros contenedores en el host
- **Resolución DNS:** Docker daemon proporciona DNS para nombres de servicios

#### 4. Ciclo Vida

```bash
# Iniciar (crea redes, volúmenes, contenedores)
docker-compose up -d

# Detener (pausa contenedores)
docker-compose stop

# Reanudar
docker-compose start

# Reiniciar
docker-compose restart

# Detener y eliminar contenedores (volúmenes persisten)
docker-compose down

# Eliminar TODO incluyendo volúmenes (DESTRUYE datos)
docker-compose down -v

# Ver estado
docker-compose ps

# Ejecutar comando en contenedor activo
docker-compose exec backend npm run dev
docker-compose exec db psql -U casino -d casino_db
```

#### 5. Troubleshooting Docker Compose

```bash
# Ver logs todos los servicios
docker-compose logs -f

# Ver logs específico servicio
docker-compose logs -f backend
docker-compose logs -f db

# Ingresar bash backend
docker-compose exec backend bash
npm test

# Ingresar psql directamente
docker-compose exec db psql -U casino -d casino_db
SELECT * FROM usuarios;

# Ver configuración final (con sustituciones)
docker-compose config

# Validar sintaxis yaml
docker-compose config --quiet
```

---

## Principios DevOps Implementados

### 1. 12-Factor App

| Factor | Implementación |
|:---|:---|
| **I. Codebase** | Un repo Git; rama dev para desarrollo |
| **II. Dependencies** | package.json explícito; npm install aislado |
| **III. Config** | Variables entorno (JWT_SECRET, DB_HOST, etc.) |
| **IV. Backing Services** | PostgreSQL como servicio externo (DB_HOST variable) |
| **V. Build/Run** | Dockerfile separa etapas; npm install una sola vez |
| **VI. Processes** | Stateless: sin sesiones en memoria; JWT para estado |
| **VII. Port Binding** | Express auto-contiene; no requiere web server externo |
| **VIII. Concurrency** | Pool conexiones (10 máx); múltiples procesos node |
| **IX. Disposability** | Startup rápido (~2s); graceful shutdown con SIGTERM |
| **X. Dev/Prod Parity** | Docker Compose local ≈ AWS EC2 en prod |
| **XI. Logs** | stdout/stderr (docker logs); sin archivos locales |
| **XII. Admin Tasks** | seeders y migrations via code (idempotentes) |

### 2. Healthcheck y Liveness

**Endpoint `/health`:**
```javascript
app.get('/health', async (req, res) => {
  try {
    await pool.query('SELECT 1');
    res.json({ status: 'ok', db: 'up', uptime: process.uptime() });
  } catch (err) {
    res.status(503).json({ status: 'degraded', db: 'down' });
  }
});
```

**Docker HEALTHCHECK:**
```dockerfile
HEALTHCHECK --interval=15s --timeout=5s --start-period=30s --retries=3 \
  CMD wget -qO- http://localhost:3000/health || exit 1
```

**AWS ALB (Load Balancer):**
```
Health check: GET /health
Interval: 15 segundos
Timeout: 5 segundos
Healthy threshold: 2 (2 checks exitosos = healthy)
Unhealthy threshold: 3 (3 checks fallidos = reemplazar instancia)
```

### 3. Persistencia de Datos

**PostgreSQL:**
- **Volumen named:** `postgres_data:/var/lib/postgresql/data`
- **Persiste entre:** `docker-compose down` (sin `-v`)
- **Estrategia backup:** WAL (Write-Ahead Logging) automático en Postgres

**Transacciones ACID:**
```javascript
// Depósito: BEGIN → UPDATE → INSERT → COMMIT / ROLLBACK
const client = await pool.connect();
try {
  await client.query('BEGIN');
  await client.query('UPDATE usuarios SET saldo = saldo + $1', [monto]);
  await client.query('INSERT INTO transacciones ...', [...]);
  await client.query('COMMIT');
} catch (err) {
  await client.query('ROLLBACK');
  throw err;
}
```

### 4. Seed Idempotente

```javascript
INSERT INTO usuarios (username, ...) VALUES (...)
ON CONFLICT (username) DO NOTHING;
```

- **Idempotencia:** Múltiples ejecuciones = mismo resultado
- **Reinicio contenedor:** No duplica usuarios ni falla
- **Redeploy automático:** Seed se ejecuta; usuarios demo ya existen

### 5. Connection Pool

```javascript
const pool = new Pool({
  max: 10,  // máximo conexiones simultáneas
  idleTimeoutMillis: 30000,  // reciclaje después 30s inactividad
});
```

- **Eficiencia:** Reutiliza conexiones; no crea una por request
- **Escalabilidad:** 10 conexiones soportan ~100 requests concurrentes
- **Seguridad:** Retirada automática de conexiones viejas

### 6. Conversión NUMERIC → JSON

```javascript
types.setTypeParser(1700, (v) => v === null ? null : parseFloat(v));
```

- **Problema:** Postgres retorna NUMERIC como string (para precisión)
- **Solución:** Convertir a float para JSON
- **Riesgo:** Pérdida de precisión a partir de ~15 dígitos (aceptable para saldos)

---

## Seguridad

### 1. Autenticación JWT

| Aspecto | Detalle |
|:---|:---|
| **Algoritmo** | HS256 (HMAC-SHA256) |
| **Payload** | `{ sub: userId, username, rol }` |
| **Expiración** | 8 horas (por defecto) |
| **Secret** | Debe tener ≥32 caracteres; variar en dev/prod |
| **Transmisión** | Header `Authorization: Bearer <token>` |
| **Validación** | Cada ruta protegida verifica firma y expiración |

### 2. Hashing de Contraseñas

```javascript
const hash = await bcrypt.hash(password, 10);
const ok = await bcrypt.compare(password, hash);
```

| Parámetro | Valor | Propósito |
|:---|:---:|:---|
| **Cost** | 10 | ~100ms por hash; protege contra ataques GPU |
| **Algoritmo** | bcrypt | Adaptativo: futuro costmore tiempo a medida que CPUs mejoren |
| **Salt** | Autogenerado | Único por usuario; rainbow tables inútiles |

### 3. Validación de Input

```javascript
// Contraseña
if (password.length < 6) return res.status(400).json(...);

// Apuesta
const monto = Number(req.body?.monto);
if (!monto || monto <= 0 || monto > 100000) return res.status(400).json(...);

// Rango apuesta en juego
if (monto < Number(juego.apuesta_min) || monto > Number(juego.apuesta_max)) {
  throw error;
}
```

### 4. CORS Configurado

```javascript
const corsOrigin = process.env.CORS_ORIGIN || '*';
app.use(cors({
  origin: corsOrigin === '*' ? true : corsOrigin.split(',').map(s => s.trim())
}));
```

**Desarrollo:** `CORS_ORIGIN=*`  
**Producción:** `CORS_ORIGIN=https://frontend.example.com`

### 5. Rate Limiting (Recomendado para Producción)

No implementado aún, pero agregar para prevenir ataques de fuerza bruta:

```javascript
const rateLimit = require('express-rate-limit');

const loginLimiter = rateLimit({
  windowMs: 15 * 60 * 1000,  // 15 minutos
  max: 5,  // 5 intentos
  message: 'Demasiados intentos de login'
});

app.post('/api/auth/login', loginLimiter, async (req, res) => { ... });
```

### 6. Secrets Management (AWS)

**En AWS EC2 con Secrets Manager:**

```bash
# Crear secret
aws secretsmanager create-secret --name casino/jwt-secret \
  --secret-string "mi_secreto_32_caracteres_minimo"

# Inyectar en instancia EC2
export JWT_SECRET=$(aws secretsmanager get-secret-value \
  --secret-id casino/jwt-secret \
  --query SecretString \
  --output text)

docker run -e JWT_SECRET=$JWT_SECRET casino-backend
```

### 7. HTTPS/TLS (AWS)

**Con ALB (Application Load Balancer):**

```
ALB:443 (HTTPS con certificado ACM) → EC2:3000 (HTTP local)
```

- **Certificado:** AWS Certificate Manager (gratuito)
- **Encriptación:** HTTPS entre cliente y ALB; HTTP local seguro en VPC privada

---

## Deployment en AWS

### Arquitectura Objetivo

```
┌─────────────────────────────────────────────────────┐
│               Internet (HTTPS)                      │
└────────────────────┬────────────────────────────────┘
                     │
        ┌────────────▼─────────────┐
        │  AWS Certificate Manager │
        │  + Route53 (DNS)         │
        └────────────┬─────────────┘
                     │
   ┌─────────────────▼──────────────────────┐
   │  Application Load Balancer (ALB)       │
   │  Listener: 443 → target port 3000      │
   │  Health check: GET /health             │
   └─────────────────┬──────────────────────┘
                     │
        ┌────────────▼────────────┐
        │      VPC (10.0.0.0/16)  │
        │                         │
        │  Subnet Pública         │
        │  (10.0.1.0/24)          │
        │  ┌──────────────────┐   │
        │  │ EC2 backend      │   │
        │  │ (t3.small)       │   │
        │  │ Security Group:  │   │
        │  │  - 3000/TCP in   │   │
        │  │    (from ALB)    │   │
        │  └──────────────────┘   │
        │                         │
        │  Subnet Privada         │
        │  (10.0.2.0/24)          │
        │  ┌──────────────────┐   │
        │  │ RDS PostgreSQL   │   │
        │  │ (db.t3.small)    │   │
        │  │ Security Group:  │   │
        │  │  - 5432 (from    │   │
        │  │    public SG)    │   │
        │  └──────────────────┘   │
        │                         │
        └─────────────────────────┘
```

### 1. VPC y Subnets

```bash
# VPC
aws ec2 create-vpc --cidr-block 10.0.0.0/16 \
  --tag-specifications 'ResourceType=vpc,Tags=[{Key=Name,Value=casino-vpc}]'
# VPC_ID: vpc-xxxxx

# Subnet Pública (para EC2 frontend/backend)
aws ec2 create-subnet --vpc-id vpc-xxxxx \
  --cidr-block 10.0.1.0/24 \
  --availability-zone us-east-1a \
  --tag-specifications 'ResourceType=subnet,Tags=[{Key=Name,Value=casino-public}]'
# SUBNET_PUBLIC: subnet-xxxxx

# Subnet Privada (para RDS)
aws ec2 create-subnet --vpc-id vpc-xxxxx \
  --cidr-block 10.0.2.0/24 \
  --availability-zone us-east-1b \
  --tag-specifications 'ResourceType=subnet,Tags=[{Key=Name,Value=casino-private}]'
# SUBNET_PRIVATE: subnet-yyyyy
```

### 2. EC2 Backend

**Lanzar instancia:**

```bash
aws ec2 run-instances \
  --image-id ami-0c55b159cbfafe1f0 \
  --instance-type t3.small \
  --subnet-id subnet-xxxxx \
  --security-group-ids sg-xxxxx \
  --iam-instance-profile Name=EC2-Docker-Role \
  --user-data file://user-data.sh \
  --tag-specifications 'ResourceType=instance,Tags=[{Key=Name,Value=casino-backend}]'
```

**user-data.sh:**

```bash
#!/bin/bash
set -e

# Update y Docker
sudo yum update -y
sudo yum install -y docker git

# Iniciar Docker
sudo systemctl start docker
sudo usermod -aG docker ec2-user

# Clonar repo y ejecutar con Docker Compose
cd /home/ec2-user
git clone https://github.com/usuario/casino-backend.git
cd casino-backend

# Variables de entorno desde Secrets Manager
export JWT_SECRET=$(aws secretsmanager get-secret-value \
  --secret-id casino/jwt-secret --query SecretString --output text)
export DB_PASSWORD=$(aws secretsmanager get-secret-value \
  --secret-id casino/db-password --query SecretString --output text)

# Iniciar servicios
docker-compose -f docker-compose.prod.yml up -d
```

### 3. RDS PostgreSQL

```bash
# Crear subnet group
aws rds create-db-subnet-group \
  --db-subnet-group-name casino-db-subnet \
  --db-subnet-group-description "Subnets privadas para casino DB" \
  --subnet-ids subnet-xxxxx subnet-yyyyy

# Crear DB
aws rds create-db-instance \
  --db-instance-identifier casino-prod-db \
  --db-instance-class db.t3.small \
  --engine postgres \
  --engine-version 16.0 \
  --master-username casino \
  --master-user-password $(aws secretsmanager get-random-password --query RandomPassword --output text) \
  --db-name casino_db \
  --db-subnet-group-name casino-db-subnet \
  --vpc-security-group-ids sg-private-xxxxx \
  --storage-encrypted \
  --backup-retention-period 7
```

### 4. Application Load Balancer

```bash
# Crear target group
aws elbv2 create-target-group \
  --name casino-backend-tg \
  --protocol HTTP \
  --port 3000 \
  --vpc-id vpc-xxxxx \
  --health-check-path /health \
  --health-check-interval-seconds 15 \
  --health-check-timeout-seconds 5 \
  --healthy-threshold-count 2 \
  --unhealthy-threshold-count 3

# Registrar EC2 en target group
aws elbv2 register-targets \
  --target-group-arn arn:aws:elasticloadbalancing:... \
  --targets Id=i-xxxxx

# Crear ALB
aws elbv2 create-load-balancer \
  --name casino-alb \
  --subnets subnet-public-1 subnet-public-2 \
  --security-groups sg-alb-xxxxx \
  --scheme internet-facing \
  --type application
```

### 5. Secrets Manager

```bash
# JWT Secret
aws secretsmanager create-secret \
  --name casino/jwt-secret \
  --secret-string "super-secreto-32-caracteres-minimo-aleatorio"

# DB Password
aws secretsmanager create-secret \
  --name casino/db-password \
  --secret-string "contraseña-postgres-fuerte-aqui"

# Usar en aplicación
export JWT_SECRET=$(aws secretsmanager get-secret-value --secret-id casino/jwt-secret --query SecretString --output text)
```

### 6. CloudWatch Monitoring

```bash
# Habilitar logs
aws logs create-log-group --log-group-name /casino/backend
aws logs create-log-stream --log-group-name /casino/backend --log-stream-name prod

# Docker push logs a CloudWatch
docker run --log-driver awslogs \
  --log-opt awslogs-group=/casino/backend \
  --log-opt awslogs-region=us-east-1 \
  casino-backend:latest
```

---

## CI/CD y GitHub Actions

### Estrategia de Ramas

```
main (producción)
  ↑
  └─ pull request (requiere review + tests pass)

dev (desarrollo)
  ↑
  └─ feature/readme, feature/auth-2fa, etc.
       ↑
       └─ git checkout -b feature/readme
          (trabajo local)
          git push origin feature/readme
          → pull request a dev
```

### GitHub Actions Workflow Recomendado

**Crear `.github/workflows/test-and-build.yml`:**

```yaml
name: Test, Build & Deploy

on:
  push:
    branches: [dev, main]
  pull_request:
    branches: [dev, main]

jobs:
  test:
    runs-on: ubuntu-latest
    services:
      postgres:
        image: postgres:16-alpine
        env:
          POSTGRES_USER: casino
          POSTGRES_PASSWORD: casino
          POSTGRES_DB: casino_db
        options: >-
          --health-cmd pg_isready
          --health-interval 10s
          --health-timeout 5s
          --health-retries 5
        ports:
          - 5432:5432

    steps:
      - uses: actions/checkout@v3

      - name: Setup Node.js
        uses: actions/setup-node@v3
        with:
          node-version: '20'
          cache: 'npm'

      - name: Install dependencies
        run: npm install

      - name: Run linter (ESLint)
        run: npm run lint --if-present

      - name: Run tests
        run: npm test --if-present
        env:
          DB_HOST: localhost
          DB_USER: casino
          DB_PASSWORD: casino
          DB_NAME: casino_db

  build:
    needs: test
    runs-on: ubuntu-latest
    if: github.event_name == 'push' && (github.ref == 'refs/heads/dev' || github.ref == 'refs/heads/main')

    steps:
      - uses: actions/checkout@v3

      - name: Set up Docker Buildx
        uses: docker/setup-buildx-action@v2

      - name: Login to Docker Hub
        uses: docker/login-action@v2
        with:
          username: ${{ secrets.DOCKER_USERNAME }}
          password: ${{ secrets.DOCKER_PASSWORD }}

      - name: Login to ECR
        uses: aws-actions/amazon-ecr-login@v1
        with:
          registry-type: private

      - name: Build and push Docker image
        uses: docker/build-push-action@v4
        with:
          context: .
          push: true
          tags: |
            ${{ secrets.DOCKER_USERNAME }}/casino-backend:${{ github.sha }}
            ${{ secrets.DOCKER_USERNAME }}/casino-backend:latest
            ${{ secrets.ECR_REGISTRY }}/casino-backend:${{ github.sha }}
          cache-from: type=registry,ref=${{ secrets.DOCKER_USERNAME }}/casino-backend:buildcache
          cache-to: type=registry,ref=${{ secrets.DOCKER_USERNAME }}/casino-backend:buildcache,mode=max

  deploy:
    needs: build
    runs-on: ubuntu-latest
    if: github.event_name == 'push' && github.ref == 'refs/heads/main'

    steps:
      - uses: actions/checkout@v3

      - name: Deploy to AWS EC2
        uses: appleboy/ssh-action@master
        with:
          host: ${{ secrets.EC2_HOST }}
          username: ec2-user
          key: ${{ secrets.EC2_SSH_KEY }}
          script: |
            cd /home/ec2-user/casino-backend
            git pull origin main
            export JWT_SECRET=$(aws secretsmanager get-secret-value --secret-id casino/jwt-secret --query SecretString --output text)
            docker-compose -f docker-compose.prod.yml up -d
            docker-compose logs -f
```

**Secrets requeridos:**
- `DOCKER_USERNAME`: tu_usuario_dockerhub
- `DOCKER_PASSWORD`: token_dockerhub
- `ECR_REGISTRY`: AWS ECR registry URL
- `EC2_HOST`: IP pública EC2
- `EC2_SSH_KEY`: Clave privada SSH EC2

---

## Troubleshooting

### Problemas Comunes

| Problema | Síntoma | Causa | Solución |
|:---|:---|:---|:---|
| **Backend no conecta a BD** | `Error: connect ECONNREFUSED 127.0.0.1:5432` | DB_HOST=localhost en contenedor, pero Postgres en host | Cambiar DB_HOST=db (docker-compose) o host.docker.internal (Docker Desktop) |
| **Port 3000 ya en uso** | `Error: listen EADDRINUSE :::3000` | Otro proceso usando puerto 3000 | `lsof -i :3000` y kill PID, o cambiar PORT env var |
| **Healthcheck fallido** | Contenedor restarta cada 15s | `/health` retorna 503 (BD caída) | Verificar BD está activa: `docker-compose logs db` |
| **JWT_SECRET inválido en prod** | Token creation falla silenciosamente | Variable no inyectada en docker run | Verificar `docker inspect casino-backend \| grep JWT_SECRET` |
| **Volumen Postgres sin datos** | BD vacía tras restart | Volumen no configurado en docker-compose | Agregar `volumes: postgres_data:` y mount en `/var/lib/postgresql/data` |
| **npm install lentísimo** | Build tarda >2 minutos | npm descarga del registry global | Usar npm ci (offline) o registry privado; cachear en CI/CD |
| **Usuarios demo no crean tokens** | `req.usuario undefined` | seed.js falló silenciosamente | Ver logs: `docker logs casino-backend \| grep SEED` |
| **CORS error en frontend** | Browser bloquea requests | CORS_ORIGIN no incluye dominio frontend | Cambiar `CORS_ORIGIN=http://localhost:3001` (frontend) |
| **Memoria agotada en contenedor** | OOMKilled, exit code 137 | Pool conexiones × procesos Node × objetos grandes | Limitar memory en docker-compose: `memory: 512m` |
| **Transacción cuelga | Request timeout tras 30s | Connection pool exhausto (max=10, 10 requests concurrentes) | Aumentar max en pool.js o investigar queries lentas |

---

## Comandos Útiles

### Docker

```bash
# Construir imagen
docker build -t casino-backend:latest .

# Ejecutar contenedor
docker run -p 3000:3000 casino-backend:latest

# Ver logs en tiempo real
docker logs -f casino-backend

# Acceder bash dentro del contenedor
docker exec -it casino-backend bash

# Ver procesos en contenedor
docker top casino-backend

# Inspeccionar variables de entorno
docker inspect casino-backend | grep -A 20 Env

# Eliminar contenedor
docker rm casino-backend

# Eliminar imagen
docker rmi casino-backend:latest
```

### Docker Compose

```bash
# Iniciar servicios
docker-compose up -d

# Ver estado servicios
docker-compose ps

# Ver logs todos los servicios
docker-compose logs -f

# Ver logs específico servicio
docker-compose logs -f backend
docker-compose logs -f db

# Detener servicios
docker-compose stop

# Reiniciar servicios
docker-compose restart

# Eliminar contenedores (persisten volúmenes)
docker-compose down

# Eliminar TODO
docker-compose down -v

# Ejecutar comando en servicio
docker-compose exec backend bash
docker-compose exec db psql -U casino -d casino_db
```

### PostgreSQL

```bash
# Ingresar psql interactivo
docker-compose exec db psql -U casino -d casino_db

# Listar tablas
\dt

# Ver esquema tabla
\d usuarios

# Ejecutar query
SELECT * FROM usuarios;

# Ver índices
\di

# Backup BD
docker-compose exec db pg_dump -U casino casino_db > backup.sql

# Restaurar BD
cat backup.sql | docker-compose exec -T db psql -U casino -d casino_db
```

### npm

```bash
# Instalar dependencias
npm install

# Instalar dependencia específica
npm install express@4.19.2

# Instalar dev dependency
npm install --save-dev jest

# Ver dependencias instaladas
npm ls

# Buscar vulnerabilidades
npm audit

# Arreglar vulnerabilidades automáticamente
npm audit fix

# Ejecutar script
npm start
npm run dev

# Eliminar node_modules
rm -rf node_modules package-lock.json
npm install --ci
```

### Git

```bash
# Crear rama feature
git checkout -b feature/readme

# Ver cambios antes de commit
git diff

# Agregar cambios
git add README.md

# Commit
git commit -m "docs: actualizar README con documentación completa"

# Ver commits
git log --oneline

# Push rama a origin
git push origin feature/readme

# Pull request (en GitHub web)

# Después merge, limpiar rama local
git checkout dev
git pull origin dev
git branch -d feature/readme
```

### Debugging

```bash
# Ver health endpoint
curl -X GET http://localhost:3000/health

# Login (obtener token)
curl -X POST http://localhost:3000/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{"username":"demo","password":"demo1234"}'

# Usar token para perfil
TOKEN="eyJ..."
curl -X GET http://localhost:3000/api/usuarios/me \
  -H "Authorization: Bearer $TOKEN"

# Ver logs Node.js con timestamps
NODE_DEBUG=* npm start

# Debug breakpoints (inspect)
node --inspect src/server.js
# Luego: chrome://inspect
```

---

## Referencias Académicas

### Documentación Oficial

- **Express.js:** https://expressjs.com/
- **PostgreSQL:** https://www.postgresql.org/docs/
- **Docker:** https://docs.docker.com/
- **Docker Compose:** https://docs.docker.com/compose/
- **JWT:** https://jwt.io/
- **Node.js Pool (pg):** https://node-postgres.com/
- **AWS EC2:** https://docs.aws.amazon.com/ec2/

### Libros Recomendados

- **"The Twelve-Factor App"** - https://12factor.net/
- **"Docker in Action"** - Jeff Nickoloff & Stephen Kuenzli
- **"Kubernetes in Action"** - Marko Lukša
- **"DevOps Handbook"** - Gene Kim, Jez Humble, Patrick Debois, John Willis

### Cursos

- **Linux Academy:** Docker & Kubernetes paths
- **Pluralsight:** AWS & DevOps specializations
- **Udemy:** Complete Docker Course (Bhagirath Bosewar)

### Best Practices

- **OWASP Top 10:** https://owasp.org/www-project-top-ten/
- **Docker Security:** https://docs.docker.com/engine/security/
- **PostgreSQL Security:** https://www.postgresql.org/docs/16/sql-syntax.html

---

## Conclusión

Este backend implementa una API REST segura, escalable y lista para producción con:

✅ **Containerización:** Multi-stage Docker + Alpine  
✅ **Orquestación:** Docker Compose local ≈ producción  
✅ **Seguridad:** JWT, bcrypt, CORS, validación input  
✅ **DevOps:** 12-factor app, healthcheck, CI/CD ready  
✅ **Datos:** Transacciones ACID, pool conexiones, seed idempotente  
✅ **Escalabilidad:** Stateless, AWS-ready, load balancer compatible  

Está listo para evaluación académica y deployment en AWS EC2 con RDS PostgreSQL.

---

**Última actualización:** 17 de mayo de 2026  
**Versión:** 1.0.0  
**Autor:** Equipo DevOps - ISY1101

---

## Repositorio del frontend

[`casino-frontend`](../casino-frontend)
