FROM node:20-slim AS builder
WORKDIR /app
COPY apps/api/package*.json ./
RUN npm install --ignore-scripts
COPY apps/api/ .
RUN npx prisma generate
RUN npm run build

FROM node:20-slim AS runner
WORKDIR /app

RUN apt-get update && apt-get install -y --no-install-recommends \
    r-base r-base-dev \
    libcurl4-openssl-dev libssl-dev libxml2-dev \
    libfontconfig1-dev libfreetype6-dev \
    libharfbuzz-dev libfribidi-dev \
    libpng-dev libtiff5-dev libjpeg-dev \
    libcairo2-dev libxt-dev cmake libv8-dev libnode-dev \
    locales \
    && sed -i 's/# en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/' /etc/locale.gen \
    && locale-gen en_US.UTF-8 \
    && rm -rf /var/lib/apt/lists/*

COPY apps/stats-engine-r/install_packages.R /tmp/install_packages.R
RUN Rscript /tmp/install_packages.R

COPY --from=builder /app/dist ./dist
COPY --from=builder /app/node_modules ./node_modules
COPY apps/api/package.json ./
COPY apps/api/prisma ./prisma
COPY apps/stats-engine-r ./stats-engine-r

ENV NODE_ENV=production
ENV LANG=en_US.UTF-8
ENV LC_ALL=en_US.UTF-8
ENV LANGUAGE=en_US.UTF-8
EXPOSE 4000
CMD ["node", "dist/main.js"]
