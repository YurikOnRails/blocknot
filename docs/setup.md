# Development Setup

## Prerequisites

| Tool | Version | Install |
|------|---------|---------|
| Elixir | 1.16+ | [asdf](https://asdf-vm.com/) or [official](https://elixir-lang.org/install.html) |
| Erlang/OTP | 26+ | Installed with Elixir via asdf |
| Node.js | 20+ | [asdf](https://asdf-vm.com/) or [nvm](https://github.com/nvm-sh/nvm) |
| PostgreSQL | 15+ | [official](https://www.postgresql.org/download/) |

### Installing with asdf (recommended)

```bash
# Install asdf plugins
asdf plugin add erlang
asdf plugin add elixir
asdf plugin add nodejs

# Install versions (from .tool-versions if present)
asdf install erlang 26.2.1
asdf install elixir 1.16.1-otp-26
asdf install nodejs 20.11.0

# Set as current
asdf global erlang 26.2.1
asdf global elixir 1.16.1-otp-26
asdf global nodejs 20.11.0
```

### PostgreSQL on Ubuntu/Debian

```bash
sudo apt install postgresql postgresql-contrib
sudo systemctl start postgresql

# Create a dev user (if needed)
sudo -u postgres createuser -s $USER
```

### PostgreSQL on macOS

```bash
brew install postgresql@15
brew services start postgresql@15
```

## Project Setup

```bash
# Clone the repo
git clone https://github.com/your-username/blocknot.git
cd blocknot

# Copy environment config
cp .env.example .env
```

Edit `.env` with your values:

```bash
# .env
DATABASE_URL=ecto://postgres:postgres@localhost/blocknot_dev
SECRET_KEY_BASE=generate-with-mix-phx-gen-secret
TELEGRAM_BOT_TOKEN=your-bot-token-from-botfather
TELEGRAM_BOT_USERNAME=your_bot_username
PHX_HOST=localhost
PORT=4000
```

Generate a secret:

```bash
mix phx.gen.secret
# Copy the output into SECRET_KEY_BASE
```

Install dependencies and set up the database:

```bash
# Install Elixir and Node.js dependencies
mix setup

# Create database, run migrations, seed data
mix ecto.setup

# Start the development server
mix phx.server
```

Open [http://localhost:4000](http://localhost:4000).

## Telegram Bot Setup

1. Open [BotFather](https://t.me/BotFather) in Telegram
2. Send `/newbot`
3. Choose a name (e.g., "BlockNot Dev Bot")
4. Choose a username (e.g., `blocknot_dev_bot`)
5. Copy the token — put it in `.env` as `TELEGRAM_BOT_TOKEN`
6. Send `/setdomain` to BotFather → select your bot → enter your domain

For local development, you can use [ngrok](https://ngrok.com/) to expose localhost:

```bash
ngrok http 4000
# Use the ngrok URL as your domain in BotFather
```

## Environment Variables Reference

| Variable | Required | Default | Description |
|----------|----------|---------|-------------|
| `DATABASE_URL` | Yes | — | PostgreSQL connection string |
| `SECRET_KEY_BASE` | Yes | — | Phoenix secret key, min 64 chars |
| `TELEGRAM_BOT_TOKEN` | Yes | — | Telegram bot API token |
| `TELEGRAM_BOT_USERNAME` | Yes | — | Bot username (without @) |
| `PHX_HOST` | Yes | `localhost` | Hostname for URL generation |
| `PORT` | No | `4000` | HTTP listener port |
| `POOL_SIZE` | No | `10` | Database connection pool size |
| `MIX_ENV` | No | `dev` | Elixir environment |

## Running Tests

```bash
# Run all tests
mix test

# Run with coverage
mix test --cover

# Run a specific test file
mix test test/blocknot/chat_test.exs
```

## Common Errors

### `(Postgrex.Error) FATAL: role "postgres" does not exist`

Create the postgres role:

```bash
sudo -u postgres createuser -s postgres
```

### `(Postgrex.Error) FATAL: database "blocknot_dev" does not exist`

Create the database:

```bash
mix ecto.create
```

### `** (Mix) Could not compile dependency :phoenix`

Update Elixir/Erlang to the required versions:

```bash
asdf install erlang 26.2.1
asdf install elixir 1.16.1-otp-26
```

### WebRTC calls don't work on localhost

WebRTC requires HTTPS in production, but works on `localhost` without it. If testing between devices on a local network, you need to use HTTPS or `ngrok`.

### Telegram webhook not receiving updates

- Check that your domain is set correctly in BotFather
- Verify the bot token is correct
- For local dev, ensure ngrok is running and URL is up to date
