# ---------- deps stage ----------
FROM node:20-alpine AS deps
WORKDIR /app
COPY package*.json ./
RUN npm ci --omit=dev --ignore-scripts

# ---------- runtime stage ----------
FROM node:20-alpine AS runner
WORKDIR /app

# Create non-root user
RUN addgroup -S app && adduser -S app -G app

COPY --from=deps /app/node_modules ./node_modules
COPY src ./src

# Drop privileges
USER app

ENV NODE_ENV=production
EXPOSE 3000
CMD ["node", "src/server.js"]
    