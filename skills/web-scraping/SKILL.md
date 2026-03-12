---
name: web-scraping
description: Decision framework for extracting content from the web. Covers when to use web_fetch (fast HTTP) vs browser (full Chromium via Browserless). Always consult this skill before any web content extraction task.
metadata:
  {
    "openclaw":
      {
        "emoji": "🕸️",
        "always": true,
      },
  }
---

# Web Scraping — Decision Framework

You have **two tools** for extracting content from the web. Always start with the lightest approach and escalate only when needed.

---

## Tool Overview

| Tool | Method | JavaScript | Interaction | Speed | Cost |
|------|--------|-----------|-------------|-------|------|
| `web_fetch` | HTTP GET → Readability extraction | ❌ No | ❌ Read-only | Fast (~1-3s) | Free |
| `browser` | Chromium via CDP (Browserless) | ✅ Full | ✅ Click/type/scroll | Slow (~5-15s) | Heavier |

---

## Decision Tree

Follow this order **every time** you need web content:

### Step 1 — Try `web_fetch` first

```
web_fetch(url: "https://example.com", extractMode: "markdown", maxChars: 50000)
```

This works for:
- News articles, blog posts, documentation
- Static HTML pages, wikis, READMEs
- Public APIs returning HTML or text
- Any page where the main content is in the initial HTML response

### Step 2 — Evaluate the result

`web_fetch` **succeeded** if you got meaningful readable content.

`web_fetch` **failed** if:
- The response is empty, near-empty, or just boilerplate (nav/footer only)
- You see "Please enable JavaScript" or similar messages
- The content is behind a login wall
- The page is a Single Page Application (React, Angular, Vue)
- You got a CAPTCHA or anti-bot block
- You need to interact with the page (click tabs, expand sections, paginate)

### Step 3 — Escalate to `browser` only if `web_fetch` failed

```
browser(action: "open", url: "https://example.com")
browser(action: "snapshot")
```

---

## `web_fetch` Patterns

### Basic content extraction

```
web_fetch(url: "https://example.com/article", extractMode: "markdown")
```

### Extract as plain text (smaller, no formatting)

```
web_fetch(url: "https://example.com/article", extractMode: "text")
```

### Limit output size for large pages

```
web_fetch(url: "https://example.com/docs", extractMode: "markdown", maxChars: 20000)
```

### Known good targets for `web_fetch`

- Wikipedia, MDN, GitHub READMEs, Medium, Substack
- News sites (BBC, Reuters, NYT, Le Monde)
- Documentation sites (official docs, man pages)
- Blog platforms (WordPress, Ghost, Hugo)
- Any page with server-side rendered content

---

## `browser` Patterns

### Read a JavaScript-rendered page

```
browser(action: "open", url: "https://spa-app.com")
browser(action: "snapshot")
```

The snapshot returns an accessibility tree with refs. Use this to read the page content.

### Wait for dynamic content to load

```
browser(action: "open", url: "https://example.com")
browser(action: "act", kind: "wait", text: "Results loaded")
browser(action: "snapshot")
```

### Extract content from a specific section

```
browser(action: "snapshot", selector: "#main-content", interactive: true)
```

### Handle pagination / "Load More"

```
browser(action: "snapshot", interactive: true)
# Find the "Load more" or "Next" button ref
browser(action: "act", kind: "click", ref: <button_ref>)
browser(action: "snapshot")
```

### Handle cookie banners / popups

```
browser(action: "snapshot", interactive: true)
# Find and click "Accept" / "Close" button
browser(action: "act", kind: "click", ref: <accept_ref>)
browser(action: "snapshot")
```

### Take a visual screenshot for verification

```
browser(action: "screenshot")
```

### Extract a full-page PDF

```
browser(action: "act", kind: "pdf")
```

### Scroll to load lazy content

```
browser(action: "act", kind: "press", key: "End")
browser(action: "act", kind: "wait", timeMs: 2000)
browser(action: "snapshot")
```

### Fill a search form and extract results

```
browser(action: "snapshot", interactive: true)
browser(action: "act", kind: "type", ref: <search_input_ref>, text: "search query", submit: true)
browser(action: "act", kind: "wait", text: "results")
browser(action: "snapshot")
```

---

## Known cases requiring `browser`

These sites/patterns almost always need the browser — skip `web_fetch`:

- **SPAs**: React, Angular, Vue, Next.js client-rendered pages
- **Login-required content**: any site needing authentication
- **Dynamic dashboards**: analytics, admin panels, data tables
- **E-commerce**: product pages with JS-loaded prices/availability
- **Social media feeds**: Twitter/X, LinkedIn, Instagram (rendered client-side)
- **Maps and interactive widgets**: Google Maps, embedded charts
- **Infinite scroll pages**: content loaded on scroll events
- **Pages behind Cloudflare/anti-bot**: Cloudflare challenge pages

---

## Important Rules

1. **Always try `web_fetch` first** unless you know the site requires JavaScript. It is faster and lighter.
2. **Never use `browser` just because you can.** It consumes a Browserless session slot.
3. **Close tabs when done.** After extracting browser content, use `browser(action: "close", targetId: "<id>")` to free resources.
4. **One tab at a time.** Avoid opening multiple tabs simultaneously — the Browserless instance has limited concurrency (2 sessions by default).
5. **Snapshot before acting.** Always take a snapshot before clicking/typing to get fresh refs.
6. **Refs are ephemeral.** After any navigation or page change, take a new snapshot — old refs are invalid.
7. **Report extraction quality.** If content seems incomplete or garbled, tell the user and suggest an alternative approach.
8. **Respect `maxChars`.** For large pages, use `maxChars` to stay within context limits. Summarize if needed.
9. **Cache awareness.** `web_fetch` caches results for 15 minutes. If the user wants fresh data, mention this.
10. **No credentials.** Never ask for or handle user passwords. For login-required sites, the user must log in manually in the browser profile first.