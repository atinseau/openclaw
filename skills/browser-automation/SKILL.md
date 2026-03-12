---
name: browser-automation
description: Complete reference for the browser tool powered by Browserless (headless Chromium via CDP). Covers all actions, workflow patterns, and best practices for browser automation. Consult this skill when web_fetch is insufficient and you need full browser control.
metadata:
  {
    "openclaw":
      {
        "emoji": "🌐",
        "always": true,
      },
  }
---

# Browser Automation — Browserless Reference

This gateway runs a **Browserless** container (headless Chromium) accessible via the `browser` tool with `profile="browserless"`. All browser actions go through this remote CDP connection.

---

## Architecture

```
Agent → browser tool → OpenClaw Gateway → playwright-core → CDP → Browserless container (Chromium)
```

- **Profile**: `browserless` (default)
- **Concurrency**: 2 simultaneous sessions (configurable via `BROWSERLESS_CONCURRENT`)
- **Session timeout**: 120 seconds per session (configurable via `BROWSERLESS_TIMEOUT`)
- **Headless**: always (server environment)

---

## Core Workflow

Every browser interaction follows this pattern:

```
1. OPEN    → browser(action: "open", url: "...")
2. SNAPSHOT → browser(action: "snapshot")           ← read the page, get refs
3. ACT     → browser(action: "act", kind: "...", ref: N)  ← interact using refs
4. SNAPSHOT → browser(action: "snapshot")           ← re-read after action
5. CLOSE   → browser(action: "close", targetId: "...")    ← free the session
```

**Golden rules:**
- Always snapshot before acting — you need fresh refs.
- Always snapshot after acting — the page may have changed.
- Always close tabs when done — Browserless has limited slots.

---

## Actions Reference

### Lifecycle

| Action | Purpose | Example |
|--------|---------|---------|
| `status` | Check if Browserless is reachable | `browser(action: "status")` |
| `open` | Open a URL in a new tab | `browser(action: "open", url: "https://example.com")` |
| `tabs` | List all open tabs | `browser(action: "tabs")` |
| `focus` | Switch to a specific tab | `browser(action: "focus", targetId: "ABC123")` |
| `close` | Close a specific tab | `browser(action: "close", targetId: "ABC123")` |

### Reading

| Action | Purpose | Example |
|--------|---------|---------|
| `snapshot` | Get the accessibility tree with refs | `browser(action: "snapshot")` |
| `snapshot` (interactive) | Flat list of interactive elements only | `browser(action: "snapshot", interactive: true)` |
| `snapshot` (selector) | Scope to a DOM subtree | `browser(action: "snapshot", selector: "#main")` |
| `screenshot` | Capture viewport as image | `browser(action: "screenshot")` |
| `screenshot` (full) | Capture entire page | `browser(action: "screenshot", fullPage: true)` |
| `screenshot` (element) | Capture a specific element | `browser(action: "screenshot", ref: 12)` |
| `console` | Read browser console output | `browser(action: "console")` |

### Navigation

| Action | Purpose | Example |
|--------|---------|---------|
| `navigate` | Navigate current tab to a URL | `browser(action: "navigate", url: "https://...")` |

### Interaction (via `act`)

All `act` actions require a `ref` obtained from the most recent `snapshot`.

| Kind | Purpose | Example |
|------|---------|---------|
| `click` | Click an element | `browser(action: "act", kind: "click", ref: 12)` |
| `click` (double) | Double-click | `browser(action: "act", kind: "click", ref: 12, double: true)` |
| `type` | Type text into an input | `browser(action: "act", kind: "type", ref: 7, text: "hello")` |
| `type` (submit) | Type and press Enter | `browser(action: "act", kind: "type", ref: 7, text: "query", submit: true)` |
| `press` | Press a keyboard key | `browser(action: "act", kind: "press", key: "Enter")` |
| `hover` | Hover over an element | `browser(action: "act", kind: "hover", ref: 5)` |
| `scroll` | Scroll element into view | `browser(action: "act", kind: "scrollintoview", ref: 15)` |
| `drag` | Drag from one ref to another | `browser(action: "act", kind: "drag", startRef: 3, endRef: 8)` |
| `select` | Select dropdown option(s) | `browser(action: "act", kind: "select", ref: 9, values: ["Option A"])` |
| `fill` | Fill multiple fields at once | `browser(action: "act", kind: "fill", fields: [...])` |
| `wait` | Wait for text to appear | `browser(action: "act", kind: "wait", text: "Done")` |
| `wait` | Wait for a duration | `browser(action: "act", kind: "wait", timeMs: 3000)` |
| `evaluate` | Execute JavaScript in page | `browser(action: "act", kind: "evaluate", fn: "document.title")` |
| `resize` | Resize viewport | `browser(action: "act", kind: "resize", width: 1280, height: 720)` |
| `pdf` | Generate PDF of current page | `browser(action: "act", kind: "pdf")` |

### State Management

| Action | Purpose | Example |
|--------|---------|---------|
| `cookies` | Get all cookies | `browser(action: "act", kind: "cookies")` |
| `cookies.set` | Set a cookie | `browser(action: "act", kind: "cookies.set", name: "session", value: "abc", url: "https://...")` |
| `cookies.clear` | Clear all cookies | `browser(action: "act", kind: "cookies.clear")` |

### File Operations

| Action | Purpose | Example |
|--------|---------|---------|
| `upload` | Arm file upload (call before clicking the upload button) | `browser(action: "upload", paths: ["/tmp/openclaw/uploads/file.pdf"])` |
| `dialog` | Accept/dismiss a browser dialog | `browser(action: "dialog", accept: true)` |
| `download` | Download a file by clicking a ref | `browser(action: "act", kind: "download", ref: 14, path: "report.pdf")` |

---

## Snapshot Types

### AI Snapshot (default)

```
browser(action: "snapshot")
```

Returns a text representation with **numeric refs** like `ref=12`. Best for general page reading and action targeting.

### Interactive Snapshot

```
browser(action: "snapshot", interactive: true)
```

Returns a **flat list of only interactive elements** (buttons, links, inputs) with role refs like `ref=e12`. Best when you need to find something to click/type.

### Scoped Snapshot

```
browser(action: "snapshot", selector: "#results", interactive: true)
```

Scopes the snapshot to a specific DOM subtree. Use when the page is large and you only need one section.

### Compact / Efficient Snapshot

```
browser(action: "snapshot", mode: "efficient")
```

Compact preset: interactive + compact + limited depth. Use for large pages to reduce output size.

---

## Common Workflow Patterns

### Pattern: Read a JS-rendered page

```
browser(action: "open", url: "https://spa-app.com/dashboard")
browser(action: "snapshot")
# Read the content from the snapshot
browser(action: "close", targetId: "...")
```

### Pattern: Search on a website

```
browser(action: "open", url: "https://example.com")
browser(action: "snapshot", interactive: true)
# Find the search input ref
browser(action: "act", kind: "type", ref: <input_ref>, text: "search terms", submit: true)
browser(action: "act", kind: "wait", text: "results")
browser(action: "snapshot")
# Extract results
browser(action: "close", targetId: "...")
```

### Pattern: Multi-page navigation

```
browser(action: "open", url: "https://example.com/page1")
browser(action: "snapshot")
# Extract page 1 content
browser(action: "snapshot", interactive: true)
# Find "Next" link ref
browser(action: "act", kind: "click", ref: <next_ref>)
browser(action: "snapshot")
# Extract page 2 content
browser(action: "close", targetId: "...")
```

### Pattern: Fill and submit a form

```
browser(action: "open", url: "https://example.com/form")
browser(action: "snapshot", interactive: true)
browser(action: "act", kind: "type", ref: <name_ref>, text: "John Doe")
browser(action: "act", kind: "type", ref: <email_ref>, text: "john@example.com")
browser(action: "act", kind: "select", ref: <country_ref>, values: ["France"])
browser(action: "act", kind: "click", ref: <submit_ref>)
browser(action: "act", kind: "wait", text: "Thank you")
browser(action: "snapshot")
browser(action: "close", targetId: "...")
```

### Pattern: Dismiss cookie banner then read

```
browser(action: "open", url: "https://example.com")
browser(action: "snapshot", interactive: true)
# Look for "Accept" / "Agree" / "OK" button in the snapshot
browser(action: "act", kind: "click", ref: <accept_ref>)
browser(action: "snapshot")
# Now read the actual page content
browser(action: "close", targetId: "...")
```

### Pattern: Scroll to load lazy/infinite content

```
browser(action: "open", url: "https://example.com/feed")
browser(action: "snapshot")
# First batch of content
browser(action: "act", kind: "press", key: "End")
browser(action: "act", kind: "wait", timeMs: 2000)
browser(action: "snapshot")
# Second batch loaded
browser(action: "act", kind: "press", key: "End")
browser(action: "act", kind: "wait", timeMs: 2000)
browser(action: "snapshot")
# Third batch, etc.
browser(action: "close", targetId: "...")
```

### Pattern: Extract structured data from a table

```
browser(action: "open", url: "https://example.com/data")
browser(action: "snapshot", selector: "table", interactive: false)
# Parse the table structure from the snapshot
browser(action: "close", targetId: "...")
```

### Pattern: Screenshot for visual verification

```
browser(action: "open", url: "https://example.com")
browser(action: "screenshot")
# Returns an image — use to verify visual layout or share with user
browser(action: "close", targetId: "...")
```

### Pattern: Handle authentication (pre-logged-in session)

If the user has already logged in manually in the browserless profile:

```
browser(action: "open", url: "https://authenticated-app.com/dashboard")
browser(action: "snapshot")
# Session cookies carry over — you're logged in
browser(action: "close", targetId: "...")
```

**Never** ask for or type credentials yourself. The user must log in manually.

### Pattern: Extract text from a PDF URL

```
browser(action: "open", url: "https://example.com/document.pdf")
browser(action: "snapshot")
# Chromium renders PDFs natively — snapshot gives you the text
browser(action: "close", targetId: "...")
```

---

## Debugging

### Page not loading as expected

```
browser(action: "console")          # Check for JS errors
browser(action: "screenshot")       # Visual check
```

### Element not found or click fails

```
browser(action: "snapshot", interactive: true)  # Refresh refs
browser(action: "screenshot")                    # See what's visible
# If an overlay/modal is blocking, dismiss it first
```

### Action targets wrong element

```
browser(action: "snapshot", interactive: true)
# Verify the ref matches what you expect
# If ambiguous, use scoped snapshot:
browser(action: "snapshot", selector: "#specific-section", interactive: true)
```

---

## Resource Management

Browserless has **limited concurrency** (default: 2 sessions, 120s timeout).

**Do:**
- Close tabs immediately after extracting content
- Use `web_fetch` for simple pages instead of wasting a browser session
- Check `browser(action: "tabs")` to see what's open
- Work with one tab at a time

**Don't:**
- Leave tabs open "for later"
- Open multiple tabs simultaneously for parallel scraping
- Use the browser for pages that `web_fetch` handles fine
- Keep a session alive longer than necessary

---

## Limitations

- **No file system access**: the browser runs in a separate container; downloaded files go to Browserless, not the gateway filesystem
- **No persistent state**: Browserless sessions are ephemeral; cookies and storage reset between sessions
- **No extension support**: Browserless runs vanilla Chromium without extensions
- **Headless only**: no visual UI — use screenshots to "see" the page
- **SSRF guarded**: navigation to private/internal IPs is blocked by default (`dangerouslyAllowPrivateNetwork: true` allows Docker-internal addresses)
- **Session timeout**: sessions are killed after 120s of activity (configurable)