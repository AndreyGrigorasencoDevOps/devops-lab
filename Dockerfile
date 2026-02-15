# ---------- deps stage ----------
    FROM node:18-alpine AS deps
    WORKDIR /app
    COPY package*.json ./
    RUN npm ci --omit=dev
    
    # ---------- runtime stage ----------
    FROM node:18-alpine AS runner
    WORKDIR /app
    COPY --from=deps /app/node_modules ./node_modules
    COPY src ./src
    
    ENV NODE_ENV=production
    EXPOSE 3000
    CMD ["node", "src/server.js"]
    