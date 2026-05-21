from __future__ import annotations

import base64
import hashlib
import hmac
import json
import os
import secrets
import sqlite3
from contextlib import contextmanager
from datetime import UTC, datetime, timedelta, timezone
from html import escape
from http import HTTPStatus
from http.cookies import SimpleCookie
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from typing import Any
from urllib.parse import parse_qs, urlparse


HOST = os.getenv("TOKEN_ISSUER_HOST", "0.0.0.0")
PORT = int(os.getenv("TOKEN_ISSUER_PORT", "8090"))
DB_PATH = Path(os.getenv("TOKEN_ISSUER_DB_PATH", "/data/token_issuer.db"))
ADMIN_PASSWORD = os.getenv(
    "TOKEN_ISSUER_ADMIN_PASSWORD",
    os.getenv("CENTRIFUGO_ADMIN_PASSWORD", ""),
).strip()
JWT_SECRET = os.getenv(
    "CENTRIFUGO_CLIENT_TOKEN_HMAC_SECRET_KEY",
    os.getenv("CENTRIFUGO_ADMIN_SECRET", ""),
).strip()
JWT_ISSUER = os.getenv("CENTRIFUGO_CLIENT_TOKEN_ISSUER", "blackphoenix-market-feed")
JWT_AUDIENCE = os.getenv("CENTRIFUGO_CLIENT_TOKEN_AUDIENCE", "blackphoenix-market-feed")
PUBLIC_WEBSOCKET_URL = os.getenv(
    "TOKEN_ISSUER_PUBLIC_WEBSOCKET_URL",
    "wss://blackphoenix.online/connection/websocket",
).strip()
JWT_TTL_SECONDS = int(os.getenv("TOKEN_ISSUER_JWT_TTL_SECONDS", "900"))
SESSION_TTL_SECONDS = int(os.getenv("TOKEN_ISSUER_SESSION_TTL_SECONDS", "86400"))
COOKIE_SECURE = os.getenv("TOKEN_ISSUER_COOKIE_SECURE", "true").lower() not in {"0", "false", "no"}
DEFAULT_GROUP = "btc_viewer"

GROUP_OPTIONS = {
    "btc_viewer": {
        "label": "BTC viewer",
        "channels": ["market:btc"],
    }
}

SESSION_COOKIE = "bp_admin_session"


def now_utc() -> datetime:
    return datetime.now(timezone.utc)


def isoformat(dt: datetime | None) -> str | None:
    if dt is None:
        return None
    value = dt.astimezone(timezone.utc).replace(microsecond=0)
    return value.isoformat().replace("+00:00", "Z")


def parse_iso(value: str | None) -> datetime | None:
    if not value:
        return None
    normalized = value.replace("Z", "+00:00")
    try:
        parsed = datetime.fromisoformat(normalized)
    except ValueError:
        return None
    if parsed.tzinfo is None:
        parsed = parsed.replace(tzinfo=UTC)
    return parsed.astimezone(timezone.utc)


def normalize_group(group_name: str | None) -> str:
    if group_name in GROUP_OPTIONS:
        return group_name
    return DEFAULT_GROUP


def channels_for_group(group_name: str | None) -> list[str]:
    group = normalize_group(group_name)
    return list(GROUP_OPTIONS[group]["channels"])


def sha256_hex(value: str) -> str:
    return hashlib.sha256(value.encode("utf-8")).hexdigest()


def b64url(raw: bytes) -> str:
    return base64.urlsafe_b64encode(raw).rstrip(b"=").decode("ascii")


def encode_jwt(payload: dict[str, Any]) -> str:
    if not JWT_SECRET:
        raise RuntimeError("CENTRIFUGO_CLIENT_TOKEN_HMAC_SECRET_KEY is not set")
    header = {"alg": "HS256", "typ": "JWT"}
    signing_input = ".".join(
        [
            b64url(json.dumps(header, separators=(",", ":"), sort_keys=True).encode("utf-8")),
            b64url(json.dumps(payload, separators=(",", ":"), sort_keys=True).encode("utf-8")),
        ]
    ).encode("ascii")
    signature = hmac.new(JWT_SECRET.encode("utf-8"), signing_input, hashlib.sha256).digest()
    return f"{signing_input.decode('ascii')}.{b64url(signature)}"


def generate_raw_token() -> str:
    return f"bp_{secrets.token_urlsafe(4)}_{secrets.token_urlsafe(28)}"


def format_expires_date(raw: str | None) -> str:
    if not raw:
        return ""
    parsed = parse_iso(raw)
    if not parsed:
        return ""
    return parsed.strftime("%Y-%m-%d")


def parse_date_to_expiry(raw: str | None) -> str | None:
    if not raw:
        return None
    raw = raw.strip()
    if not raw:
        return None
    try:
        parsed = datetime.strptime(raw, "%Y-%m-%d").replace(tzinfo=UTC)
    except ValueError:
        return None
    return isoformat(parsed + timedelta(days=1) - timedelta(seconds=1))


@contextmanager
def db() -> sqlite3.Connection:
    DB_PATH.parent.mkdir(parents=True, exist_ok=True)
    conn = sqlite3.connect(DB_PATH)
    conn.row_factory = sqlite3.Row
    try:
        yield conn
        conn.commit()
    finally:
        conn.close()


def init_db() -> None:
    with db() as conn:
        conn.execute(
            """
            CREATE TABLE IF NOT EXISTS users (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                username TEXT NOT NULL UNIQUE,
                token_hash TEXT NOT NULL,
                token_prefix TEXT NOT NULL,
                group_name TEXT NOT NULL,
                expires_at TEXT,
                enabled INTEGER NOT NULL DEFAULT 1,
                last_used_at TEXT,
                created_at TEXT NOT NULL,
                updated_at TEXT NOT NULL
            )
            """
        )
        conn.execute(
            """
            CREATE TABLE IF NOT EXISTS admin_sessions (
                session_hash TEXT PRIMARY KEY,
                created_at TEXT NOT NULL,
                expires_at TEXT NOT NULL
            )
            """
        )


def json_response(handler: BaseHTTPRequestHandler, payload: Any, status: int = 200, headers: dict[str, str] | None = None) -> None:
    data = json.dumps(payload, ensure_ascii=False, separators=(",", ":")).encode("utf-8")
    handler.send_response(status)
    handler.send_header("Content-Type", "application/json; charset=utf-8")
    handler.send_header("Content-Length", str(len(data)))
    handler.send_header("Cache-Control", "no-store")
    if headers:
        for key, value in headers.items():
            handler.send_header(key, value)
    handler.end_headers()
    handler.wfile.write(data)


def html_response(handler: BaseHTTPRequestHandler, html: str, status: int = 200) -> None:
    data = html.encode("utf-8")
    handler.send_response(status)
    handler.send_header("Content-Type", "text/html; charset=utf-8")
    handler.send_header("Content-Length", str(len(data)))
    handler.send_header("Cache-Control", "no-store")
    handler.end_headers()
    handler.wfile.write(data)


def text_response(handler: BaseHTTPRequestHandler, text: str, status: int = 200) -> None:
    data = text.encode("utf-8")
    handler.send_response(status)
    handler.send_header("Content-Type", "text/plain; charset=utf-8")
    handler.send_header("Content-Length", str(len(data)))
    handler.send_header("Cache-Control", "no-store")
    handler.end_headers()
    handler.wfile.write(data)


def read_json_body(handler: BaseHTTPRequestHandler) -> dict[str, Any]:
    length = int(handler.headers.get("Content-Length", "0"))
    raw = handler.rfile.read(length) if length > 0 else b""
    if not raw:
        return {}
    return json.loads(raw.decode("utf-8"))


def read_form_body(handler: BaseHTTPRequestHandler) -> dict[str, str]:
    length = int(handler.headers.get("Content-Length", "0"))
    raw = handler.rfile.read(length) if length > 0 else b""
    parsed = parse_qs(raw.decode("utf-8"))
    return {key: values[0] if values else "" for key, values in parsed.items()}


def get_cookies(handler: BaseHTTPRequestHandler) -> SimpleCookie:
    cookie = SimpleCookie()
    raw = handler.headers.get("Cookie")
    if raw:
        cookie.load(raw)
    return cookie


def session_hash(token: str) -> str:
    return sha256_hex(token)


def create_admin_session() -> str:
    token = secrets.token_urlsafe(32)
    created_at = isoformat(now_utc()) or ""
    expires_at = isoformat(now_utc() + timedelta(seconds=SESSION_TTL_SECONDS)) or ""
    with db() as conn:
        conn.execute(
            "INSERT OR REPLACE INTO admin_sessions (session_hash, created_at, expires_at) VALUES (?, ?, ?)",
            (session_hash(token), created_at, expires_at),
        )
    return token


def is_admin_session_valid(token: str | None) -> bool:
    if not token:
        return False
    token_hash = session_hash(token)
    with db() as conn:
        row = conn.execute(
            "SELECT expires_at FROM admin_sessions WHERE session_hash = ?",
            (token_hash,),
        ).fetchone()
    if not row:
        return False
    expires_at = parse_iso(row["expires_at"])
    return bool(expires_at and expires_at > now_utc())


def delete_admin_session(token: str | None) -> None:
    if not token:
        return
    with db() as conn:
        conn.execute("DELETE FROM admin_sessions WHERE session_hash = ?", (session_hash(token),))


def admin_session_cookie(token: str, max_age: int) -> str:
    parts = [
        f"{SESSION_COOKIE}={token}",
        "Path=/auth",
        "HttpOnly",
        "SameSite=Lax",
        f"Max-Age={max_age}",
    ]
    if COOKIE_SECURE:
        parts.append("Secure")
    return "; ".join(parts)


def user_to_public_dict(row: sqlite3.Row) -> dict[str, Any]:
    return {
        "id": row["id"],
        "username": row["username"],
        "token_prefix": row["token_prefix"],
        "group_name": row["group_name"],
        "channels": channels_for_group(row["group_name"]),
        "expires_at": row["expires_at"],
        "enabled": bool(row["enabled"]),
        "last_used_at": row["last_used_at"],
        "created_at": row["created_at"],
        "updated_at": row["updated_at"],
    }


def list_users() -> list[dict[str, Any]]:
    with db() as conn:
        rows = conn.execute(
            "SELECT id, username, token_prefix, group_name, expires_at, enabled, last_used_at, created_at, updated_at "
            "FROM users ORDER BY id DESC"
        ).fetchall()
    return [user_to_public_dict(row) for row in rows]


def get_user_by_id(user_id: int) -> sqlite3.Row | None:
    with db() as conn:
        return conn.execute(
            "SELECT * FROM users WHERE id = ?",
            (user_id,),
        ).fetchone()


def get_user_by_token(raw_token: str) -> sqlite3.Row | None:
    token_hash = sha256_hex(raw_token)
    with db() as conn:
        return conn.execute(
            "SELECT * FROM users WHERE token_hash = ?",
            (token_hash,),
        ).fetchone()


def create_user(username: str, group_name: str, expires_at: str | None, enabled: bool) -> tuple[dict[str, Any], str]:
    group_name = normalize_group(group_name)
    token = generate_raw_token()
    token_hash = sha256_hex(token)
    token_prefix = token[:12]
    created_at = isoformat(now_utc()) or ""
    updated_at = created_at
    with db() as conn:
        conn.execute(
            """
            INSERT INTO users (
                username, token_hash, token_prefix, group_name, expires_at, enabled, last_used_at, created_at, updated_at
            ) VALUES (?, ?, ?, ?, ?, ?, NULL, ?, ?)
            """,
            (
                username,
                token_hash,
                token_prefix,
                group_name,
                expires_at,
                1 if enabled else 0,
                created_at,
                updated_at,
            ),
        )
        row = conn.execute("SELECT * FROM users WHERE username = ?", (username,)).fetchone()
    assert row is not None
    return user_to_public_dict(row), token


def update_user(user_id: int, group_name: str | None, expires_at: str | None, enabled: bool | None) -> dict[str, Any] | None:
    row = get_user_by_id(user_id)
    if row is None:
        return None
    group_name = normalize_group(group_name or row["group_name"])
    expires_at = row["expires_at"] if expires_at is None else expires_at
    enabled_value = row["enabled"] if enabled is None else (1 if enabled else 0)
    updated_at = isoformat(now_utc()) or ""
    with db() as conn:
        conn.execute(
            """
            UPDATE users
            SET group_name = ?, expires_at = ?, enabled = ?, updated_at = ?
            WHERE id = ?
            """,
            (group_name, expires_at, enabled_value, updated_at, user_id),
        )
        updated = conn.execute("SELECT * FROM users WHERE id = ?", (user_id,)).fetchone()
    return user_to_public_dict(updated) if updated else None


def rotate_user_token(user_id: int) -> tuple[dict[str, Any] | None, str | None]:
    row = get_user_by_id(user_id)
    if row is None:
        return None, None
    token = generate_raw_token()
    token_hash = sha256_hex(token)
    token_prefix = token[:12]
    updated_at = isoformat(now_utc()) or ""
    with db() as conn:
        conn.execute(
            """
            UPDATE users
            SET token_hash = ?, token_prefix = ?, last_used_at = NULL, updated_at = ?
            WHERE id = ?
            """,
            (token_hash, token_prefix, updated_at, user_id),
        )
        updated = conn.execute("SELECT * FROM users WHERE id = ?", (user_id,)).fetchone()
    return (user_to_public_dict(updated) if updated else None), token


def delete_user(user_id: int) -> bool:
    with db() as conn:
        cursor = conn.execute("DELETE FROM users WHERE id = ?", (user_id,))
    return cursor.rowcount > 0


def update_last_used(user_id: int) -> None:
    updated_at = isoformat(now_utc()) or ""
    with db() as conn:
        conn.execute(
            "UPDATE users SET last_used_at = ?, updated_at = ? WHERE id = ?",
            (updated_at, updated_at, user_id),
        )


def make_connection_jwt(user: sqlite3.Row) -> tuple[str, str]:
    now = now_utc()
    expires_at = now + timedelta(seconds=JWT_TTL_SECONDS)
    channels = channels_for_group(user["group_name"])
    payload = {
        "iss": JWT_ISSUER,
        "aud": JWT_AUDIENCE,
        "sub": user["username"],
        "iat": int(now.timestamp()),
        "exp": int(expires_at.timestamp()),
        "channels": channels,
    }
    return encode_jwt(payload), isoformat(expires_at) or ""


def derive_websocket_url() -> str:
    return PUBLIC_WEBSOCKET_URL or "wss://blackphoenix.online/connection/websocket"


def is_admin_path(path: str) -> bool:
    return path == "/auth/admin" or path.startswith("/auth/admin/")


def is_auth_path(path: str) -> bool:
    return path == "/auth/exchange" or path.startswith("/auth/")


def admin_page_html(authed: bool) -> str:
    groups_json = json.dumps(
        [{"value": key, "label": value["label"]} for key, value in GROUP_OPTIONS.items()],
        ensure_ascii=False,
    )
    login_section = """
      <section class="panel">
        <h2>Admin login</h2>
        <form method="post" action="/auth/login" class="form">
          <label>
            <span>Password</span>
            <input type="password" name="password" autofocus autocomplete="current-password">
          </label>
          <button type="submit">Sign in</button>
        </form>
      </section>
    """

    dashboard_section = f"""
      <section class="panel">
        <div class="topbar">
          <div>
            <h2>Token users</h2>
            <div class="muted">Premium auth feeds are issued here. Standard AllTick access stays in the app.</div>
          </div>
          <form method="post" action="/auth/logout">
            <button type="submit" class="ghost">Sign out</button>
          </form>
        </div>

        <div class="grid">
          <form id="createForm" class="form card">
            <h3>Create user</h3>
            <label><span>Username</span><input name="username" required placeholder="btc-user-001"></label>
            <label>
              <span>Group</span>
              <select name="group_name">
                {''.join(f'<option value="{escape(option["value"])}">{escape(option["label"])}</option>' for option in json.loads(groups_json))}
              </select>
            </label>
            <label><span>Expires after (days)</span><input type="number" name="expires_days" min="1" value="30"></label>
            <label class="inline"><input type="checkbox" name="enabled" checked>Enabled</label>
            <button type="submit">Create token</button>
          </form>

          <section class="card">
            <h3>Issued token</h3>
            <div class="muted">Shown once after create or rotate.</div>
            <pre id="issuedToken">No token yet.</pre>
            <button id="copyToken" class="ghost" type="button">Copy token</button>
          </section>
        </div>

        <section class="tableWrap">
          <table>
            <thead>
              <tr>
                <th>User</th>
                <th>Group</th>
                <th>Prefix</th>
                <th>Expires</th>
                <th>Enabled</th>
                <th>Last used</th>
                <th>Actions</th>
              </tr>
            </thead>
            <tbody id="userRows"></tbody>
          </table>
        </section>
      </section>
    """

    body = dashboard_section if authed else login_section
    return f"""<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>Token issuer</title>
  <style>
    :root {{
      color-scheme: dark;
      --bg: #0c1120;
      --panel: #111936;
      --line: #243156;
      --text: #e9eef8;
      --muted: #8e99b7;
      --accent: #5ac8fa;
      --good: #4cd964;
      --bad: #ff6b6b;
    }}
    html, body {{
      margin: 0;
      min-height: 100%;
      background: var(--bg);
      color: var(--text);
      font: 14px/1.45 -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif;
    }}
    main {{
      max-width: 1100px;
      margin: 0 auto;
      padding: 24px;
    }}
    h1, h2, h3, p {{ margin: 0; }}
    h1 {{ font-size: 26px; margin-bottom: 6px; }}
    h2 {{ font-size: 18px; }}
    h3 {{ font-size: 15px; margin-bottom: 12px; }}
    .muted {{ color: var(--muted); }}
    .panel, .card {{
      border: 1px solid var(--line);
      background: rgba(17, 25, 54, 0.92);
      border-radius: 12px;
      padding: 16px;
    }}
    .panel + .panel {{
      margin-top: 16px;
    }}
    .topbar {{
      display: flex;
      align-items: center;
      justify-content: space-between;
      gap: 12px;
      margin-bottom: 16px;
    }}
    .grid {{
      display: grid;
      grid-template-columns: 1fr 1fr;
      gap: 16px;
      margin-bottom: 16px;
    }}
    .form {{
      display: grid;
      gap: 12px;
    }}
    label {{
      display: grid;
      gap: 6px;
    }}
    label span {{
      color: var(--muted);
      font-size: 12px;
    }}
    label.inline {{
      display: flex;
      align-items: center;
      gap: 8px;
      color: var(--text);
    }}
    input, select, button, textarea {{
      border-radius: 8px;
      border: 1px solid var(--line);
      background: #0e1530;
      color: var(--text);
      padding: 10px 12px;
      font: inherit;
    }}
    button {{
      cursor: pointer;
      width: fit-content;
    }}
    button:hover {{
      border-color: var(--accent);
    }}
    button.ghost {{
      background: transparent;
    }}
    pre {{
      white-space: pre-wrap;
      word-break: break-word;
      margin: 12px 0;
      background: #0b1025;
      padding: 12px;
      border-radius: 8px;
      border: 1px solid var(--line);
      min-height: 60px;
    }}
    .status {{
      margin-top: 10px;
      color: var(--muted);
    }}
    .status.good {{ color: var(--good); }}
    .status.bad {{ color: var(--bad); }}
    .tableWrap {{
      overflow: auto;
    }}
    table {{
      width: 100%;
      border-collapse: collapse;
    }}
    th, td {{
      text-align: left;
      vertical-align: top;
      padding: 10px 8px;
      border-bottom: 1px solid rgba(36, 49, 86, 0.7);
    }}
    th {{
      color: var(--muted);
      font-weight: 600;
      font-size: 12px;
      text-transform: uppercase;
      letter-spacing: 0.03em;
    }}
    .rowActions {{
      display: grid;
      gap: 8px;
      grid-template-columns: repeat(2, minmax(0, 1fr));
    }}
    .rowActions button {{
      width: 100%;
      justify-content: center;
    }}
    .small {{
      font-size: 12px;
    }}
    .inlineRow {{
      display: grid;
      grid-template-columns: 1.2fr 1fr 1fr auto auto auto;
      gap: 8px;
      align-items: center;
    }}
    .inlineRow input, .inlineRow select {{
      width: 100%;
      min-width: 0;
    }}
    @media (max-width: 900px) {{
      .grid, .inlineRow {{
        grid-template-columns: 1fr;
      }}
      .rowActions {{
        grid-template-columns: 1fr;
      }}
    }}
  </style>
</head>
<body>
  <main>
    <h1>Token issuer</h1>
    <p class="muted">Premium clients exchange a private user token for a short-lived Centrifugo JWT.</p>
    {body}
  </main>
  <script>
    const GROUP_OPTIONS = {groups_json};
    const authenticated = {str(authed).lower()};
    const state = {{ users: [] }};
    const statusEl = document.createElement('div');
    statusEl.className = 'status';
    document.querySelector('main').appendChild(statusEl);

    function setStatus(text, kind = '') {{
      statusEl.className = `status ${{kind}}`.trim();
      statusEl.textContent = text;
    }}

    function formatDate(value) {{
      if (!value) return '--';
      try {{
        return new Date(value).toLocaleString();
      }} catch (_) {{
        return value;
      }}
    }}

    function escapeHtml(text) {{
      return String(text)
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;')
        .replaceAll("'", '&#39;');
    }}

    async function loadUsers() {{
      const res = await fetch('/auth/admin/api/users');
      if (!res.ok) {{
        setStatus('Failed to load users', 'bad');
        return;
      }}
      const data = await res.json();
      state.users = data.users || [];
      renderUsers();
    }}

    function renderUsers() {{
      const tbody = document.getElementById('userRows');
      if (!tbody) return;
      tbody.innerHTML = state.users.map((user) => {{
        const groupOptions = GROUP_OPTIONS.map((group) =>
          `<option value="${{escapeHtml(group.value)}}" ${{group.value === user.group_name ? 'selected' : ''}}>${{escapeHtml(group.label)}}</option>`
        ).join('');
        return `
          <tr data-id="${{user.id}}">
            <td>
              <div><strong>${{escapeHtml(user.username)}}</strong></div>
              <div class="muted small">#${{user.id}}</div>
            </td>
            <td>
              <select class="groupSelect">${{groupOptions}}</select>
            </td>
            <td>
              <code>${{escapeHtml(user.token_prefix)}}</code>
            </td>
            <td>
              <input class="expiresInput" type="date" value="${{escapeHtml((user.expires_at || '').slice(0, 10))}}">
            </td>
            <td>
              <label class="inline small">
                <input class="enabledInput" type="checkbox" ${{user.enabled ? 'checked' : ''}}>
                Enabled
              </label>
            </td>
            <td class="small muted">${{escapeHtml(formatDate(user.last_used_at))}}</td>
            <td>
              <div class="rowActions">
                <button type="button" class="ghost" data-action="save">Save</button>
                <button type="button" class="ghost" data-action="rotate">Rotate</button>
                <button type="button" class="ghost" data-action="delete">Delete</button>
              </div>
            </td>
          </tr>
        `;
      }}).join('');
    }}

    async function createUser(event) {{
      event.preventDefault();
      const form = event.currentTarget;
      const payload = {{
        username: form.username.value.trim(),
        group_name: form.group_name.value,
        expires_days: Number(form.expires_days.value || 0),
        enabled: form.enabled.checked,
      }};
      const res = await fetch('/auth/admin/api/users', {{
        method: 'POST',
        headers: {{ 'Content-Type': 'application/json' }},
        body: JSON.stringify(payload),
      }});
      const data = await res.json().catch(() => ({{}}));
      if (!res.ok) {{
        setStatus(data.error || 'Failed to create user', 'bad');
        return;
      }}
      document.getElementById('issuedToken').textContent = data.raw_token || 'No token returned.';
      setStatus(`Created ${{data.user.username}}`, 'good');
      form.reset();
      form.enabled.checked = true;
      form.group_name.value = GROUP_OPTIONS[0]?.value || 'btc_viewer';
      await loadUsers();
    }}

    async function patchUser(row) {{
      const userId = row.dataset.id;
      const payload = {{
        group_name: row.querySelector('.groupSelect').value,
        expires_at: row.querySelector('.expiresInput').value,
        enabled: row.querySelector('.enabledInput').checked,
      }};
      const res = await fetch(`/auth/admin/api/users/${{userId}}`, {{
        method: 'PATCH',
        headers: {{ 'Content-Type': 'application/json' }},
        body: JSON.stringify(payload),
      }});
      const data = await res.json().catch(() => ({{}}));
      if (!res.ok) {{
        setStatus(data.error || 'Failed to update user', 'bad');
        return;
      }}
      setStatus(`Updated ${{data.user.username}}`, 'good');
      await loadUsers();
    }}

    async function rotateUser(row) {{
      const userId = row.dataset.id;
      const res = await fetch(`/auth/admin/api/users/${{userId}}/rotate`, {{ method: 'POST' }});
      const data = await res.json().catch(() => ({{}}));
      if (!res.ok) {{
        setStatus(data.error || 'Failed to rotate token', 'bad');
        return;
      }}
      document.getElementById('issuedToken').textContent = data.raw_token || 'No token returned.';
      setStatus(`Rotated ${{data.user.username}}`, 'good');
      await loadUsers();
    }}

    async function deleteUser(row) {{
      const userId = row.dataset.id;
      if (!confirm('Delete this token user?')) return;
      const res = await fetch(`/auth/admin/api/users/${{userId}}`, {{ method: 'DELETE' }});
      const data = await res.json().catch(() => ({{}}));
      if (!res.ok) {{
        setStatus(data.error || 'Failed to delete user', 'bad');
        return;
      }}
      setStatus(`Deleted ${{data.username}}`, 'good');
      await loadUsers();
    }}

    document.getElementById('createForm')?.addEventListener('submit', createUser);
    document.getElementById('copyToken')?.addEventListener('click', async () => {{
      const token = document.getElementById('issuedToken').textContent || '';
      if (!token || token === 'No token yet.') return;
      try {{
        await navigator.clipboard.writeText(token);
        setStatus('Token copied', 'good');
      }} catch (_) {{
        setStatus('Clipboard unavailable', 'bad');
      }}
    }});

    document.getElementById('userRows')?.addEventListener('click', async (event) => {{
      const button = event.target.closest('button');
      if (!button) return;
      const row = event.target.closest('tr');
      if (!row) return;
      const action = button.dataset.action;
      if (action === 'save') await patchUser(row);
      if (action === 'rotate') await rotateUser(row);
      if (action === 'delete') await deleteUser(row);
    }});

    if (authenticated) {{
      loadUsers().catch(() => setStatus('Failed to load users', 'bad'));
    }}
  </script>
</body>
</html>"""


class IssuerHandler(BaseHTTPRequestHandler):
    server_version = "TokenIssuer/1.0"

    def do_GET(self) -> None:  # noqa: N802
        path = urlparse(self.path).path
        if path in {"/", "/auth"}:
            self.send_response(HTTPStatus.SEE_OTHER)
            self.send_header("Location", "/auth/admin")
            self.end_headers()
            return
        if path == "/health":
            return text_response(self, "ok\n")
        if path == "/auth/admin":
            return self.handle_admin_page()
        if path == "/auth/admin/api/users":
            if not self.require_admin():
                return
            return json_response(self, {"users": list_users()})
        return self.not_found()

    def do_POST(self) -> None:  # noqa: N802
        path = urlparse(self.path).path
        if path == "/auth/exchange":
            return self.handle_exchange()
        if path == "/auth/login":
            return self.handle_login()
        if path == "/auth/logout":
            return self.handle_logout()
        if path == "/auth/admin/api/users":
            if not self.require_admin():
                return
            return self.handle_create_user()
        if path.endswith("/rotate"):
            if not self.require_admin():
                return
            return self.handle_rotate_user(path)
        return self.not_found()

    def do_PATCH(self) -> None:  # noqa: N802
        path = urlparse(self.path).path
        if path.startswith("/auth/admin/api/users/"):
            if not self.require_admin():
                return
            return self.handle_update_user(path)
        return self.not_found()

    def do_DELETE(self) -> None:  # noqa: N802
        path = urlparse(self.path).path
        if path.startswith("/auth/admin/api/users/"):
            if not self.require_admin():
                return
            return self.handle_delete_user(path)
        return self.not_found()

    def do_OPTIONS(self) -> None:  # noqa: N802
        path = urlparse(self.path).path
        if path == "/auth/exchange":
            self.send_response(HTTPStatus.NO_CONTENT)
            self.send_cors_headers()
            self.send_header("Access-Control-Allow-Methods", "POST, OPTIONS")
            self.send_header("Access-Control-Allow-Headers", "Content-Type")
            self.end_headers()
            return
        self.send_response(HTTPStatus.NO_CONTENT)
        self.end_headers()

    def handle_admin_page(self) -> None:
        html_response(self, admin_page_html(self.is_admin_authenticated()))

    def handle_login(self) -> None:
        form = read_form_body(self)
        password = form.get("password", "").strip()
        if not ADMIN_PASSWORD or not hmac.compare_digest(password, ADMIN_PASSWORD):
            return html_response(self, admin_page_html(False), status=HTTPStatus.UNAUTHORIZED)

        token = create_admin_session()
        self.send_response(HTTPStatus.SEE_OTHER)
        self.send_header("Location", "/auth/admin")
        self.send_header("Set-Cookie", admin_session_cookie(token, SESSION_TTL_SECONDS))
        self.end_headers()

    def handle_logout(self) -> None:
        token = self.session_token()
        delete_admin_session(token)
        self.send_response(HTTPStatus.SEE_OTHER)
        self.send_header("Location", "/auth/admin")
        self.send_header("Set-Cookie", admin_session_cookie("", 0))
        self.end_headers()

    def handle_exchange(self) -> None:
        if self.command == "OPTIONS":
            return
        try:
            body = read_json_body(self)
        except Exception as exc:  # pragma: no cover
            return json_response(self, {"error": f"invalid json: {exc}"}, status=HTTPStatus.BAD_REQUEST, headers=self.cors_headers())

        raw_token = str(body.get("token", "")).strip()
        if not raw_token:
            return json_response(self, {"error": "token is required"}, status=HTTPStatus.BAD_REQUEST, headers=self.cors_headers())

        user = get_user_by_token(raw_token)
        if user is None:
            return json_response(self, {"error": "invalid token"}, status=HTTPStatus.UNAUTHORIZED, headers=self.cors_headers())
        if not user["enabled"]:
            return json_response(self, {"error": "token disabled"}, status=HTTPStatus.FORBIDDEN, headers=self.cors_headers())

        user_expires_at = parse_iso(user["expires_at"])
        if user_expires_at and user_expires_at <= now_utc():
            return json_response(self, {"error": "token expired"}, status=HTTPStatus.FORBIDDEN, headers=self.cors_headers())

        update_last_used(user["id"])
        centrifugo_token, jwt_expires_at = make_connection_jwt(user)
        payload = {
            "centrifugo_token": centrifugo_token,
            "channels": channels_for_group(user["group_name"]),
            "expires_at": jwt_expires_at,
            "websocket_url": derive_websocket_url(),
        }
        return json_response(self, payload, headers=self.cors_headers())

    def handle_create_user(self) -> None:
        try:
            body = read_json_body(self)
        except Exception as exc:
            return json_response(self, {"error": f"invalid json: {exc}"}, status=HTTPStatus.BAD_REQUEST)

        username = str(body.get("username", "")).strip()
        if not username:
            return json_response(self, {"error": "username is required"}, status=HTTPStatus.BAD_REQUEST)
        group_name = normalize_group(str(body.get("group_name", DEFAULT_GROUP)).strip())
        expires_days = int(body.get("expires_days") or 0)
        enabled = bool(body.get("enabled", True))
        expires_at = None
        if expires_days > 0:
            expires_at = isoformat(now_utc() + timedelta(days=expires_days))

        try:
            user, raw_token = create_user(username, group_name, expires_at, enabled)
        except sqlite3.IntegrityError:
            return json_response(self, {"error": "username already exists"}, status=HTTPStatus.CONFLICT)

        return json_response(self, {"user": user, "raw_token": raw_token})

    def handle_update_user(self, path: str) -> None:
        user_id = self.extract_user_id(path)
        if user_id is None:
            return self.not_found()
        try:
            body = read_json_body(self)
        except Exception as exc:
            return json_response(self, {"error": f"invalid json: {exc}"}, status=HTTPStatus.BAD_REQUEST)

        group_name = body.get("group_name")
        expires_at_raw = body.get("expires_at")
        expires_at = None if expires_at_raw == "" else parse_date_to_expiry(str(expires_at_raw)) if expires_at_raw is not None else None
        if expires_at_raw is not None and expires_at_raw != "" and expires_at is None:
            return json_response(self, {"error": "invalid expires_at"}, status=HTTPStatus.BAD_REQUEST)
        enabled_value = body.get("enabled")
        updated = update_user(user_id, str(group_name) if group_name is not None else None, expires_at, None if enabled_value is None else bool(enabled_value))
        if updated is None:
            return json_response(self, {"error": "user not found"}, status=HTTPStatus.NOT_FOUND)
        return json_response(self, {"user": updated})

    def handle_rotate_user(self, path: str) -> None:
        user_id = self.extract_user_id(path)
        if user_id is None:
            return self.not_found()
        user, raw_token = rotate_user_token(user_id)
        if user is None or raw_token is None:
            return json_response(self, {"error": "user not found"}, status=HTTPStatus.NOT_FOUND)
        return json_response(self, {"user": user, "raw_token": raw_token})

    def handle_delete_user(self, path: str) -> None:
        user_id = self.extract_user_id(path)
        if user_id is None:
            return self.not_found()
        with db() as conn:
            row = conn.execute("SELECT username FROM users WHERE id = ?", (user_id,)).fetchone()
        if row is None:
            return json_response(self, {"error": "user not found"}, status=HTTPStatus.NOT_FOUND)
        delete_user(user_id)
        return json_response(self, {"username": row["username"]})

    def require_admin(self) -> bool:
        if self.is_admin_authenticated():
            return True
        html_response(self, admin_page_html(False), status=HTTPStatus.UNAUTHORIZED)
        return False

    def is_admin_authenticated(self) -> bool:
        return self.session_token() is not None and is_admin_session_valid(self.session_token())

    def session_token(self) -> str | None:
        cookie = get_cookies(self)
        morsel = cookie.get(SESSION_COOKIE)
        return morsel.value if morsel else None

    def extract_user_id(self, path: str) -> int | None:
        parts = path.rstrip("/").split("/")
        if len(parts) < 6:
            return None
        try:
            return int(parts[5])
        except ValueError:
            return None

    def cors_headers(self) -> dict[str, str]:
        return self.send_cors_headers(as_dict=True)

    def send_cors_headers(self, as_dict: bool = False) -> dict[str, str] | None:
        headers = {
            "Access-Control-Allow-Origin": "*",
            "Access-Control-Allow-Headers": "Content-Type",
            "Access-Control-Allow-Methods": "POST, OPTIONS",
        }
        if as_dict:
            return headers
        for key, value in headers.items():
            self.send_header(key, value)
        return None

    def not_found(self) -> None:
        json_response(self, {"error": "not found"}, status=HTTPStatus.NOT_FOUND)

    def log_message(self, fmt: str, *args: Any) -> None:  # noqa: A003
        return


def main() -> None:
    if not ADMIN_PASSWORD:
        raise RuntimeError("TOKEN_ISSUER_ADMIN_PASSWORD is not set")
    if not JWT_SECRET:
        raise RuntimeError("CENTRIFUGO_CLIENT_TOKEN_HMAC_SECRET_KEY is not set")
    init_db()
    server = ThreadingHTTPServer((HOST, PORT), IssuerHandler)
    print(f"Token issuer listening on {HOST}:{PORT}")
    server.serve_forever()


if __name__ == "__main__":
    main()
