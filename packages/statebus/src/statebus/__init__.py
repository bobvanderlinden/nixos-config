"""
statebus — ndjson state pub/sub daemon over Unix sockets.

Two sockets:
  --publish   producers connect and send ndjson { type, key, ...data }
  --subscribe consumers connect, receive a full state replay, then live updates

Protocol:
  type "update"  upserts key in state and broadcasts to all subscribers
  type "remove"  deletes key from state and broadcasts to all subscribers

When a publisher disconnects, all keys it owned are automatically removed
and "remove" events are broadcast to all subscribers.
"""

import argparse
import asyncio
import json
import logging
import os

logger = logging.getLogger(__name__)

# key → last published object (the full original message)
state: dict[str, dict] = {}

# publisher StreamWriter → set of keys owned by that connection
publisher_keys: dict[asyncio.StreamWriter, set[str]] = {}

# active subscriber StreamWriters
subscribers: set[asyncio.StreamWriter] = set()


async def _send_line(writer: asyncio.StreamWriter, message: dict) -> bool:
    """Write one ndjson line to writer. Returns False if the connection is dead."""
    try:
        writer.write((json.dumps(message) + "\n").encode())
        await writer.drain()
        return True
    except (ConnectionResetError, BrokenPipeError, OSError):
        return False


async def _broadcast(message: dict) -> None:
    """Send a message to every subscriber, dropping dead connections."""
    dead: set[asyncio.StreamWriter] = set()
    for writer in list(subscribers):
        if not await _send_line(writer, message):
            dead.add(writer)
    subscribers.difference_update(dead)


async def handle_publisher(
    reader: asyncio.StreamReader,
    writer: asyncio.StreamWriter,
) -> None:
    publisher_keys[writer] = set()
    peer = writer.get_extra_info("peername") or "publisher"
    logger.info("publisher connected: %s", peer)

    try:
        async for raw_line in reader:
            line = raw_line.decode().strip()
            if not line:
                continue
            try:
                message = json.loads(line)
            except json.JSONDecodeError:
                logger.debug("ignoring malformed JSON from publisher: %r", line)
                continue

            key = message.get("key")
            if not key:
                logger.debug("ignoring message without key: %r", message)
                continue

            message_type = message.get("type")

            if message_type == "update":
                state[key] = message
                publisher_keys[writer].add(key)
                await _broadcast(message)

            elif message_type == "remove":
                state.pop(key, None)
                publisher_keys[writer].discard(key)
                await _broadcast({"type": "remove", "key": key})

    except (ConnectionResetError, BrokenPipeError, OSError):
        pass
    finally:
        logger.info("publisher disconnected: %s", peer)
        owned = publisher_keys.pop(writer, set())
        for key in owned:
            state.pop(key, None)
            await _broadcast({"type": "remove", "key": key})
        writer.close()


async def handle_subscriber(
    reader: asyncio.StreamReader,
    writer: asyncio.StreamWriter,
) -> None:
    peer = writer.get_extra_info("peername") or "subscriber"
    logger.info("subscriber connected: %s", peer)

    # Replay current state before adding to the live broadcast list.
    for message in list(state.values()):
        if not await _send_line(writer, message):
            logger.info("subscriber disconnected during replay: %s", peer)
            writer.close()
            return

    subscribers.add(writer)

    # Keep the connection open; subscribers are read-only so we just wait for EOF.
    try:
        await reader.read()
    except (ConnectionResetError, BrokenPipeError, OSError):
        pass
    finally:
        logger.info("subscriber disconnected: %s", peer)
        subscribers.discard(writer)
        writer.close()


def _remove_stale_socket(path: str) -> None:
    try:
        os.unlink(path)
        logger.debug("removed stale socket: %s", path)
    except FileNotFoundError:
        pass


async def run(publish_path: str, subscribe_path: str) -> None:
    _remove_stale_socket(publish_path)
    _remove_stale_socket(subscribe_path)

    publish_server = await asyncio.start_unix_server(handle_publisher, path=publish_path)
    subscribe_server = await asyncio.start_unix_server(handle_subscriber, path=subscribe_path)

    logger.info("publish  socket: %s", publish_path)
    logger.info("subscribe socket: %s", subscribe_path)

    async with publish_server, subscribe_server:
        await asyncio.gather(
            publish_server.serve_forever(),
            subscribe_server.serve_forever(),
        )


def main() -> None:
    parser = argparse.ArgumentParser(
        description="ndjson state pub/sub daemon over Unix sockets",
    )
    parser.add_argument(
        "--publish",
        required=True,
        metavar="SOCKET",
        help="path to the Unix socket that publishers connect to",
    )
    parser.add_argument(
        "--subscribe",
        required=True,
        metavar="SOCKET",
        help="path to the Unix socket that subscribers connect to",
    )
    parser.add_argument(
        "--log-level",
        default="INFO",
        choices=["DEBUG", "INFO", "WARNING", "ERROR"],
        help="logging verbosity (default: INFO)",
    )
    args = parser.parse_args()

    logging.basicConfig(
        level=getattr(logging, args.log_level),
        format="%(asctime)s %(levelname)s %(message)s",
    )

    asyncio.run(run(args.publish, args.subscribe))
