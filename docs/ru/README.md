# BlockNot

Самохостящийся мессенджер для семьи и друзей. Построен на Elixir/Phoenix и WebRTC.

## О проекте

BlockNot — pet-проект для изучения возможностей Phoenix: LiveView, Channels, Presence, PubSub и WebRTC. Название от русского слова «Блокнот» (записная книжка).

## MVP

- **Интерфейс в стиле Telegram** — тёмная тема, mobile-first дизайн с пузырями и индикатором набора
- **Чат в реальном времени** — текстовые сообщения, статус онлайн, история сообщений через Phoenix Channels
- **Голосовые и видеозвонки** — peer-to-peer через WebRTC, шифрование DTLS-SRTP
- **Вход через Telegram** — авторизация в один клик через Telegram Login Widget + инвайт-ссылки
- **Деплой** — Kamal 2 на Hetzner VPS с SSL

## Roadmap

После деплоя — по приоритету:

| Приоритет | Фича | Документация |
|-----------|------|-------------|
| 1 | Статусы сообщений (отправлено / доставлено / прочитано) | [architecture.md](../architecture.md) |
| 2 | Ответ, редактирование, удаление | [chat-features.md](../chat-features.md) |
| 3 | Разделители дат, последний визит | [chat-features.md](../chat-features.md) |
| 4 | PWA — установка как приложение + push-уведомления | [pwa.md](../pwa.md) |
| 5 | Офлайн-очередь сообщений | [architecture.md](../architecture.md) |
| 6 | Превью ссылок (OpenGraph) | [chat-features.md](../chat-features.md) |
| 7 | Контекстное меню, свайп для ответа | [chat-features.md](../chat-features.md) |

## Технологии

| Уровень | Технология |
|---------|-----------|
| Бэкенд | Elixir 1.18, Phoenix 1.8 (LiveView, Channels, PubSub) |
| База данных | PostgreSQL + Ecto |
| Звонки | WebRTC (встроен в браузер, peer-to-peer) |
| Фронтенд | Phoenix LiveView + минимум JavaScript |
| Авторизация | Telegram Login Widget |
| Деплой | Kamal 2 на Hetzner VPS |
| Шифрование | HTTPS/WSS в транзите, DTLS-SRTP для звонков |

## Быстрый старт

```bash
# 1. Клонируем
git clone https://github.com/your-username/blocknot.git
cd blocknot

# 2. Настраиваем окружение
cp .env.example .env
# Отредактируйте .env — укажите DATABASE_URL, TELEGRAM_BOT_TOKEN, SECRET_KEY_BASE

# 3. Устанавливаем зависимости
mix setup

# 4. Создаём базу данных
mix ecto.setup

# 5. Запускаем сервер
mix phx.server
```

Откройте [http://localhost:4000](http://localhost:4000) в браузере.

## Настройка Telegram-бота

1. Откройте [@BotFather](https://t.me/BotFather) в Telegram
2. Отправьте `/newbot`, следуйте инструкциям
3. Скопируйте токен бота в `.env` как `TELEGRAM_BOT_TOKEN`
4. Настройте домен: Bot Settings → Domain → `chat.example.com`

### Как пользователи входят

1. Вы создаёте инвайт-ссылку в настройках BlockNot
2. Делитесь ссылкой с другом
3. Друг открывает ссылку → нажимает **«Войти через Telegram»**
4. Один клик → в чате

Подробнее в [docs/auth.md](../auth.md).

## Деплой

```bash
kamal setup    # первый деплой
kamal deploy   # последующие деплои
```

Подробнее в [docs/deployment.md](../deployment.md) — Hetzner + SSL.

## Безопасность

- Весь трафик шифруется через HTTPS/WSS
- Звонки шифруются через DTLS-SRTP (обязательный стандарт WebRTC)
- Сквозного шифрования пока нет (планируется)

## Документация

**MVP:**
- [Дизайн UI](../ui-design.md) — mobile-first UI в стиле Telegram, компоненты LiveView, CSS
- [Авторизация и инвайты](../auth.md) — Telegram Login Widget, инвайт-ссылки
- [Архитектура](../architecture.md) — дизайн системы, WebRTC-сигналинг, схема БД
- [Установка](../setup.md) — настройка среды разработки
- [Деплой](../deployment.md) — Hetzner VPS + Kamal + SSL

**После деплоя:**
- [Фичи чата](../chat-features.md) — ответ, редактирование, удаление, превью ссылок, контекстное меню
- [PWA](../pwa.md) — установка как приложение, push-уведомления, офлайн

**Другое:**
- [English README](../../README.md)

## Лицензия

[MIT](../../LICENSE)
