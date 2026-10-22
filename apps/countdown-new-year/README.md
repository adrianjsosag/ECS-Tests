# Cuenta regresiva a Año Nuevo

Aplicación Node.js (sin dependencias externas) que muestra un cronómetro con cuenta regresiva hasta Año Nuevo y una barra de progreso animada con el avance del año.

## Configuración (`.env`)

| Variable          | Descripción                                   | Por defecto |
|-------------------|-----------------------------------------------|-------------|
| `PORT`            | Puerto HTTP                                   | `3000`      |
| `TIMEZONE`        | Zona horaria IANA (ej. `America/Bogota`)      | `UTC`       |
| `PRIMARY_COLOR`   | Color principal (hex, `rgb()`, `hsl()`, nombre) | `#7c3aed` |
| `SECONDARY_COLOR` | Color secundario del degradado                | `#06b6d4`   |

Copia `.env.example` a `.env` y ajusta los valores.

## Ejecutar con Docker

```bash
docker compose up -d --build
```

Abre http://localhost:3000. Tras cambiar el `.env`, aplica los cambios con:

```bash
docker compose up -d --force-recreate
```

Sin Compose:

```bash
docker build -t countdown-new-year .
docker run -d -p 3000:3000 --env-file .env countdown-new-year
```

## Ejecutar en local

Requiere Node.js 18+:

```bash
npm start
```
