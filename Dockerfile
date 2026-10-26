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

EXPOSE 3000

CMD ["npm", "start"]
