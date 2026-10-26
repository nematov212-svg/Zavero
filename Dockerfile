# =======================================================
# ZAVERO POS - REPOSITORY ROOT DOCKERFILE FOR RAILWAY
# =======================================================
FROM node:20-alpine

WORKDIR /app

RUN apk add --no-cache curl

# Copy backend dependencies from backend subdirectory
COPY backend/package*.json ./

RUN npm ci --omit=dev

# Copy backend application source
COPY backend/ ./

ENV NODE_ENV=production
ENV PORT=3000

EXPOSE 3000

HEALTHCHECK --interval=30s --timeout=5s --start-period=15s --retries=3 \
  CMD curl -f http://127.0.0.1:${PORT}/api/health || exit 1

CMD ["npm", "start"]
