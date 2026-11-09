FROM node:22-alpine AS frontend
WORKDIR /build
COPY frontend/package.json frontend/package-lock.json ./
RUN npm ci
COPY frontend/ ./
# API relative : le navigateur utilise le même hôte pour React et Django.
ENV VITE_API_BASE_URL=""
RUN npm run build

FROM caddy:2 AS caddy

FROM python:3.12-slim
ENV PYTHONDONTWRITEBYTECODE=1 PYTHONUNBUFFERED=1 \
    DJANGO_SETTINGS_MODULE=config.production \
    XDG_CONFIG_HOME=/tmp/caddy/config XDG_DATA_HOME=/tmp/caddy/data
WORKDIR /app
RUN apt-get update && apt-get install -y --no-install-recommends ca-certificates \
    && rm -rf /var/lib/apt/lists/* \
    && groupadd --gid 10001 sauverndeko \
    && useradd --create-home --uid 10001 --gid 10001 --shell /bin/sh sauverndeko \
    && install -d -m 0700 -o sauverndeko -g sauverndeko /home/sauverndeko/.ssh
COPY backend/requirements.txt /app/requirements.txt
RUN python -m pip install --no-cache-dir --only-binary=:all: pip==26.3 \
    && python -m pip install --no-cache-dir -r /app/requirements.txt
COPY --from=caddy /usr/bin/caddy /usr/bin/caddy
COPY --from=frontend /build/dist /app/frontend/dist
COPY --chown=sauverndeko:sauverndeko backend/ /app/backend/
COPY --chown=sauverndeko:sauverndeko SQL/ /app/SQL/
COPY --chown=sauverndeko:sauverndeko deploy/render/ /app/deploy/render/
COPY --chown=sauverndeko:sauverndeko skills/document-mise-en-forme/assets/charte_sauverndeko.json /app/skills/document-mise-en-forme/assets/charte_sauverndeko.json
RUN python deploy/render/collect_static.py \
    && mkdir -p /var/data/media \
    && chown -R sauverndeko:sauverndeko /var/data /app/backend/staticfiles \
    && caddy validate --config /app/deploy/render/Caddyfile --adapter caddyfile
COPY --chown=sauverndeko:sauverndeko scripts/render-start.sh /app/scripts/render-start.sh
USER sauverndeko
EXPOSE 10000
CMD ["bash", "scripts/render-start.sh"]
