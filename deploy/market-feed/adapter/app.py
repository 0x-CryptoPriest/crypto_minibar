from __future__ import annotations

import contextlib
import asyncio
import json
import logging
import os
import uuid
from dataclasses import dataclass
from datetime import UTC, datetime
from pathlib import Path
from typing import Any

import httpx
import websockets


LOG_LEVEL = os.getenv("LOG_LEVEL", "INFO").upper()
logging.basicConfig(level=LOG_LEVEL, format="%(asctime)s %(levelname)s %(name)s: %(message)s")
logger = logging.getLogger("market-feed-adapter")
logging.getLogger("httpx").setLevel(logging.WARNING)


@dataclass(frozen=True)
class Subscription:
    symbol: str
    channel: str


@dataclass(frozen=True)
class FeedConfig:
    name: str
    provider: str
    endpoint: str
    token_env: str
    heartbeat_seconds: int
    subscriptions: list[Subscription]


@dataclass(frozen=True)
class CentrifugoConfig:
    api_url: str
    api_key_env: str


@dataclass(frozen=True)
class AdapterConfig:
    centrifugo: CentrifugoConfig
    feeds: list[FeedConfig]


class ConfigError(RuntimeError):
    pass


class CentrifugoPublisher:
    def __init__(self, api_url: str, api_key: str) -> None:
        self._api_url = api_url.rstrip("/")
        self._api_key = api_key
        self._client = httpx.AsyncClient(timeout=httpx.Timeout(10.0, connect=10.0))

    async def close(self) -> None:
        await self._client.aclose()

    async def publish(self, channel: str, data: dict[str, Any]) -> None:
        response = await self._client.post(
            self._api_url,
            headers={"X-API-Key": self._api_key},
            json={"method": "publish", "params": {"channel": channel, "data": data}},
        )
        response.raise_for_status()
        body = response.json()
        if body.get("error"):
            raise RuntimeError(f"Centrifugo publish failed: {body['error']}")


class AllTickFeedRunner:
    def __init__(self, config: FeedConfig, publisher: CentrifugoPublisher) -> None:
        self._config = config
        self._publisher = publisher
        self._symbol_to_channel = {sub.symbol: sub.channel for sub in config.subscriptions}
        self._seq = 1

    async def run_forever(self) -> None:
        token = os.getenv(self._config.token_env, "").strip()
        if not token:
            raise ConfigError(f"{self._config.name}: missing env {self._config.token_env}")

        reconnect_delay = 1.0
        while True:
            try:
                await self._run_once(token)
                reconnect_delay = 1.0
            except asyncio.CancelledError:
                raise
            except Exception as exc:
                logger.exception("%s: upstream loop ended: %s", self._config.name, exc)
                await asyncio.sleep(reconnect_delay)
                reconnect_delay = min(reconnect_delay * 2, 30.0)

    async def _run_once(self, token: str) -> None:
        url = f"{self._config.endpoint}?token={token}"
        logger.info("%s: connecting to upstream", self._config.name)
        async with websockets.connect(url, ping_interval=None, close_timeout=5, max_size=2**20) as ws:
            await self._send_subscription(ws)
            heartbeat_task = asyncio.create_task(self._heartbeat_loop(ws))
            try:
                async for raw in ws:
                    await self._handle_message(raw)
            finally:
                heartbeat_task.cancel()
                with contextlib.suppress(asyncio.CancelledError):
                    await heartbeat_task

    async def _send_subscription(self, ws: websockets.WebSocketClientProtocol) -> None:
        payload = {
            "cmd_id": 22004,
            "seq_id": self._next_seq(),
            "trace": str(uuid.uuid4()),
            "data": {
                "symbol_list": [{"code": symbol} for symbol in self._symbol_to_channel],
            },
        }
        await ws.send(json.dumps(payload))
        logger.info("%s: subscribed to %s", self._config.name, ", ".join(self._symbol_to_channel))

    async def _heartbeat_loop(self, ws: websockets.WebSocketClientProtocol) -> None:
        while True:
            await asyncio.sleep(self._config.heartbeat_seconds)
            payload = {
                "cmd_id": 22000,
                "seq_id": self._next_seq(),
                "trace": str(uuid.uuid4()),
                "data": {},
            }
            try:
                await ws.send(json.dumps(payload))
            except Exception:
                return

    async def _handle_message(self, raw: Any) -> None:
        if isinstance(raw, bytes):
            text = raw.decode("utf-8", errors="replace")
        else:
            text = str(raw)

        try:
            message = json.loads(text)
        except json.JSONDecodeError:
            return

        if message.get("cmd_id") != 22998:
            return

        data = message.get("data") or {}
        symbol = data.get("code")
        channel = self._symbol_to_channel.get(symbol)
        price = data.get("price")
        if not channel or price in (None, ""):
            return

        payload = self._build_payload(symbol, channel, data)
        await self._publisher.publish(channel, payload)

    def _build_payload(self, symbol: str, channel: str, data: dict[str, Any]) -> dict[str, Any]:
        tick_time_raw = data.get("tick_time")
        tick_time_iso = self._tick_time_to_iso(tick_time_raw)
        volume = data.get("volume")

        payload: dict[str, Any] = {
            "feed": self._config.name,
            "provider": self._config.provider,
            "symbol": symbol,
            "channel": channel,
            "price": str(data.get("price")),
            "received_at": datetime.now(UTC).isoformat(),
        }
        if tick_time_raw not in (None, ""):
            payload["tick_time_raw"] = tick_time_raw
        if tick_time_iso:
            payload["tick_time"] = tick_time_iso
        if volume not in (None, ""):
            payload["volume"] = str(volume)
        return payload

    def _tick_time_to_iso(self, tick_time_raw: Any) -> str | None:
        if tick_time_raw in (None, ""):
            return None
        try:
            raw = float(tick_time_raw)
        except (TypeError, ValueError):
            return None
        seconds = raw / 1000 if raw > 10_000_000_000 else raw
        return datetime.fromtimestamp(seconds, tz=UTC).isoformat()

    def _next_seq(self) -> int:
        value = self._seq
        self._seq += 1
        return value


def load_config(path: Path) -> AdapterConfig:
    try:
        raw = json.loads(path.read_text())
    except FileNotFoundError as exc:
        raise ConfigError(f"config not found: {path}") from exc

    centrifugo_raw = raw.get("centrifugo") or {}
    centrifugo = CentrifugoConfig(
        api_url=_require_str(centrifugo_raw, "api_url"),
        api_key_env=centrifugo_raw.get("api_key_env", "CENTRIFUGO_HTTP_API_KEY"),
    )

    feeds_raw = raw.get("feeds")
    if not isinstance(feeds_raw, list) or not feeds_raw:
        raise ConfigError("feeds must be a non-empty array")

    feeds: list[FeedConfig] = []
    for index, feed_raw in enumerate(feeds_raw, start=1):
        provider = _require_str(feed_raw, "provider")
        if provider != "alltick":
            raise ConfigError(f"feed #{index}: unsupported provider {provider!r}")
        subs_raw = feed_raw.get("subscriptions")
        if not isinstance(subs_raw, list) or not subs_raw:
            raise ConfigError(f"feed #{index}: subscriptions must be a non-empty array")
        subscriptions = [
            Subscription(symbol=_require_str(sub, "symbol"), channel=_require_str(sub, "channel"))
            for sub in subs_raw
        ]
        feeds.append(
            FeedConfig(
                name=_require_str(feed_raw, "name"),
                provider=provider,
                endpoint=_require_str(feed_raw, "endpoint"),
                token_env=feed_raw.get("token_env", "ALLTICK_TOKEN"),
                heartbeat_seconds=int(feed_raw.get("heartbeat_seconds", 10)),
                subscriptions=subscriptions,
            )
        )

    return AdapterConfig(centrifugo=centrifugo, feeds=feeds)


def _require_str(obj: dict[str, Any], key: str) -> str:
    value = obj.get(key)
    if not isinstance(value, str) or not value.strip():
        raise ConfigError(f"missing required string field: {key}")
    return value.strip()


async def main() -> None:
    config_path = Path(os.getenv("ADAPTER_CONFIG_PATH", "/app/config/config.json"))
    config = load_config(config_path)

    api_key = os.getenv(config.centrifugo.api_key_env, "").strip()
    if not api_key:
        raise ConfigError(f"missing env {config.centrifugo.api_key_env}")

    publisher = CentrifugoPublisher(config.centrifugo.api_url, api_key)
    runners = [AllTickFeedRunner(feed, publisher) for feed in config.feeds]

    tasks = [asyncio.create_task(runner.run_forever()) for runner in runners]
    try:
        await asyncio.gather(*tasks)
    finally:
        for task in tasks:
            task.cancel()
        await publisher.close()


if __name__ == "__main__":
    try:
        asyncio.run(main())
    except ConfigError as exc:
        logger.error("%s", exc)
        raise SystemExit(1) from exc
