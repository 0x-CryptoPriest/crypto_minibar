# Market Feed Bridge

This deployment bridges AllTick BTC ticks into Centrifugo and exposes:

- `wss://blackphoenix.online/connection/websocket`
- `https://blackphoenix.online/auth/admin`
- `https://blackphoenix.online/`

Standard access stays in the mac app with an AllTick API key.
Premium access uses a private user token exchanged at `/auth/exchange`.

## What it does

- Connects to AllTick BTC websocket upstream
- Parses BTC tick updates
- Publishes them into Centrifugo over HTTP API
- Serves a browser test page for the authenticated BTC feed
- Serves an admin page for issuing and revoking user tokens

## Notes

- Set `ALLTICK_TOKEN` in the server `.env` before starting.
- Centrifugo admin UI is enabled and protected by `CENTRIFUGO_ADMIN_PASSWORD` and `CENTRIFUGO_ADMIN_SECRET`.
- `CENTRIFUGO_CLIENT_ALLOW_ANONYMOUS_CONNECT_WITHOUT_TOKEN=false`.
- The `btc_viewer` group is currently authorized for `market:btc` only.
