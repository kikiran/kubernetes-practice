# Multi-stage Dockerfile for deployment strategies demo
FROM node:18-alpine AS builder
WORKDIR /app
COPY package*.json ./
RUN npm ci 

FROM node:18-alpine
WORKDIR /app

# Create non-root user
RUN addgroup -g 1001 -S nodejs && \
    adduser -S nodejs -u 1001

# Copy dependencies
COPY --from=builder /app/node_modules ./node_modules

# Copy application
COPY --chown=nodejs:nodejs . .

# Set version as build arg
ARG APP_VERSION=v1
ARG APP_COLOR=blue
ENV APP_VERSION=${APP_VERSION}
ENV APP_COLOR=${APP_COLOR}

EXPOSE 3000

USER nodejs

HEALTHCHECK --interval=10s --timeout=3s --start-period=5s --retries=3 \
    CMD node -e "require('http').get('http://localhost:3000/health', (r) => {process.exit(r.statusCode === 200 ? 0 : 1)})"

CMD ["node", "app.js"]
