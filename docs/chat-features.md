# Chat Features

Detailed implementation guide for core chat features that make BlockNot feel like a real messenger.

## 1. Date Separators

Visual dividers between messages from different days: "Today", "Yesterday", "March 15".

### How it looks

```
         ┌─────────────┐
         │  Yesterday   │
         └─────────────┘
  ┌────────────────────┐
  │ Hey, how are you?  │
  └────────────────────┘
         ┌─────────────┐
         │    Today     │
         └─────────────┘
               ┌───────────────────┐
               │ Good, thanks! ✓✓  │
               └───────────────────┘
```

### LiveView

Messages are grouped by date before rendering:

```elixir
defp group_messages_by_date(messages) do
  messages
  |> Enum.group_by(fn msg -> Date.to_string(msg.inserted_at) end)
  |> Enum.sort_by(fn {date, _} -> date end)
end

defp format_date_label(date) do
  today = Date.utc_today()
  yesterday = Date.add(today, -1)

  case Date.from_iso8601!(date) do
    ^today -> "Today"
    ^yesterday -> "Yesterday"
    d -> Calendar.strftime(d, "%B %d")  # "March 15"
  end
end
```

Template:

```heex
<div :for={{date, msgs} <- group_messages_by_date(@messages)}>
  <div class="date-separator">
    <span><%= format_date_label(date) %></span>
  </div>

  <div :for={msg <- msgs} class={"msg-row #{if msg.mine, do: "out", else: "in"}"}>
    <!-- bubble -->
  </div>
</div>
```

### CSS

```css
.date-separator {
  display: flex;
  justify-content: center;
  padding: 8px 0;
  position: sticky;
  top: 0;
  z-index: 1;
}

.date-separator span {
  background: rgba(0, 0, 0, 0.3);
  color: white;
  font-size: 12px;
  font-weight: 500;
  padding: 4px 12px;
  border-radius: 12px;
}
```

## 2. Last Seen Status

Shows "online" or "last seen X minutes ago" under the user's name in the chat header.

### Database

Add `last_seen_at` to users:

```elixir
# migration
alter table(:users) do
  add :last_seen_at, :utc_datetime
end
```

### Tracking

Update `last_seen_at` when user disconnects from Presence:

```elixir
# In the channel
def terminate(_reason, socket) do
  user_id = socket.assigns.current_user.id
  Blocknot.Accounts.update_last_seen(user_id, DateTime.utc_now())
  :ok
end
```

### Display

```elixir
defp format_last_seen(nil), do: ""
defp format_last_seen(dt) do
  diff = DateTime.diff(DateTime.utc_now(), dt, :minute)

  cond do
    diff < 1  -> "last seen just now"
    diff < 60 -> "last seen #{diff} min ago"
    diff < 1440 -> "last seen #{div(diff, 60)}h ago"
    true -> "last seen #{Calendar.strftime(dt, "%b %d")}"
  end
end
```

Template — chat header:

```heex
<div class="chat-header">
  <div class="avatar" style={"background: #{avatar_color(@chat_user.name)}"}>
    <%= String.first(@chat_user.name) %>
  </div>
  <div class="header-info">
    <span class="header-name"><%= @chat_user.name %></span>
    <span class="header-status">
      <%= if @chat_user_online, do: "online", else: format_last_seen(@chat_user.last_seen_at) %>
    </span>
  </div>
</div>
```

### CSS

```css
.header-status {
  font-size: 13px;
  color: var(--text-secondary);
}

/* Green "online" text */
.header-status.online {
  color: var(--online);
}
```

## 3. Scroll-to-Bottom Button

A floating button that appears when the user scrolls up. Shows unread count.

### How it looks

```
│                               │
│  ┌──────────────┐             │
│  │ old message   │             │
│  └──────────────┘             │
│                               │
│                        ┌────┐ │
│                        │ ↓3 │ │  ← floating button
│                        └────┘ │
├───────────────────────────────┤
│  [  Message input...  ]       │
└───────────────────────────────┘
```

### JS Hook

```javascript
// assets/js/hooks/scroll_to_bottom.js
export const ScrollToBottom = {
  mounted() {
    this.isAtBottom = true;
    this.newCount = 0;
    this.button = document.getElementById("scroll-btn");

    this.el.addEventListener("scroll", () => {
      const threshold = 100;
      const { scrollTop, scrollHeight, clientHeight } = this.el;
      this.isAtBottom = scrollHeight - scrollTop - clientHeight < threshold;

      if (this.isAtBottom) {
        this.newCount = 0;
        this.updateButton();
      }
    });

    // Auto-scroll on new messages if already at bottom
    this.handleEvent("new_message", () => {
      if (this.isAtBottom) {
        this.scrollToEnd();
      } else {
        this.newCount++;
        this.updateButton();
      }
    });

    this.button.addEventListener("click", () => {
      this.scrollToEnd();
      this.newCount = 0;
      this.updateButton();
    });

    this.scrollToEnd();
  },

  scrollToEnd() {
    this.el.scrollTo({ top: this.el.scrollHeight, behavior: "smooth" });
  },

  updateButton() {
    if (this.isAtBottom || this.newCount === 0) {
      this.button.classList.add("hidden");
    } else {
      this.button.classList.remove("hidden");
      this.button.querySelector(".count").textContent = this.newCount;
    }
  }
};
```

### Template

```heex
<div class="messages-wrapper">
  <div id="messages" phx-hook="ScrollToBottom" phx-update="stream">
    <!-- messages -->
  </div>

  <button id="scroll-btn" class="scroll-to-bottom hidden">
    <svg><!-- down arrow icon --></svg>
    <span class="count"></span>
  </button>
</div>
```

### CSS

```css
.messages-wrapper {
  position: relative;
  flex: 1;
  overflow: hidden;
}

.scroll-to-bottom {
  position: absolute;
  bottom: 16px;
  right: 16px;
  width: 40px;
  height: 40px;
  border-radius: 50%;
  background: var(--bg-secondary);
  border: none;
  color: var(--text-secondary);
  cursor: pointer;
  box-shadow: 0 2px 8px rgba(0, 0, 0, 0.3);
  display: flex;
  align-items: center;
  justify-content: center;
  transition: opacity 0.2s;
}

.scroll-to-bottom .count {
  position: absolute;
  top: -6px;
  right: -6px;
  background: var(--accent);
  color: white;
  font-size: 11px;
  font-weight: 600;
  min-width: 18px;
  height: 18px;
  padding: 0 5px;
  border-radius: 9px;
  display: flex;
  align-items: center;
  justify-content: center;
}

.scroll-to-bottom.hidden { opacity: 0; pointer-events: none; }
```

## 4. Edit Messages

Users can edit their own messages. Edited messages show an "edited" label.

### Database

```elixir
# migration
alter table(:messages) do
  add :edited_at, :utc_datetime
  add :original_body, :text  # keep original for audit
end
```

### Channel

```elixir
def handle_in("edit_msg", %{"id" => id, "body" => body}, socket) do
  user_id = socket.assigns.current_user.id

  with {:ok, message} <- Chat.get_user_message(id, user_id),
       {:ok, updated} <- Chat.update_message(message, %{body: body}) do
    broadcast!(socket, "msg_edited", %{
      id: updated.id,
      body: updated.body,
      edited_at: updated.edited_at
    })
    {:reply, :ok, socket}
  else
    _ -> {:reply, {:error, %{reason: "cannot edit"}}, socket}
  end
end
```

Context function:

```elixir
def update_message(message, attrs) do
  message
  |> Message.edit_changeset(attrs)
  |> Ecto.Changeset.put_change(:edited_at, DateTime.utc_now())
  |> Ecto.Changeset.put_change(:original_body, message.body)
  |> Repo.update()
end
```

### LiveView — Edit Mode

```elixir
def handle_event("start_edit", %{"id" => id}, socket) do
  message = Chat.get_message!(id)
  {:noreply, assign(socket, editing_message: message)}
end

def handle_event("cancel_edit", _, socket) do
  {:noreply, assign(socket, editing_message: nil)}
end

def handle_event("save_edit", %{"body" => body}, socket) do
  msg = socket.assigns.editing_message
  # push to channel "edit_msg"
  {:noreply, assign(socket, editing_message: nil)}
end
```

### Template — Edit Bar

When editing, the input area shows what you're editing:

```heex
<div :if={@editing_message} class="edit-bar">
  <div class="edit-bar-icon">
    <.icon name="hero-pencil-square" />
  </div>
  <div class="edit-bar-content">
    <span class="edit-bar-label">Editing</span>
    <span class="edit-bar-text"><%= truncate(@editing_message.body, 60) %></span>
  </div>
  <button phx-click="cancel_edit" class="icon-btn">
    <.icon name="hero-x-mark" />
  </button>
</div>
```

### Template — "edited" Label

```heex
<div class="msg-meta">
  <span :if={msg.edited_at} class="msg-edited">edited</span>
  <span class="msg-time"><%= format_time(msg.inserted_at) %></span>
  <span :if={msg.mine} class={"msg-status #{msg.status}"}><%= status_icon(msg.status) %></span>
</div>
```

### CSS

```css
.edit-bar {
  display: flex;
  align-items: center;
  gap: 8px;
  padding: 8px 12px;
  background: var(--bg-secondary);
  border-left: 2px solid var(--accent);
}

.edit-bar-label {
  color: var(--accent);
  font-size: 12px;
  font-weight: 600;
}

.edit-bar-text {
  color: var(--text-secondary);
  font-size: 13px;
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}

.msg-edited {
  color: var(--text-secondary);
  font-size: 11px;
  font-style: italic;
}
```

## 5. Delete Messages

Soft delete — message replaced with "Message deleted" placeholder.

### Database

```elixir
# migration
alter table(:messages) do
  add :deleted_at, :utc_datetime
end
```

### Channel

```elixir
def handle_in("delete_msg", %{"id" => id}, socket) do
  user_id = socket.assigns.current_user.id

  with {:ok, message} <- Chat.get_user_message(id, user_id),
       {:ok, _} <- Chat.soft_delete_message(message) do
    broadcast!(socket, "msg_deleted", %{id: id})
    {:reply, :ok, socket}
  else
    _ -> {:reply, {:error, %{reason: "cannot delete"}}, socket}
  end
end
```

Context:

```elixir
def soft_delete_message(message) do
  message
  |> Ecto.Changeset.change(%{deleted_at: DateTime.utc_now()})
  |> Repo.update()
end
```

### Template

```heex
<div :if={msg.deleted_at} class="bubble deleted">
  <.icon name="hero-no-symbol" class="w-4 h-4" />
  <span>Message deleted</span>
</div>

<div :if={!msg.deleted_at} class={"bubble #{if msg.mine, do: "out", else: "in"}"}>
  <!-- normal message content -->
</div>
```

### CSS

```css
.bubble.deleted {
  background: none;
  display: flex;
  align-items: center;
  gap: 6px;
  color: var(--text-secondary);
  font-size: 13px;
  font-style: italic;
}
```

## 6. Reply to Message

Quoting a specific message when replying. Shows a mini-preview above the reply.

### Database

```elixir
# migration
alter table(:messages) do
  add :reply_to_id, references(:messages, on_delete: :nilify_all)
end

create index(:messages, [:reply_to_id])
```

Schema:

```elixir
schema "messages" do
  belongs_to :reply_to, Blocknot.Chat.Message
  # ... other fields
end
```

### LiveView — Reply Mode

```elixir
def handle_event("start_reply", %{"id" => id}, socket) do
  message = Chat.get_message!(id) |> Repo.preload(:user)
  {:noreply, assign(socket, replying_to: message)}
end

def handle_event("cancel_reply", _, socket) do
  {:noreply, assign(socket, replying_to: nil)}
end

# When sending, include reply_to_id
def handle_event("send_message", %{"body" => body}, socket) do
  attrs = %{
    body: body,
    reply_to_id: get_in(socket.assigns, [:replying_to, :id])
  }
  # push to channel
  {:noreply, assign(socket, replying_to: nil)}
end
```

### Template — Reply Bar (above input)

```heex
<div :if={@replying_to} class="reply-bar">
  <div class="reply-bar-line"></div>
  <div class="reply-bar-content">
    <span class="reply-bar-name" style={"color: #{avatar_color(@replying_to.user.name)}"}>
      <%= @replying_to.user.name %>
    </span>
    <span class="reply-bar-text"><%= truncate(@replying_to.body, 60) %></span>
  </div>
  <button phx-click="cancel_reply" class="icon-btn">
    <.icon name="hero-x-mark" />
  </button>
</div>
```

### Template — Reply Preview Inside Bubble

```heex
<div :if={msg.reply_to} class="reply-preview" phx-click="scroll_to_msg" phx-value-id={msg.reply_to_id}>
  <div class="reply-preview-line"></div>
  <div class="reply-preview-content">
    <span class="reply-preview-name" style={"color: #{avatar_color(msg.reply_to.user.name)}"}>
      <%= msg.reply_to.user.name %>
    </span>
    <span class="reply-preview-text"><%= truncate(msg.reply_to.body, 50) %></span>
  </div>
</div>
```

### CSS

```css
.reply-bar {
  display: flex;
  align-items: center;
  gap: 8px;
  padding: 8px 12px;
  background: var(--bg-secondary);
}

.reply-bar-line,
.reply-preview-line {
  width: 2px;
  height: 100%;
  min-height: 32px;
  background: var(--accent);
  border-radius: 1px;
  flex-shrink: 0;
}

.reply-bar-name,
.reply-preview-name {
  font-size: 12px;
  font-weight: 600;
}

.reply-bar-text,
.reply-preview-text {
  font-size: 13px;
  color: var(--text-secondary);
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}

.reply-preview {
  display: flex;
  gap: 8px;
  padding: 4px 8px;
  margin-bottom: 4px;
  cursor: pointer;
  border-radius: 4px;
}

.reply-preview:hover {
  background: rgba(255, 255, 255, 0.05);
}
```

## 7. Context Menu

Right-click or long-press on a message shows action menu: Reply, Edit, Delete, Copy.

### Template

```heex
<div :for={{dom_id, msg} <- @streams.messages}
     id={dom_id}
     class={"msg-row #{if msg.mine, do: "out", else: "in"}"}
     phx-hook="ContextMenu"
     data-msg-id={msg.id}
     data-mine={msg.mine}>

  <div class={"bubble #{if msg.mine, do: "out", else: "in"}"}>
    <!-- message content -->
  </div>
</div>

<!-- Shared context menu (one for all messages) -->
<div id="context-menu" class="context-menu hidden" phx-hook="ContextMenuActions">
  <button class="ctx-item" data-action="reply">
    <.icon name="hero-arrow-uturn-left" class="w-4 h-4" /> Reply
  </button>
  <button class="ctx-item" data-action="copy">
    <.icon name="hero-clipboard" class="w-4 h-4" /> Copy
  </button>
  <button class="ctx-item mine-only" data-action="edit">
    <.icon name="hero-pencil-square" class="w-4 h-4" /> Edit
  </button>
  <div class="ctx-divider mine-only"></div>
  <button class="ctx-item ctx-danger mine-only" data-action="delete">
    <.icon name="hero-trash" class="w-4 h-4" /> Delete
  </button>
</div>
```

### JS Hook

```javascript
// assets/js/hooks/context_menu.js
export const ContextMenu = {
  mounted() {
    const menu = document.getElementById("context-menu");

    // Right-click (desktop)
    this.el.addEventListener("contextmenu", (e) => {
      e.preventDefault();
      showMenu(e.clientX, e.clientY, this.el);
    });

    // Long-press (mobile)
    let timer;
    this.el.addEventListener("touchstart", (e) => {
      timer = setTimeout(() => {
        const touch = e.touches[0];
        showMenu(touch.clientX, touch.clientY, this.el);
      }, 500);
    });
    this.el.addEventListener("touchend", () => clearTimeout(timer));
    this.el.addEventListener("touchmove", () => clearTimeout(timer));

    function showMenu(x, y, el) {
      const isMine = el.dataset.mine === "true";
      menu.dataset.msgId = el.dataset.msgId;

      // Show/hide edit and delete for own messages only
      menu.querySelectorAll(".mine-only").forEach(item => {
        item.style.display = isMine ? "" : "none";
      });

      menu.style.left = x + "px";
      menu.style.top = y + "px";
      menu.classList.remove("hidden");
    }
  }
};

export const ContextMenuActions = {
  mounted() {
    // Close on click outside
    document.addEventListener("click", () => {
      this.el.classList.add("hidden");
    });

    this.el.querySelectorAll(".ctx-item").forEach(btn => {
      btn.addEventListener("click", (e) => {
        e.stopPropagation();
        const action = btn.dataset.action;
        const msgId = this.el.dataset.msgId;

        if (action === "copy") {
          // Copy message text to clipboard
          const bubble = document.querySelector(
            `[data-msg-id="${msgId}"] .msg-text`
          );
          navigator.clipboard.writeText(bubble?.textContent || "");
        } else {
          // Dispatch to LiveView
          this.pushEvent(action === "reply" ? "start_reply" : action === "edit" ? "start_edit" : "delete_msg", { id: msgId });
        }

        this.el.classList.add("hidden");
      });
    });
  }
};
```

### CSS

```css
.context-menu {
  position: fixed;
  background: var(--bg-secondary);
  border-radius: 8px;
  padding: 4px 0;
  min-width: 160px;
  box-shadow: 0 4px 16px rgba(0, 0, 0, 0.4);
  z-index: 100;
}

.ctx-item {
  display: flex;
  align-items: center;
  gap: 12px;
  width: 100%;
  padding: 8px 16px;
  background: none;
  border: none;
  color: var(--text-primary);
  font-size: 14px;
  cursor: pointer;
  text-align: left;
}

.ctx-item:hover {
  background: var(--bg-hover);
}

.ctx-danger {
  color: var(--danger);
}

.ctx-divider {
  height: 1px;
  background: var(--divider);
  margin: 4px 0;
}

.context-menu.hidden {
  display: none;
}
```

## 8. Link Previews

When a message contains a URL, show an OpenGraph preview below the text: title, description, thumbnail.

### Database

```elixir
# migration
create table(:link_previews) do
  add :url, :string, null: false
  add :title, :string
  add :description, :string
  add :image_url, :string
  add :domain, :string
  add :message_id, references(:messages, on_delete: :delete_all)

  timestamps()
end

create index(:link_previews, [:message_id])
create unique_index(:link_previews, [:url])
```

### Background Fetcher

A GenServer fetches OpenGraph data asynchronously so it doesn't block message delivery:

```elixir
defmodule Blocknot.Chat.LinkPreviewWorker do
  use GenServer

  def start_link(_), do: GenServer.start_link(__MODULE__, [], name: __MODULE__)
  def init(_), do: {:ok, []}

  def fetch(message_id, url) do
    GenServer.cast(__MODULE__, {:fetch, message_id, url})
  end

  def handle_cast({:fetch, message_id, url}, state) do
    case fetch_og_data(url) do
      {:ok, preview_data} ->
        {:ok, preview} = Chat.create_link_preview(message_id, preview_data)
        # Broadcast preview to room
        Phoenix.PubSub.broadcast(
          Blocknot.PubSub,
          "room:#{preview.message.room_id}",
          {:link_preview, preview}
        )
      _ -> :ok
    end
    {:noreply, state}
  end

  defp fetch_og_data(url) do
    case Req.get(url, max_redirects: 3, receive_timeout: 5000) do
      {:ok, %{status: 200, body: body}} ->
        {:ok, %{
          url: url,
          title: extract_meta(body, "og:title") || extract_tag(body, "title"),
          description: extract_meta(body, "og:description"),
          image_url: extract_meta(body, "og:image"),
          domain: URI.parse(url).host
        }}
      _ -> :error
    end
  end

  defp extract_meta(html, property) do
    case Regex.run(
      ~r/<meta[^>]*property="#{property}"[^>]*content="([^"]*)"[^>]*>/i,
      html
    ) do
      [_, content] -> content
      _ -> nil
    end
  end

  defp extract_tag(html, tag) do
    case Regex.run(~r/<#{tag}[^>]*>([^<]*)<\/#{tag}>/i, html) do
      [_, content] -> String.trim(content)
      _ -> nil
    end
  end
end
```

### Triggering Preview Fetch

In the channel, after saving a message:

```elixir
def handle_in("new_msg", %{"body" => body} = params, socket) do
  # ... save message ...

  # Check for URLs and fetch previews
  case Regex.run(~r/https?:\/\/[^\s]+/, body) do
    [url | _] -> Blocknot.Chat.LinkPreviewWorker.fetch(message.id, url)
    _ -> :ok
  end

  {:reply, :ok, socket}
end
```

### Template

```heex
<div class={"bubble #{if msg.mine, do: "out", else: "in"}"}>
  <p class="msg-text"><%= msg.body %></p>

  <a :if={msg.link_preview} href={msg.link_preview.url}
     target="_blank" rel="noopener" class="link-preview">
    <img :if={msg.link_preview.image_url}
         src={msg.link_preview.image_url}
         class="link-preview-image"
         loading="lazy" />
    <div class="link-preview-info">
      <span class="link-preview-domain"><%= msg.link_preview.domain %></span>
      <span class="link-preview-title"><%= msg.link_preview.title %></span>
      <span :if={msg.link_preview.description} class="link-preview-desc">
        <%= truncate(msg.link_preview.description, 120) %>
      </span>
    </div>
  </a>

  <div class="msg-meta">
    <!-- time + status -->
  </div>
</div>
```

### CSS

```css
.link-preview {
  display: block;
  margin-top: 6px;
  border-radius: 8px;
  overflow: hidden;
  background: rgba(0, 0, 0, 0.15);
  border-left: 2px solid var(--accent);
  text-decoration: none;
  color: inherit;
}

.link-preview-image {
  width: 100%;
  max-height: 200px;
  object-fit: cover;
}

.link-preview-info {
  padding: 8px 10px;
  display: flex;
  flex-direction: column;
  gap: 2px;
}

.link-preview-domain {
  font-size: 11px;
  color: var(--accent);
  text-transform: lowercase;
}

.link-preview-title {
  font-size: 14px;
  font-weight: 500;
  color: var(--text-primary);
}

.link-preview-desc {
  font-size: 13px;
  color: var(--text-secondary);
  display: -webkit-box;
  -webkit-line-clamp: 2;
  -webkit-box-orient: vertical;
  overflow: hidden;
}
```

## Summary

All features work together in the message flow:

```
User types message
  → Contains URL? → Queue link preview fetch (async)
  → Has reply_to? → Include reply_to_id
  → Send via Channel
  → Server saves to DB (status: sent)
  → Broadcast to room
  → Recipients render: bubble + reply preview + link preview
  → Recipients send "delivered" ack
  → User opens chat → "read" ack
  → Link preview arrives → update bubble (async)
```

### Updated Message Schema

```elixir
schema "messages" do
  field :body, :string
  field :type, Ecto.Enum, values: [:text, :image]
  field :status, Ecto.Enum, values: [:sent, :delivered, :read], default: :sent
  field :client_id, :string
  field :edited_at, :utc_datetime
  field :deleted_at, :utc_datetime
  field :original_body, :string

  belongs_to :user, Blocknot.Accounts.User
  belongs_to :room, Blocknot.Chat.Room
  belongs_to :reply_to, Blocknot.Chat.Message
  has_one :link_preview, Blocknot.Chat.LinkPreview
  has_many :reads, Blocknot.Chat.MessageRead

  timestamps()
end
```
