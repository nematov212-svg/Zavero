# =======================================================
# ZAVERO POS - PRODUCTION DOCKERFILE FOR RAILWAY / CLOUD
# =======================================================
FROM node:20-alpine

# Set working directory inside container
WORKDIR /app

# Install curl for reliable container health checks
RUN apk add --no-cache curl

# Copy dependency manifests first for Docker layer caching
COPY package*.json ./

# Install only production dependencies
RUN npm ci --omit=dev

# Copy the entire backend application code (including migrations, bot, and pre-built Flutter web bundle)
COPY . .

# Set environment defaults (Railway injects PORT and other ENV variables automatically)
ENV NODE_ENV=production
ENV PORT=3000


# Expose default port
EXPOSE 3000

# Health check to ensure zero-downtime deployments
HEALTHCHECK --interval=30s --timeout=5s --start-period=15s --retries=3 \
  CMD curl -f http://127.0.0.1:${PORT}/api/health || exit 1

# Start command: server.js automatically runs migrations and starts listening on 0.0.0.0:PORT
CMD ["npm", "start"]
