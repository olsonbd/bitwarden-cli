FROM node:24-alpine

# Install required packages (curl, bash, tini)
RUN apk add --no-cache curl bash tini

# Install Bitwarden CLI globally
RUN npm install -g @bitwarden/cli

# Create non-root user and config directory
RUN addgroup -g 1001 -S bw && adduser -S bw -u 1001 -G bw bw && \
    mkdir -p /app/.config && chown -R bw:bw /app/.config

# Copy entrypoint logic
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh && chown bw:bw /entrypoint.sh

USER bw
WORKDIR /app

EXPOSE 8087

HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
  CMD curl -f http://localhost:8087/status || exit 1

ENTRYPOINT ["tini", "--", "/entrypoint.sh"]
