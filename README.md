# BlockNot

A learning project for exploring Elixir/Phoenix — a self-hosted chat application with voice calls and Telegram-based authentication.

## About

BlockNot is a pet project built to learn Phoenix framework features: LiveView, Channels, Presence, and PubSub. The name comes from the Russian word "Блокнот" (notebook).

## Features

- **Real-time chat** — text messages, image sharing, online presence, message history via Phoenix Channels
- **Voice & video calls** — peer-to-peer WebRTC, DTLS-SRTP encrypted
- **Telegram login** — passwordless authentication via one-time token from a Telegram bot
- **PWA** — installable from the browser, push notifications, offline support

## Tech Stack

| Layer | Technology |
|-------|-----------|
| Backend | Elixir 1.18, Phoenix 1.8 (LiveView, Channels, PubSub) |
| Database | PostgreSQL + Ecto |
| Real-time calls | WebRTC (browser-native, peer-to-peer) |
| Frontend | Phoenix LiveView + minimal JS hooks |
| PWA | Service Worker |
| Auth | Telegram Bot (magic token) |
| Deployment | Kamal 2 |
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
4. Set the bot's domain: `/setdomain` → your domain

Users authenticate by:
1. Opening an invite link that leads to the bot
2. The bot sends a one-time token
3. Entering the token on the website → done, logged in

## Deployment with Kamal

```bash
# First deploy
kamal setup

# Subsequent deploys
kamal deploy
```

See [docs/deployment.md](docs/deployment.md) for detailed instructions.

## Security

- All traffic encrypted via HTTPS/WSS
- WebRTC calls encrypted via DTLS-SRTP (mandatory browser standard)
- No end-to-end encryption in v1 (planned for v2)

## Limitations (v1)

- No end-to-end encryption yet
- No native mobile apps — PWA only
- No phone/PSTN calls — browser-to-browser only
- Designed for small groups (family, close friends)
- This is a learning project, not production-grade software

## Documentation

- [Architecture](docs/architecture.md) — system design, WebRTC flow, auth flow, database schema
- [Setup Guide](docs/setup.md) — development environment from scratch
- [Deployment](docs/deployment.md) — VPS + Kamal + SSL
- [README на русском](docs/ru/README.md)

## Contributing

This is a personal learning project, but contributions are welcome!

1. Fork the repo
2. Create a feature branch (`git checkout -b feature/my-feature`)
3. Commit your changes
4. Push and open a PR

## License

[MIT](LICENSE)
