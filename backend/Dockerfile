# =======================================================
# ZAVERO POS - PRODUCTION DOCKERFILE FOR RAILWAY / CLOUD
# =======================================================
FROM node:20-alpine

WORKDIR /app

RUN apk add --no-cache curl

COPY package*.json ./

RUN npm ci --omit=dev

COPY . .

ENV NODE_ENV=production

EXPOSE 3000

CMD ["npm", "start"]
