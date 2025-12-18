# Build stage: compile Caddy with plugins using xcaddy
FROM golang:alpine AS builder

# Install xcaddy and git
RUN apk add --no-cache git ca-certificates && \
    go install github.com/caddyserver/xcaddy/cmd/xcaddy@latest

# Copy plugins list
COPY plugins.txt /plugins.txt

# Build Caddy with plugins
ARG CADDY_VERSION=latest
RUN set -ex; \
    PLUGINS=""; \
    while IFS= read -r plugin || [ -n "$plugin" ]; do \
        # Skip empty lines and comments
        case "$plugin" in \
            ""|\#*) continue ;; \
        esac; \
        PLUGINS="$PLUGINS --with $plugin"; \
    done < /plugins.txt; \
    if [ "$CADDY_VERSION" = "latest" ]; then \
        xcaddy build $PLUGINS; \
    else \
        xcaddy build "$CADDY_VERSION" $PLUGINS; \
    fi

# Runtime stage: minimal image with Caddy binary
FROM alpine:latest

# Install runtime dependencies
RUN apk add --no-cache ca-certificates tzdata mailcap

# Copy Caddy binary from builder
COPY --from=builder /go/caddy /usr/bin/caddy

# Create caddy user and directories
RUN addgroup -S caddy && adduser -S -G caddy caddy && \
    mkdir -p /config/caddy /data/caddy && \
    chown -R caddy:caddy /config /data

# Set environment variables
ENV XDG_CONFIG_HOME=/config
ENV XDG_DATA_HOME=/data

# Expose ports
EXPOSE 80 443 443/udp 2019

# Set working directory
WORKDIR /srv

# Switch to non-root user
USER caddy

# Default command
CMD ["caddy", "run", "--config", "/etc/caddy/Caddyfile", "--adapter", "caddyfile"]
