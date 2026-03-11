# ─── Stage 1: Dependency installation (build stage) ───────────────────────────
FROM node:18-alpine AS deps
# Why alpine: minimal attack surface, ~50MB vs ~900MB full image
# Why multi-stage: final image has NO npm, NO build tools — only runtime

WORKDIR /app

# Copy package files first → Docker cache layer optimization
# If package.json hasn't changed, npm install layer is reused on rebuilds
COPY package*.json ./

# --omit=dev: production deps only (no devDependencies in final image)
# npm ci: deterministic installs using package-lock.json exactly
RUN npm ci --omit=dev

# ─── Stage 2: Final runtime image ─────────────────────────────────────────────
FROM node:18-alpine AS runtime

# Security: create non-root user/group
# Running as root inside container = privilege escalation risk
# Also install wget for healthcheck (not available by default in alpine)
RUN addgroup -g 1001 -S nodejs && \
    adduser  -u 1001 -S nodeapp -G nodejs && \
    apk add --no-cache wget

WORKDIR /app

# Copy only production node_modules from deps stage
COPY --from=deps --chown=nodeapp:nodejs /app/node_modules ./node_modules

# Copy application source
COPY --chown=nodeapp:nodejs . .

# Drop to non-root user
USER nodeapp

# Document port (doesn't publish — just metadata)
EXPOSE 3000

# Health check built into the image itself
# --interval: check every 30s
# --timeout: fail if no response in 5s
# --start-period: grace period on container start (30s for app boot)
# --retries: 3 consecutive failures = unhealthy
HEALTHCHECK --interval=30s --timeout=5s --start-period=30s --retries=3 \
  CMD wget -qO- http://localhost:3000/health || exit 1

# Use exec form (not shell form) — PID 1 gets SIGTERM directly for graceful shutdown
CMD ["node", "index.js"]
