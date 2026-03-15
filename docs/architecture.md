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
        bigint user_id FK
        bigint room_id FK
        timestamp inserted_at
    }

    telegram_tokens {
        bigint id PK
        string token UK
        jsonb telegram_user
        timestamp used_at
        timestamp expires_at
    }

    users ||--o{ room_members : "has many"
    rooms ||--o{ room_members : "has many"
    users ||--o{ messages : "sends"
    rooms ||--o{ messages : "contains"
```

### Relationships

- **users ↔ rooms**: many-to-many through `room_members`
- **rooms → messages**: one-to-many, a room contains many messages
- **users → messages**: one-to-many, a user sends many messages
- **telegram_tokens**: standalone, linked to user by `telegram_user` JSONB data

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

## Authentication Flow (Telegram)

```mermaid
sequenceDiagram
    participant U as User
    participant B as Browser
    participant S as Phoenix Server
    participant T as Telegram Bot

    U->>T: Opens invite link → starts bot
    T->>U: "Welcome! Here is your login token: ABC123"
    Note over T: Token stored in DB with expiry

    U->>B: Opens blocknot.example.com
    B->>S: GET /login
    S->>B: Login page with token input

    U->>B: Enters token "ABC123"
    B->>S: POST /auth/telegram {token: "ABC123"}
    S->>S: Lookup token in DB
    S->>S: Check not expired, not used
    S->>S: Create/find user from telegram_user data
    S->>S: Mark token as used
    S->>B: Set session cookie, redirect to /chat

    Note over U,B: User is now authenticated
```

### Why Telegram?

- No passwords to remember or leak
- No email verification flow
- Telegram bots are easy to set up and free
- Simple UX — users just enter a token
