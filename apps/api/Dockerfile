FROM node:20-slim AS builder
WORKDIR /app
COPY apps/api/package*.json ./
RUN npm install --ignore-scripts
COPY apps/api/ .
RUN npx prisma generate
RUN npm run build

# rocker/r-ver ships R already compiled and installed, removing the slowest
# step of the previous Dockerfile (apt-get install r-base from Debian's
# repositories), which was exceeding Railway's trial-plan build timeout.
FROM rocker/r-ver:4.3.2 AS runner
WORKDIR /app

# Install Node.js 20 (not present in the rocker base image) and the system
# libraries required by the R packages used by the statistical engine.
RUN apt-get update && apt-get install -y --no-install-recommends \
    curl ca-certificates gnupg \
    libcurl4-openssl-dev libssl-dev libxml2-dev \
    libfontconfig1-dev libfreetype6-dev \
    libharfbuzz-dev libfribidi-dev \
    libpng-dev libtiff5-dev libjpeg-dev libwebp-dev \
    libcairo2-dev libxt-dev cmake libuv1-dev \
    locales \
    && curl -fsSL https://deb.nodesource.com/setup_20.x | bash - \
    && apt-get install -y --no-install-recommends nodejs \
    && sed -i 's/# en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/' /etc/locale.gen \
    && locale-gen en_US.UTF-8 \
    && rm -rf /var/lib/apt/lists/*

COPY apps/api/stats-engine-r/install_packages.R /tmp/install_packages.R
# NOTA: se evaluo un cache mount de BuildKit para este paso, pero Railway's
# proprietary build engine (railpack-builder, Metal) requiere un formato de
# id/cacheKey no documentado distinto al estandar de Docker BuildKit, y
# rechaza el mount con un error de sintaxis. Se opta por una instalacion
# directa sin cache mount: confirmado localmente que completa en ~14 min,
# dentro del limite de build observado en intentos exitosos anteriores.
RUN Rscript /tmp/install_packages.R

COPY --from=builder /app/dist ./dist
COPY --from=builder /app/node_modules ./node_modules
COPY apps/api/package.json ./
COPY apps/api/prisma ./prisma
# cache-bust: 20260707150715
COPY apps/api/stats-engine-r ./stats-engine-r

ENV NODE_ENV=production
ENV LANG=en_US.UTF-8
ENV LC_ALL=en_US.UTF-8
ENV LANGUAGE=en_US.UTF-8
EXPOSE 4000
CMD ["sh", "-c", "npx prisma migrate deploy && node dist/main.js"]
# trigger fresh deploy Fri Jun 26 20:40:18 -05 2026
