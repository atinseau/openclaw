---
name: container-tools
description: List the custom CLI tools that have been added to this OpenClaw container beyond the default image. Use when the user asks what extra tools are installed or available.
metadata: { "openclaw": { "emoji": "📦", "os": ["linux"], "always": true } }
---

# Container Custom Tools

This container extends the official OpenClaw image with the following additional commands:

## Installed tools

| Command | Description |
|---------|-------------|
| `jq`   | Lightweight JSON processor for parsing, filtering, and transforming JSON data |

## Usage notes

- These tools are available system-wide in the container PATH.
- To add more tools, edit the `Dockerfile` and redeploy.