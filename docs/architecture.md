# Architecture

## System Overview

```mermaid
graph TB
    subgraph Browser
        LV[Phoenix LiveView UI]
        WR[WebRTC Peer]
        SW[Service Worker / PWA]
    end

    subgraph "Phoenix App"
        CH[Phoenix Channels]
        LVS[LiveView Server]
        PR[Phoenix Presence]
        PS[Phoenix PubSub]
        EC[Ecto]
    end

    subgraph External
        PG[(PostgreSQL)]
        TG[Telegram Bot API]
    end

    LV <-->|WebSocket| LVS
    LV <-->|WebSocket| CH
    CH --> PS
    CH --> PR
    LVS --> EC
    CH --> EC
    EC --> PG
    WR <-.->|Peer-to-peer audio/video| WR
    CH -.->|Signaling only: SDP + ICE| WR
    TG -->|One-time token| CH
```

## Components

### Phoenix Channels — Real-time Messaging

Channels handle all real-time communication:

- **`room:lobby`** — general presence and notifications
- **`room:{id}`** — per-room messaging channel
- **`call:{room_id}`** — WebRTC signaling for a specific room

When a user sends a message:
1. Client pushes `"new_msg"` event to `room:{id}`
2. Channel handler saves the message to PostgreSQL via Ecto
3. Channel broadcasts the message to all subscribers via PubSub
4. All connected clients in the room receive the message instantly

### Phoenix LiveView — Reactive UI

LiveView renders the entire UI server-side and sends diffs over WebSocket:

- Room list and navigation
- Message rendering and scrolling
- User settings and profile
- Online presence indicators

Minimal JavaScript hooks handle:
- WebRTC peer connection setup
- Image paste/upload
- Scroll position management
- PWA install prompt

### Phoenix Presence — Online Status

Presence tracks who is online in real-time:

```
User joins room → Presence.track(socket, user_id, metadata)
User leaves/disconnects → automatically removed
Presence diff broadcast → UI updates online indicators
```

Uses CRDT (conflict-free replicated data type) under the hood — works correctly across multiple server nodes.

### Phoenix PubSub — Message Broadcasting

PubSub distributes messages across processes (and nodes in a cluster):

```
Channel receives message → PubSub.broadcast("room:123", event)
All subscribers on all nodes → receive the event
```

### Ecto + PostgreSQL — Persistence

All data is stored in PostgreSQL. Ecto provides:
- Schema definitions and validations
- Migrations for schema changes
- Query composition

## Database Schema

```mermaid
erDiagram
    users {
        bigint id PK
        string name
        bigint telegram_id UK
        string telegram_username
        string avatar_url
        timestamp inserted_at
        timestamp updated_at
    }

    rooms {
        bigint id PK
        string name
        string type "direct | group"
        timestamp inserted_at
        timestamp updated_at
    }

    room_members {
        bigint room_id FK
        bigint user_id FK
        timestamp joined_at
    }

    messages {
        bigint id PK
        text body
        string type "text | image"
        string status "sent | delivered | read"
        string client_id UK "UUID from client for dedup"
        bigint user_id FK
        bigint room_id FK
        timestamp delivered_at
        timestamp read_at
        timestamp inserted_at
    }

    message_reads {
        bigint message_id FK
        bigint user_id FK
        timestamp read_at
    }

    telegram_tokens {
        bigint id PK
        string token UK
        jsonb telegram_user
        timestamp used_at
        timestamp expires_at
    }

    push_subscriptions {
        bigint id PK
        bigint user_id FK
        string endpoint
        string p256dh
        string auth
        timestamp inserted_at
    }

    users ||--o{ room_members : "has many"
    rooms ||--o{ room_members : "has many"
    users ||--o{ messages : "sends"
    rooms ||--o{ messages : "contains"
    messages ||--o{ message_reads : "tracked by"
    users ||--o{ message_reads : "reads"
    users ||--o{ push_subscriptions : "has many"
```

### Relationships

- **users ↔ rooms**: many-to-many through `room_members`
- **rooms → messages**: one-to-many, a room contains many messages
- **users → messages**: one-to-many, a user sends many messages
- **messages → message_reads**: tracks which users have read each message (for group chats)
- **users → push_subscriptions**: Web Push endpoints for notifications
- **telegram_tokens**: standalone, linked to user by `telegram_user` JSONB data

## Message Delivery Statuses

Every message has a status visible to the sender:

| Status | Icon | Meaning |
|--------|------|---------|
| `sent` | &#10003; | Server received and saved the message |
| `delivered` | &#10003;&#10003; | Recipient's client received the message |
| `read` | &#10003;&#10003; (blue) | Recipient opened the chat and saw the message |

```mermaid
sequenceDiagram
    participant A as Sender
    participant S as Phoenix Server
    participant B as Recipient

    A->>S: push "new_msg" {body, client_id}
    S->>S: Save to DB (status: sent)
    S->>A: reply "msg_saved" {id, status: sent}
    Note over A: Shows ✓

    S->>B: broadcast "new_msg" {id, body, sender}
    B->>S: push "msg_delivered" {id}
    S->>S: Update status → delivered
    S->>A: broadcast "msg_status" {id, status: delivered}
    Note over A: Shows ✓✓

    Note over B: User opens chat
    B->>S: push "msg_read" {ids}
    S->>S: Update status → read
    S->>A: broadcast "msg_status" {ids, status: read}
    Note over A: Shows ✓✓ (blue)
```

In group chats, `message_reads` table tracks per-user read status. The message shows "read" when all members have seen it.

## Offline Message Queue

When the connection drops, messages don't get lost — they queue locally and send automatically on reconnect.

```mermaid
sequenceDiagram
    participant U as User
    participant SW as Service Worker
    participant IDB as IndexedDB
    participant S as Phoenix Server

    Note over U,S: Connection lost

    U->>SW: Send message
    SW->>IDB: Store in outbox queue
    SW->>U: Show ✓ (pending, gray)

    Note over U,S: Connection restored

    SW->>IDB: Read outbox queue
    loop For each queued message
        SW->>S: push "new_msg" {body, client_id}
        S->>S: Deduplicate by client_id
        S->>SW: reply "msg_saved" {id}
        SW->>IDB: Remove from outbox
        SW->>U: Update ✓ (sent)
    end
```

Key details:
- Each message gets a `client_id` (UUID) before sending — used for deduplication on the server
- IndexedDB stores the outbox queue — survives browser restarts
- Service Worker handles reconnection and queue flush
- Server ignores duplicate `client_id` values — safe to retry

## Smart Push Notifications

Notifications show the sender's name and message preview instead of generic "new message" text.

```mermaid
sequenceDiagram
    participant A as Sender
    participant S as Phoenix Server
    participant WP as Web Push API
    participant B as Recipient (offline)

    A->>S: push "new_msg" {body}
    S->>S: Save message
    S->>S: Check: is recipient online? (Presence)
    Note over S: Recipient is offline

    S->>S: Build notification payload
    S->>WP: Send push {title: "Мама", body: "Как ты там? Звони..."}
    WP->>B: System notification with preview
    Note over B: "Мама: Как ты там? Звони когда освободишься"
```

Notification features:
- **Sender name as title** — you see who wrote immediately
- **Message preview in body** — truncated to ~100 chars
- **Click opens the specific chat** — not just the app home page
- **Grouped by room** — multiple messages from one chat stack into one notification
- Uses standard Web Push API — works on Android, desktop browsers; iOS Safari 16.4+

## WebRTC Signaling Flow

WebRTC calls are peer-to-peer. The Phoenix server only handles signaling (exchanging connection metadata). No audio or video data passes through the server.

```mermaid
sequenceDiagram
    participant A as Caller Browser
    participant S as Phoenix Channel
    participant B as Callee Browser

    A->>S: join "call:room_id"
    B->>S: join "call:room_id"

    Note over A: User clicks "Call"
    A->>A: createOffer() → local SDP
    A->>S: push "offer" {sdp}
    S->>B: broadcast "offer" {sdp}

    B->>B: setRemoteDescription(offer)
    B->>B: createAnswer() → local SDP
    B->>S: push "answer" {sdp}
    S->>A: broadcast "answer" {sdp}

    A->>A: setRemoteDescription(answer)

    loop ICE Candidate Exchange
        A->>S: push "ice_candidate" {candidate}
        S->>B: broadcast "ice_candidate" {candidate}
        B->>S: push "ice_candidate" {candidate}
        S->>A: broadcast "ice_candidate" {candidate}
    end

    Note over A,B: Peer-to-peer connection established
    A<-->B: Audio/Video via DTLS-SRTP
```

### Steps Explained

1. Both users join the signaling channel `call:{room_id}`
2. Caller creates an SDP offer (description of what media they can send/receive)
3. Offer is relayed through the Phoenix Channel to the callee
4. Callee creates an SDP answer and sends it back
5. Both peers exchange ICE candidates (network path information)
6. Browser establishes a direct peer-to-peer connection
7. Audio/video flows directly between browsers, encrypted with DTLS-SRTP

## Authentication & Invites

See [auth.md](auth.md) for the full authentication and invite system documentation.

### Why Telegram?

- No passwords to remember or leak
- No email verification flow
- Telegram bots are easy to set up and free
- One-click login via Telegram Login Widget
