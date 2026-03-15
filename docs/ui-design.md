# UI Design — Telegram-style Interface

BlockNot's UI closely follows Telegram's dark mode design. Mobile-first, built with Phoenix LiveView + CSS — no React, no component libraries.

## Design Principles

- **Familiar** — layout, colors, bubble shapes, and interactions match Telegram
- **Mobile-first** — designed for phones, scales up to desktop
- **CSS-only** — all visual effects (bubble tails, typing dots, patterns) are pure CSS
- **Dark theme only** — matches Telegram's dark mode

## Mobile Layout (Primary)

Two full-screen views with slide transition:

```
 ┌─ Chat List ──────────┐      ┌─ Chat View ────────────┐
 │  BlockNot        🔍   │      │  ← Мама          📞 ⋮  │
 ├───────────────────────┤      ├────────────────────────┤
 │                       │      │                        │
 │  🟢 Мама             │ tap  │  ┌──────────────┐      │
 │  Привет! Как дела?   │ ──→  │  │ Привет!      │      │
 │                       │      │  │ Как дела?    │      │
 │  Папа                 │      │  └──────────────┘      │
 │  Фото                 │      │                        │
 │                       │      │    ┌─────────────────┐ │
 │  👥 Семья        3    │      │    │ Хорошо! ✓✓     │ │
 │  Кто завтра приедет?  │      │    └─────────────────┘ │
 │                       │      │                        │
 │                       │      ├────────────────────────┤
 │                       │      │ [Message...]     📎 ➤  │
 └───────────────────────┘      └────────────────────────┘
```

- Chat list = full screen
- Tap chat → slides to chat view (full screen)
- Back button (←) → slides back to chat list
- No split view on mobile

## Desktop Layout (768px+)

Side-by-side layout like Telegram Desktop:

```
┌─────────────┬──────────────────────────────────┐
│  BlockNot 🔍│  Мама               online  📞 ⋮ │
├─────────────┼──────────────────────────────────┤
│             │                                  │
│ 🟢 Мама    │  ┌──────────────┐                │
│  Привет!   │  │ Привет!      │                │
│             │  │ Как дела?    │                │
│  Папа      │  └──────────────┘                │
│  Фото      │                                  │
│             │       ┌─────────────────┐        │
│ 👥 Семья  3│       │ Хорошо! ✓✓     │        │
│  Кто завтра │       └─────────────────┘        │
│             │                                  │
│             ├──────────────────────────────────┤
│             │ [Message...]             📎  ➤   │
└─────────────┴──────────────────────────────────┘
```

- Sidebar: fixed 320px
- Chat area: fills remaining space
- Both visible simultaneously

## Color Palette

```css
:root {
  --accent: #2AABEE;           /* Telegram blue */
  --bg-primary: #212121;       /* main background */
  --bg-secondary: #2b2b2b;     /* sidebar, headers */
  --bg-hover: #333333;         /* hover states */
  --bubble-in: #2b2b2b;        /* incoming messages */
  --bubble-out: #2b5278;       /* outgoing messages */
  --text-primary: #ffffff;
  --text-secondary: #8e8e8e;
  --online: #4dcd5e;           /* online indicator */
  --divider: #333333;
  --danger: #e53935;
}
```

## Typography

```html
<!-- root.html.heex -->
<link href="https://fonts.googleapis.com/css2?family=Inter:wght@400;500;600&display=swap" rel="stylesheet">
```

```css
body {
  font-family: 'Inter', -apple-system, BlinkMacSystemFont, sans-serif;
  font-size: 16px;       /* mobile-friendly base size */
  line-height: 1.4;
  background: var(--bg-primary);
  color: var(--text-primary);
  margin: 0;
  overflow: hidden;       /* prevent body scroll, scroll inside containers */
  height: 100dvh;         /* dynamic viewport height (handles mobile keyboard) */
}
```

## LiveView — Navigation State

The app uses a single LiveView with a `@view` assign to switch between chat list and chat:

```elixir
defmodule BlocknotWeb.ChatLive.Index do
  use BlocknotWeb, :live_view

  # Mobile: show chat list or chat view
  # Desktop: show both simultaneously (CSS handles layout)
  def mount(_params, _session, socket) do
    {:ok, assign(socket,
      view: :list,           # :list or :chat
      active_chat_id: nil,
      chats: list_chats(socket.assigns.current_user)
    )}
  end

  def handle_event("open_chat", %{"id" => id}, socket) do
    {:noreply, socket
      |> assign(view: :chat, active_chat_id: String.to_integer(id))
      |> load_messages(id)}
  end

  def handle_event("back_to_list", _, socket) do
    {:noreply, assign(socket, view: :list)}
  end
end
```

## LiveView Components

### App Shell

```heex
<!-- The wrapper has a data attribute so CSS can toggle views -->
<div class="app" data-view={@view}>
  <!-- Chat List (sidebar on desktop, full screen on mobile) -->
  <aside class="chat-list">
    <.chat_list_header />
    <.chat_list items={@chats} active_id={@active_chat_id} />
  </aside>

  <!-- Chat View (main area on desktop, full screen on mobile) -->
  <main :if={@active_chat_id} class="chat-view">
    <.chat_header room={@room} online={@chat_user_online} />
    <.message_area streams={@streams} current_user={@current_user} room={@room} />
    <.message_input replying_to={@replying_to} editing={@editing_message} />
  </main>

  <!-- Empty state when no chat selected (desktop only) -->
  <main :if={!@active_chat_id} class="chat-view chat-empty">
    <p>Select a chat to start messaging</p>
  </main>
</div>
```

### Chat List Header (mobile)

```heex
<header class="list-header">
  <button phx-click="open_menu" class="icon-btn">
    <.icon name="hero-bars-3" />
  </button>
  <h1>BlockNot</h1>
  <button phx-click="toggle_search" class="icon-btn">
    <.icon name="hero-magnifying-glass" />
  </button>
</header>
```

### Chat Header (mobile — with back button)

```heex
<header class="chat-header">
  <button phx-click="back_to_list" class="icon-btn back-btn">
    <.icon name="hero-arrow-left" />
  </button>

  <div class="avatar-sm" style={"background: #{avatar_color(@room.name)}"}>
    <%= String.first(@room.name) %>
  </div>

  <div class="header-info">
    <span class="header-name"><%= @room.name %></span>
    <span class={"header-status #{if @online, do: "online"}"}>
      <%= if @online, do: "online", else: format_last_seen(@room.last_seen_at) %>
    </span>
  </div>

  <div class="header-actions">
    <button phx-click="start_call" class="icon-btn">
      <.icon name="hero-phone" />
    </button>
    <button phx-click="open_room_menu" class="icon-btn">
      <.icon name="hero-ellipsis-vertical" />
    </button>
  </div>
</header>
```

### Chat List Item

```heex
<div :for={chat <- @items}
     phx-click="open_chat"
     phx-value-id={chat.id}
     class={"chat-item #{if chat.id == @active_id, do: "active"}"}>

  <div class="avatar" style={"background: #{avatar_color(chat.name)}"}>
    <%= String.first(chat.name) %>
    <div :if={chat.online} class="online-dot"></div>
  </div>

  <div class="chat-info">
    <div class="chat-top-row">
      <span class="chat-name"><%= chat.name %></span>
      <span class="chat-time"><%= format_relative(chat.last_message_at) %></span>
    </div>
    <div class="chat-bottom-row">
      <span class="chat-preview"><%= truncate(chat.last_message, 35) %></span>
      <span :if={chat.unread > 0} class="unread-badge"><%= chat.unread %></span>
    </div>
  </div>
</div>
```

### Message Bubbles

```heex
<div id="messages" class="messages-container" phx-update="stream" phx-hook="ScrollToBottom">
  <div :for={{dom_id, msg} <- @streams.messages}
       id={dom_id}
       class={"msg-row #{if msg.user_id == @current_user.id, do: "out", else: "in"}"}>

    <div class={"bubble #{if msg.user_id == @current_user.id, do: "out", else: "in"}"}>
      <!-- Sender name in group chats -->
      <div :if={@room.type == :group && msg.user_id != @current_user.id}
           class="msg-sender"
           style={"color: #{avatar_color(msg.user.name)}"}>
        <%= msg.user.name %>
      </div>

      <!-- Message body -->
      <p class="msg-text"><%= msg.body %></p>

      <!-- Image if present -->
      <img :if={msg.type == :image} src={msg.body} class="msg-image" loading="lazy" />

      <!-- Time + status -->
      <div class="msg-meta">
        <span class="msg-time"><%= format_time(msg.inserted_at) %></span>
        <span :if={msg.user_id == @current_user.id} class={"msg-status #{msg.status}"}>
          <%= status_icon(msg.status) %>
        </span>
      </div>
    </div>
  </div>

  <!-- Typing indicator -->
  <div :if={@typing_users != []} class="msg-row in">
    <div class="bubble in typing-bubble">
      <div class="typing-dots">
        <span class="dot"></span>
        <span class="dot"></span>
        <span class="dot"></span>
      </div>
    </div>
  </div>
</div>
```

Helper for status icons:

```elixir
defp status_icon(:sent),      do: "✓"
defp status_icon(:delivered),  do: "✓✓"
defp status_icon(:read),       do: "✓✓"  # styled blue via CSS class
```

### Message Input

```heex
<div class="input-area">
  <!-- Reply/edit bar -->
  <div :if={@replying_to} class="reply-bar">
    <div class="reply-bar-line"></div>
    <div class="reply-bar-content">
      <span class="reply-bar-name"><%= @replying_to.user.name %></span>
      <span class="reply-bar-text"><%= truncate(@replying_to.body, 50) %></span>
    </div>
    <button phx-click="cancel_reply" class="icon-btn"><.icon name="hero-x-mark" /></button>
  </div>

  <form phx-submit="send_message" class="input-row">
    <button type="button" phx-click="attach_file" class="icon-btn">
      <.icon name="hero-paper-clip" />
    </button>

    <textarea
      id="msg-input"
      name="body"
      placeholder="Message..."
      phx-hook="MessageInput"
      phx-keydown="typing"
      rows="1"
    />

    <button type="submit" class="send-btn">
      <.icon name="hero-paper-airplane-solid" />
    </button>
  </form>
</div>
```

JS hook — Enter to send on desktop, auto-resize on both:

```javascript
// assets/js/hooks/message_input.js
export const MessageInput = {
  mounted() {
    const isMobile = window.matchMedia("(max-width: 768px)").matches;

    this.el.addEventListener("keydown", (e) => {
      // Desktop: Enter sends, Shift+Enter = newline
      // Mobile: Enter = newline (on-screen keyboard has its own send)
      if (!isMobile && e.key === "Enter" && !e.shiftKey) {
        e.preventDefault();
        this.el.closest("form").dispatchEvent(
          new Event("submit", { bubbles: true, cancelable: true })
        );
        this.el.value = "";
        this.el.style.height = "auto";
      }
    });

    // Auto-resize textarea
    this.el.addEventListener("input", () => {
      this.el.style.height = "auto";
      this.el.style.height = Math.min(this.el.scrollHeight, 120) + "px";
    });
  }
};
```

## CSS — Mobile First

### Base Layout

```css
/* Mobile-first: app is a single column */
.app {
  display: flex;
  flex-direction: column;
  height: 100dvh;
  width: 100%;
  background: var(--bg-primary);
}

/* Chat list — full screen on mobile */
.chat-list {
  display: flex;
  flex-direction: column;
  width: 100%;
  height: 100dvh;
  overflow-y: auto;
  -webkit-overflow-scrolling: touch;
}

/* Chat view — full screen on mobile */
.chat-view {
  display: none;    /* hidden by default on mobile */
  flex-direction: column;
  width: 100%;
  height: 100dvh;
}

/* When a chat is open on mobile — show chat, hide list */
.app[data-view="chat"] .chat-list { display: none; }
.app[data-view="chat"] .chat-view { display: flex; }

/* Empty state — hidden on mobile */
.chat-empty { display: none; }
```

### Desktop Override (768px+)

```css
@media (min-width: 769px) {
  .app {
    flex-direction: row;
  }

  .chat-list {
    width: 320px;
    min-width: 320px;
    border-right: 1px solid var(--divider);
    /* Always visible on desktop regardless of data-view */
    display: flex !important;
  }

  .chat-view {
    flex: 1;
    /* Always visible on desktop regardless of data-view */
    display: flex !important;
  }

  .chat-empty {
    display: flex;
    align-items: center;
    justify-content: center;
    color: var(--text-secondary);
  }

  /* Hide back button on desktop */
  .back-btn { display: none; }
}
```

### View Transition (mobile slide animation)

```css
@media (max-width: 768px) {
  .chat-list,
  .chat-view {
    position: absolute;
    inset: 0;
    transition: transform 0.25s ease;
  }

  /* Chat list slides out left */
  .app[data-view="chat"] .chat-list {
    display: flex;
    transform: translateX(-100%);
  }

  /* Chat view slides in from right */
  .app[data-view="list"] .chat-view {
    display: flex;
    transform: translateX(100%);
  }

  .app[data-view="chat"] .chat-view {
    display: flex;
    transform: translateX(0);
  }
}
```

### Headers

```css
.list-header,
.chat-header {
  display: flex;
  align-items: center;
  gap: 12px;
  padding: 8px 12px;
  background: var(--bg-secondary);
  height: 56px;
  flex-shrink: 0;
}

.list-header h1 {
  flex: 1;
  font-size: 20px;
  font-weight: 600;
  margin: 0;
}

.header-info {
  flex: 1;
  display: flex;
  flex-direction: column;
  min-width: 0;       /* allow text truncation */
}

.header-name {
  font-size: 16px;
  font-weight: 600;
  white-space: nowrap;
  overflow: hidden;
  text-overflow: ellipsis;
}

.header-status {
  font-size: 13px;
  color: var(--text-secondary);
}

.header-status.online {
  color: var(--online);
}

.header-actions {
  display: flex;
  gap: 4px;
}

.avatar-sm {
  width: 36px;
  height: 36px;
  border-radius: 50%;
  display: flex;
  align-items: center;
  justify-content: center;
  font-weight: 600;
  font-size: 14px;
  color: white;
  flex-shrink: 0;
}
```

### Chat List Items

```css
.chat-item {
  display: flex;
  align-items: center;
  gap: 12px;
  padding: 8px 12px;
  cursor: pointer;
  transition: background 0.15s;
  min-height: 64px;       /* comfortable touch target */
}

.chat-item:active { background: var(--bg-hover); }   /* mobile: touch feedback */

@media (min-width: 769px) {
  .chat-item:hover { background: var(--bg-hover); }  /* desktop: hover */
}

.chat-item.active { background: var(--accent); }

.avatar {
  width: 48px;
  height: 48px;
  border-radius: 50%;
  display: flex;
  align-items: center;
  justify-content: center;
  font-weight: 600;
  font-size: 18px;
  color: white;
  position: relative;
  flex-shrink: 0;
}

.online-dot {
  width: 12px;
  height: 12px;
  background: var(--online);
  border: 2px solid var(--bg-secondary);
  border-radius: 50%;
  position: absolute;
  bottom: 0;
  right: 0;
}

.chat-info {
  flex: 1;
  min-width: 0;        /* allow text truncation */
  display: flex;
  flex-direction: column;
  gap: 2px;
}

.chat-top-row,
.chat-bottom-row {
  display: flex;
  justify-content: space-between;
  align-items: center;
  gap: 8px;
}

.chat-name {
  font-size: 15px;
  font-weight: 500;
  white-space: nowrap;
  overflow: hidden;
  text-overflow: ellipsis;
}

.chat-time {
  font-size: 12px;
  color: var(--text-secondary);
  flex-shrink: 0;
}

.chat-preview {
  font-size: 14px;
  color: var(--text-secondary);
  white-space: nowrap;
  overflow: hidden;
  text-overflow: ellipsis;
}

.unread-badge {
  background: var(--accent);
  color: white;
  font-size: 11px;
  font-weight: 600;
  min-width: 20px;
  height: 20px;
  padding: 0 6px;
  border-radius: 10px;
  display: flex;
  align-items: center;
  justify-content: center;
  flex-shrink: 0;
}
```

### Bubble Shapes

```css
.messages-container {
  position: relative;
  flex: 1;
  overflow-y: auto;
  -webkit-overflow-scrolling: touch;
  display: flex;
  flex-direction: column;
  padding: 8px 12px;
  gap: 2px;
}

/* Background dot pattern */
.messages-container::before {
  content: '';
  position: absolute;
  inset: 0;
  background-image: radial-gradient(
    circle at 1px 1px,
    rgba(255, 255, 255, 0.02) 1px,
    transparent 0
  );
  background-size: 24px 24px;
  pointer-events: none;
}

.msg-row {
  display: flex;
  position: relative;
  z-index: 1;
}

.msg-row.in  { justify-content: flex-start; }
.msg-row.out { justify-content: flex-end; }

.bubble {
  max-width: 80%;          /* wider on mobile than desktop */
  padding: 6px 10px;
  border-radius: 12px;
  word-wrap: break-word;
  overflow-wrap: break-word;
}

@media (min-width: 769px) {
  .bubble { max-width: 55%; }
}

.bubble.in {
  background: var(--bubble-in);
  border-bottom-left-radius: 4px;
}

.bubble.out {
  background: var(--bubble-out);
  border-bottom-right-radius: 4px;
}

.msg-text {
  margin: 0;
  font-size: 15px;
  white-space: pre-wrap;
}

.msg-image {
  max-width: 100%;
  border-radius: 8px;
  margin: 4px 0;
}

.msg-sender {
  font-size: 13px;
  font-weight: 600;
  margin-bottom: 2px;
}

.msg-meta {
  display: flex;
  justify-content: flex-end;
  align-items: center;
  gap: 4px;
  margin-top: 2px;
}

.msg-time {
  font-size: 11px;
  color: rgba(255, 255, 255, 0.5);
}

.msg-status         { font-size: 12px; color: rgba(255, 255, 255, 0.5); }
.msg-status.sent    { color: rgba(255, 255, 255, 0.5); }
.msg-status.delivered { color: rgba(255, 255, 255, 0.5); }
.msg-status.read    { color: var(--accent); }
```

### Message Input

```css
.input-area {
  display: flex;
  flex-direction: column;
  background: var(--bg-secondary);
  flex-shrink: 0;
  padding-bottom: env(safe-area-inset-bottom);  /* iPhone notch / home bar */
}

.input-row {
  display: flex;
  align-items: flex-end;
  gap: 4px;
  padding: 6px 8px;
}

.input-row textarea {
  flex: 1;
  background: var(--bg-primary);
  border: none;
  border-radius: 20px;
  padding: 8px 16px;
  color: var(--text-primary);
  font-size: 16px;                 /* prevents iOS zoom on focus */
  font-family: inherit;
  resize: none;
  max-height: 120px;
  outline: none;
  line-height: 1.4;
}

.input-row textarea::placeholder {
  color: var(--text-secondary);
}

.icon-btn {
  width: 40px;
  height: 40px;
  display: flex;
  align-items: center;
  justify-content: center;
  background: none;
  border: none;
  color: var(--text-secondary);
  cursor: pointer;
  border-radius: 50%;
  flex-shrink: 0;
  -webkit-tap-highlight-color: transparent;
}

.icon-btn:active {
  background: var(--bg-hover);
}

.send-btn {
  width: 40px;
  height: 40px;
  display: flex;
  align-items: center;
  justify-content: center;
  background: var(--accent);
  border: none;
  color: white;
  cursor: pointer;
  border-radius: 50%;
  flex-shrink: 0;
}
```

### Typing Indicator

```css
.typing-dots {
  display: flex;
  gap: 4px;
  padding: 4px 0;
}

.typing-dots .dot {
  width: 6px;
  height: 6px;
  border-radius: 50%;
  background: var(--text-secondary);
  animation: typing 1.4s infinite;
}

.typing-dots .dot:nth-child(2) { animation-delay: 0.2s; }
.typing-dots .dot:nth-child(3) { animation-delay: 0.4s; }

@keyframes typing {
  0%, 60%, 100% { transform: translateY(0); opacity: 0.4; }
  30%           { transform: translateY(-4px); opacity: 1; }
}
```

### Reply Bar

```css
.reply-bar {
  display: flex;
  align-items: center;
  gap: 8px;
  padding: 8px 12px;
  border-bottom: 1px solid var(--divider);
}

.reply-bar-line {
  width: 2px;
  min-height: 32px;
  background: var(--accent);
  border-radius: 1px;
  flex-shrink: 0;
}

.reply-bar-name {
  font-size: 13px;
  font-weight: 600;
  color: var(--accent);
}

.reply-bar-text {
  font-size: 13px;
  color: var(--text-secondary);
  white-space: nowrap;
  overflow: hidden;
  text-overflow: ellipsis;
}
```

## Mobile-specific Behaviors

### Virtual Keyboard Handling

When the keyboard opens on mobile, the chat should not jump around:

```css
/* Use dvh to handle keyboard resize */
.app {
  height: 100dvh;  /* dynamic viewport height */
}

/* Prevent scroll bounce on iOS */
.chat-list,
.messages-container {
  overscroll-behavior: contain;
}
```

```javascript
// assets/js/hooks/keyboard_resize.js
export const KeyboardResize = {
  mounted() {
    if (!window.visualViewport) return;

    window.visualViewport.addEventListener("resize", () => {
      // Adjust app height when virtual keyboard opens/closes
      document.documentElement.style.setProperty(
        "--app-height",
        `${window.visualViewport.height}px`
      );
    });
  }
};
```

```css
:root {
  --app-height: 100dvh;
}

.app {
  height: var(--app-height);
}
```

### Touch Gestures — Swipe to Reply

```javascript
// assets/js/hooks/swipe_reply.js
export const SwipeReply = {
  mounted() {
    let startX = 0;
    let currentX = 0;
    let swiping = false;

    this.el.addEventListener("touchstart", (e) => {
      startX = e.touches[0].clientX;
      swiping = true;
    }, { passive: true });

    this.el.addEventListener("touchmove", (e) => {
      if (!swiping) return;
      currentX = e.touches[0].clientX;
      const diff = currentX - startX;

      // Only allow right swipe on incoming, left swipe on outgoing
      const isOut = this.el.classList.contains("out");
      const valid = isOut ? diff < 0 : diff > 0;
      if (!valid) return;

      const offset = Math.min(Math.abs(diff), 80);
      this.el.style.transform = `translateX(${isOut ? -offset : offset}px)`;

      // Show reply icon when swiped enough
      if (offset > 60) {
        this.el.classList.add("swipe-ready");
      } else {
        this.el.classList.remove("swipe-ready");
      }
    }, { passive: true });

    this.el.addEventListener("touchend", () => {
      if (this.el.classList.contains("swipe-ready")) {
        const msgId = this.el.dataset.msgId;
        this.pushEvent("start_reply", { id: msgId });
      }

      this.el.style.transform = "";
      this.el.classList.remove("swipe-ready");
      swiping = false;
    });
  }
};
```

```css
.msg-row {
  transition: transform 0.1s ease;
}

.msg-row.swipe-ready::after {
  content: "↩";
  position: absolute;
  top: 50%;
  transform: translateY(-50%);
  font-size: 20px;
  color: var(--accent);
}

.msg-row.in.swipe-ready::after  { right: 8px; }
.msg-row.out.swipe-ready::after { left: 8px; }
```

### Pull to Refresh (load older messages)

```javascript
// assets/js/hooks/pull_to_load.js
export const PullToLoad = {
  mounted() {
    this.el.addEventListener("scroll", () => {
      // When scrolled to top — load older messages
      if (this.el.scrollTop < 50 && !this.loading) {
        this.loading = true;
        this.pushEvent("load_older_messages", {}, () => {
          this.loading = false;
        });
      }
    });
  }
};
```

## Safe Areas (iPhone Notch / Home Bar)

```css
/* Make sure content doesn't go under the notch or home bar */
.app {
  padding-top: env(safe-area-inset-top);
}

.input-area {
  padding-bottom: env(safe-area-inset-bottom);
}

/* Add to manifest.json */
/* "display": "standalone" already handles status bar on Android */
```

```heex
<!-- root.html.heex -->
<meta name="viewport" content="width=device-width, initial-scale=1, maximum-scale=1, user-scalable=no, viewport-fit=cover" />
```

## Avatar Colors

Consistent color per user (like Telegram):

```elixir
@avatar_colors ~w(#e17076 #7bc862 #e5ca77 #65aadd #a695e7 #ee7aae #6ec9cb #faa774)

def avatar_color(name) do
  index = :erlang.phash2(name, length(@avatar_colors))
  Enum.at(@avatar_colors, index)
end
```

## File Structure

```
lib/blocknot_web/
├── components/
│   ├── layouts/
│   │   ├── root.html.heex      ← fonts, meta, PWA manifest, viewport
│   │   └── app.html.heex       ← app shell
│   ├── core_components.ex       ← shared UI components
│   └── chat_components.ex       ← bubble, sidebar, input components
├── live/
│   ├── chat_live/
│   │   ├── index.ex             ← main chat view (list ↔ chat navigation)
│   │   ├── sidebar.ex           ← chat list component
│   │   └── message_input.ex     ← input area component
│   └── auth_live/
│       └── login.ex             ← Telegram login
assets/
├── css/
│   └── app.css                  ← all styles (variables, mobile-first, desktop override)
├── js/
│   ├── app.js                   ← hook registration
│   └── hooks/
│       ├── message_input.js     ← Enter to send (desktop), auto-resize
│       ├── scroll_to_bottom.js  ← auto-scroll on new messages
│       ├── swipe_reply.js       ← swipe to reply (mobile)
│       ├── pull_to_load.js      ← scroll up to load older messages
│       └── keyboard_resize.js   ← virtual keyboard handling
```
