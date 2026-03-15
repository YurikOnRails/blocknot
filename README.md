# BlockNot

Self-hosted messenger for family and friends. Built with Elixir/Phoenix and WebRTC.

## About

BlockNot is a pet project built to learn Phoenix framework features: LiveView, Channels, Presence, PubSub, and WebRTC. The name comes from the Russian word "Блокнот" (notebook).

## MVP Features

- **Telegram-style UI** — dark theme, mobile-first design with chat bubbles and typing indicators
- **Real-time chat** — text messages, online presence, message history via Phoenix Channels
- **Voice & video calls** — peer-to-peer WebRTC, DTLS-SRTP encrypted
- **Telegram login** — one-click auth via Telegram Login Widget + invite links
- **Deploy** — Kamal 2 on Hetzner VPS with SSL

## Roadmap

After deploy — by priority:

| Priority | Feature | Docs |
|----------|---------|------|
| 1 | Message statuses (sent / delivered / read) | [architecture.md](docs/architecture.md) |
| 2 | Reply, edit, delete messages | [chat-features.md](docs/chat-features.md) |
| 3 | Date separators, last seen | [chat-features.md](docs/chat-features.md) |
| 4 | PWA — install as app + push notifications | [pwa.md](docs/pwa.md) |
| 5 | Offline message queue | [architecture.md](docs/architecture.md) |
| 6 | Link previews (OpenGraph) | [chat-features.md](docs/chat-features.md) |
| 7 | Context menu, swipe-to-reply | [chat-features.md](docs/chat-features.md) |

## Tech Stack

| Layer | Technology |
|-------|-----------|
| Backend | Elixir 1.18, Phoenix 1.8 (LiveView, Channels, PubSub) |
| Database | PostgreSQL + Ecto |
| Real-time calls | WebRTC (browser-native, peer-to-peer) |
| Frontend | Phoenix LiveView + minimal JS hooks |
| Auth | Telegram Login Widget |
| Deployment | Kamal 2 on Hetzner VPS |
| Encryption | HTTPS/WSS in transit, DTLS-SRTP for calls |

## Quick Start

```bash
# 1. Clone
git clone https://github.com/your-username/blocknot.git
cd blocknot

# 2. Configure
cp .env.example .env
# Edit .env — set DATABASE_URL, TELEGRAM_BOT_TOKEN, SECRET_KEY_BASE

# 3. Install dependencies
mix setup

# 4. Create and migrate the database
mix ecto.setup

# 5. Start the server
mix phx.server
```

Open [http://localhost:4000](http://localhost:4000) in your browser.

## Configuration

| Variable | Description | Example |
|----------|-------------|---------|
| `DATABASE_URL` | PostgreSQL connection string | `ecto://postgres:postgres@localhost/blocknot_dev` |
| `SECRET_KEY_BASE` | Phoenix secret (generate with `mix phx.gen.secret`) | `long-random-string` |
| `TELEGRAM_BOT_TOKEN` | Bot token from [@BotFather](https://t.me/BotFather) | `123456:ABC-DEF...` |
| `TELEGRAM_BOT_USERNAME` | Bot username without @ | `blocknot_bot` |
| `PHX_HOST` | Your domain | `chat.example.com` |
| `PORT` | HTTP port | `4000` |

## Telegram Bot Setup

1. Open [@BotFather](https://t.me/BotFather) in Telegram
2. Send `/newbot`, follow the prompts
3. Copy the bot token to your `.env` file
4. Set the bot's domain: Bot Settings → Domain → `chat.example.com`

### How users join

1. You create an invite link in BlockNot settings
2. Share the link with a friend
3. Friend opens the link → clicks **"Log in with Telegram"**
4. One click → in the chat

See [docs/auth.md](docs/auth.md) for details.

## Deployment

```bash
kamal setup    # first deploy
kamal deploy   # subsequent deploys
```

See [docs/deployment.md](docs/deployment.md) for Hetzner + SSL setup.

## Security

- All traffic encrypted via HTTPS/WSS
- WebRTC calls encrypted via DTLS-SRTP (mandatory browser standard)
- No end-to-end encryption yet (planned)

## Documentation

**MVP:**
- [UI Design](docs/ui-design.md) — mobile-first Telegram-style UI, LiveView components, CSS
- [Auth & Invites](docs/auth.md) — Telegram Login Widget, invite links
- [Architecture](docs/architecture.md) — system design, WebRTC signaling, database schema
- [Setup Guide](docs/setup.md) — development environment from scratch
- [Deployment](docs/deployment.md) — Hetzner VPS + Kamal + SSL

**Post-launch:**
- [Chat Features](docs/chat-features.md) — reply, edit, delete, link previews, context menu
- [PWA](docs/pwa.md) — install as app, push notifications, offline support

**Other:**
- [README на русском](docs/ru/README.md)

## Contributing

This is a personal learning project, but contributions are welcome!

1. Fork the repo
2. Create a feature branch (`git checkout -b feature/my-feature`)
3. Commit your changes
4. Push and open a PR

## License

[MIT](LICENSE)
