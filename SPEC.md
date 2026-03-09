# Maestro macOS App (MVP) — Implementation Spec

## Goal

Build a macOS menu bar application (`Maestro.app`) that launches and manages the Maestro Go CLI binary, which serves a web UI. The macOS app provides a zero-CLI experience for users who install Maestro via a `.dmg`. The Go binary remains the primary runtime engine.

---

## User Installation

Users download `Maestro.dmg` containing `Maestro.app`.

1. Open DMG
2. Drag `Maestro.app` to `/Applications`
3. Launch `Maestro.app`

No Homebrew or terminal required. Apple Silicon only for MVP.

---

## App Bundle Layout

```
Maestro.app/
  Contents/
    Info.plist
    MacOS/
      MaestroMenuBar          # Swift executable
    Resources/
      maestro                  # Bundled Go CLI binary (arm64)
      icon.icns
```

The Go binary runs directly from the bundle. No runtime copy to `~/Library/Application Support`.

---

## First Launch Flow

```
App launches → menu bar icon appears
    ↓
No project directory configured?
    → Show macOS folder picker (mandatory)
    → Store selected path in UserDefaults
    ↓
Check Docker:
    1. Is `docker` binary present?
       └── No → Alert: "Maestro requires Docker Desktop. Please install it."
                [Open Docker Website]  [Quit]
    2. Is Docker daemon running? (`docker info`)
       └── No → Alert: "Docker Desktop is installed but not running."
                [Open Docker Desktop]  [Dismiss]
    ↓
Resolve password:
    1. Is MAESTRO_PASSWORD env var set system-wide? → Use it
    2. Is there a password in Keychain? → Use it
    3. Neither → Generate password, store in Keychain
    ↓
Generate session token (random string for this launch)
    ↓
Launch Go binary:
    MAESTRO_PASSWORD=<pass> MAESTRO_SESSION_TOKEN=<token> \
      Contents/Resources/maestro -projectdir <dir>
    ↓
Poll localhost:<port> until responsive
    ↓
Menu bar icon updates to "running" state
```

---

## Determining the Port

The web UI port is configurable in Maestro's own config file:

```
{projectDir}/.maestro/config.json → webUI.port
```

The macOS app reads this file to determine the port. Default is `8080` if the file doesn't exist or the field is absent.

---

## Menu Bar UI

```
Maestro
─────────────────────────────
  Open Web UI
  Copy Password
─────────────────────────────
  Select Project Directory...
─────────────────────────────
  Restart Maestro
  Stop Maestro
─────────────────────────────
  Quit
```

### Menu Item Behavior

**Open Web UI**
- Opens `http://localhost:<port>/auth/session?token=<session-token>` in default browser
- Token auth sets a session cookie, redirects to `/` — no password prompt
- Disabled while Maestro is starting up (port not yet responsive)

**Copy Password**
- Copies the Keychain-stored password to clipboard
- For power users who also use the CLI directly on the same project

**Select Project Directory...**
- Opens macOS folder picker
- If Maestro is currently running, show confirmation dialog:
  "Changing projects will stop the current Maestro session. Continue?"
- If confirmed: stop process, update UserDefaults, restart with new directory
- If Maestro is stopped: update UserDefaults, start with new directory

**Restart Maestro**
- Terminate existing process, re-run Docker checks, launch new process with current config
- Generate a new session token on restart

**Stop Maestro**
- Terminate the Go process
- Update menu bar icon to stopped state

**Quit**
- Terminate Go process if running, then exit the app

---

## Menu Bar Icon States

| State | Indicator |
|-------|-----------|
| Running | Normal icon |
| Starting | Dimmed icon or activity indicator |
| Stopped / Crashed | Distinct icon variant (e.g., hollow or red dot) |

---

## Password Management

The macOS app owns the password lifecycle. The Go CLI never generates or displays one — it always receives `MAESTRO_PASSWORD` via environment.

```
Precedence:
1. MAESTRO_PASSWORD env var (set system-wide by user) → use as-is
2. Keychain entry → use stored value
3. No password exists → generate 16-char random password, store in Keychain
```

The password is never displayed in the UI. "Copy Password" is the only way to retrieve it.

Keychain service name: `com.maestro.app` (or similar bundle identifier).

---

## Session Token Auth

Each launch generates a fresh random session token passed to the Go binary via `MAESTRO_SESSION_TOKEN` env var.

When the user clicks "Open Web UI":
1. App opens `http://localhost:<port>/auth/session?token=<token>`
2. Go server validates token, sets session cookie, redirects to `/`
3. Subsequent requests use the session cookie — no Basic Auth dialog

This requires a small change to the Go CLI (see `MAESTRO_CHANGES.md`).

---

## Process Lifecycle

- Go binary runs as a child process via Swift `Process`
- stdout/stderr captured to `~/Library/Application Support/Maestro/logs/`
- `Process.terminationHandler` detects crashes and updates menu bar state
- On app quit (`applicationWillTerminate`), terminate child process
- Docker checks run before every start/restart

---

## Error Handling

**Go process crashes:**
- Menu bar icon switches to stopped state
- Menu shows "Maestro Stopped" with "Restart" option available
- Logs available at `~/Library/Application Support/Maestro/logs/`

**Port not responsive after timeout:**
- Show alert: "Maestro failed to start. Check logs for details."
- Option to view log directory

**Docker unavailable:**
- Handled at start/restart time with specific dialogs (see First Launch Flow)

---

## Persistent State

| Data | Storage | Reason |
|------|---------|--------|
| Current project directory | UserDefaults | Simple app preference |
| Password | macOS Keychain | Secure, survives reinstalls |
| Session token | In-memory only | Regenerated each launch |
| Logs | ~/Library/Application Support/Maestro/logs/ | Diagnostics |

No app config file.

---

## Technologies

- Language: Swift
- UI: SwiftUI with `MenuBarExtra`
- Process management: Foundation `Process`
- Password storage: macOS Keychain via Security framework
- Distribution: DMG (code signed + notarized)

---

## MVP Scope

**In scope:**
- Menu bar app with status indicators
- Start / stop / restart daemon
- Project directory selection with switch confirmation
- Password generation and Keychain storage
- Session token auth for browser launch
- Open Web UI
- Copy Password
- Docker availability checks
- Log capture
- DMG distribution (signed + notarized)

**Out of scope:**
- Apple Intel support
- Project directory history/favorites
- `-continue` (resume session) support
- launchd / login item (auto-start at login)
- Automatic updates
- Advanced settings UI
- Custom port configuration in the macOS app (reads from Maestro config only)
