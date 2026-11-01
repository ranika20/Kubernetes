FROM node:22-alpine

WORKDIR /app

ARG APP_VERSION=v1
ENV NODE_ENV=production
ENV APP_VERSION=${APP_VERSION}

COPY package*.json ./
RUN npm ci --omit=dev

COPY --chown=node:node server.js ./
USER node

EXPOSE 3000
CMD ["node", "server.js"]
