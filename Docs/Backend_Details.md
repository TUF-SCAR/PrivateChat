# PrivateChat Backend Details

PrivateChat backend is a **FastAPI + PostgreSQL** chat backend.

It supports account authentication, private chats, group chats, messaging, GIF messages, message editing/deleting, pagination, replies, delivered receipts, read receipts, WebSocket realtime events, device-token registration, and Firebase push notification sending.

## Current backend status

This is the current backend state after the latest test:

```txt
Backend core: working
App integration: ready
Production backend: mostly ready, but still needs real notification testing and later hardening
```

Tested successfully:

```txt
/register
/login
/me
/users/search
/devices/register
/chats
/chats/{chat_id}
/messages
/messages/{chat_id}
/messages/{message_id}
/messages/{message_id}/delivered
/messages/{message_id}/read
/messages/{message_id}/reads
/chats/{chat_id}/read
/groups
/groups/{chat_id}/members
/groups/{chat_id}/members/{user_id}/role
/groups/{chat_id}/leave
WebSocket message sending
```

Still needs real-device testing:

```txt
Firebase notification delivery with a real Android/Web FCM token
Render Firebase env variable setup
Flutter app FCM token registration
Website FCM token registration later
```

## Backend folder structure

Current important backend structure:

```txt
Backend/
  main.py

  src/
    .env                       # local only, ignored by git
    database.py
    auth.py
    security.py
    util.py
    notifications.py
    firebase-service-account.json    # local only, ignored by git

    public_routes/
      login.py
      register.py

    private_routes/
      chat.py
      devices.py
      groups.py
      me.py
      messages.py
      users.py
      websocket.py
```

## Common rule for private routes

Private routes require this header:

```txt
Authorization: Bearer YOUR_TOKEN_HERE
```

The token is created during login and checked by `check_token()`.

## Environment variables

### Local PC

Local development uses:

```txt
Backend/src/.env
```

Important local `.env` keys:

```txt
DATABASE_NAME=postgres
DATABASE_USER=...
DATABASE_PASSWORD=...
DATABASE_HOST=...
DATABASE_PORT=...
TOKEN_SECRET_KEY=...
ACCESS_TOKEN_EXPIRE_MINUTES=...
```

For Firebase locally, the backend can use:

```txt
Backend/src/firebase-service-account.json
```

This file must never be pushed to GitHub.

### Render

Render uses Environment Variables from the Render dashboard.

Required Render variables:

```txt
DATABASE_NAME
DATABASE_USER
DATABASE_PASSWORD
DATABASE_HOST
DATABASE_PORT
TOKEN_SECRET_KEY
ACCESS_TOKEN_EXPIRE_MINUTES
FIREBASE_SERVICE_ACCOUNT_JSON
```

`FIREBASE_SERVICE_ACCOUNT_JSON` should contain the full Firebase service account JSON content.

Do not manually edit the `\n` inside the private key. Copy and paste the JSON exactly.

## Git ignore safety

The project ignores secrets and local generated files.

Important ignored files:

```gitignore
.env
*.env
*.json
__pycache__/
```

This means these should not be pushed:

```txt
Backend/src/.env
Backend/src/firebase-service-account.json
Backend/src/chattify-...firebase-adminsdk...json
```

## Main database tables

| Table                | Purpose                                                                                               |
| -------------------- | ----------------------------------------------------------------------------------------------------- |
| `users`              | Stores username, email, hashed password, and creation time.                                           |
| `chats`              | Stores private chats and group chats. `is_group = false` means private chat, `true` means group chat. |
| `chat_members`       | Stores which users are inside each chat, group roles, and delete-for-me state.                        |
| `messages`           | Stores text/GIF messages, soft-delete state, edit state, reply target, and media fields.              |
| `message_reads`      | Stores read receipts. One row means one user read one message.                                        |
| `message_deliveries` | Stores delivered receipts. One row means one user received one message.                               |
| `user_devices`       | Stores Firebase/device tokens for Android, iOS, or web push notifications.                            |

## Public routes

### `POST /register`

Registers a new user.

Request body:

```json
{
  "username": "scar",
  "email": "scar@example.com",
  "password": "password123"
}
```

Checks username, email, password, username uniqueness, and email uniqueness. Password is stored as `password_hash`, not plain text.

Success:

```json
{
  "message": "registration success"
}
```

### `POST /login`

Logs in with email or username and returns a token.

Request body:

```json
{
  "email_or_username": "scar",
  "password": "password123"
}
```

Success:

```json
{
  "message": "login success",
  "access_token": "token_here",
  "token_type": "bearer"
}
```

## User routes

### `GET /me`

Checks if the token is valid and returns the logged-in user.

Success:

```json
{
  "message": "token valid",
  "id": 1,
  "username": "scar"
}
```

### `GET /users/search?username=text`

Searches users by username. It returns up to 10 matching users and does not include the current logged-in user.

Success:

```json
{
  "message": "users fetched",
  "users": [
    {
      "id": 2,
      "username": "zoro"
    }
  ]
}
```

## Private chat routes

### `POST /chats`

Creates a private chat with another user, or returns the existing chat if it already exists.

Request body:

```json
{
  "other_user_id": 2
}
```

If the current user had deleted the private chat for themselves, this route makes it visible again for them.

Success:

```json
{
  "message": "successfully created chat",
  "chat_id": 1
}
```

If already exists:

```json
{
  "message": "chat already exists",
  "chat_id": 1
}
```

### `GET /chats`

Returns all private chats for the current user. Deleted-for-me chats are hidden.

The response includes last message preview and unread count.

Success:

```json
{
  "message": "chats fetched",
  "chats": [
    {
      "chat_id": 1,
      "is_group": false,
      "chat_name": null,
      "other_user_id": 2,
      "other_username": "zoro",
      "last_message": "hello bro",
      "last_message_time": "2026-05-28 10:30:00",
      "unread_count": 3
    }
  ]
}
```

For GIF messages, frontend can show the last message as something like:

```txt
GIF
```

### `GET /chats/{chat_id}`

Fetches one chat's details. Works for both private chats and group chats.

Private chat success:

```json
{
  "message": "chat fetched",
  "chat": {
    "chat_id": 1,
    "is_group": false,
    "chat_name": null,
    "my_role": "member",
    "other_user_id": 2,
    "other_username": "zoro"
  }
}
```

Group chat success:

```json
{
  "message": "chat fetched",
  "chat": {
    "chat_id": 5,
    "is_group": true,
    "chat_name": "PrivateChat Team",
    "my_role": "admin",
    "other_user_id": null,
    "other_username": null
  }
}
```

### `DELETE /chats/{chat_id}`

Deletes a private chat only for the current user. This is delete-for-me, not full deletion.

Success:

```json
{
  "message": "chat deleted"
}
```

## Message routes

### `POST /messages`

Sends a message. Supports normal text messages, GIF messages, and reply messages.

Text message body:

```json
{
  "chat_id": 1,
  "message_text": "hello bro",
  "message_type": "text"
}
```

Reply text message body:

```json
{
  "chat_id": 1,
  "message_text": "yes bro",
  "reply_to_message_id": 10,
  "message_type": "text"
}
```

GIF message body:

```json
{
  "chat_id": 1,
  "message_text": "",
  "message_type": "gif",
  "media_url": "https://media.tenor.com/example.gif",
  "preview_url": "https://media.tenor.com/example-preview.gif"
}
```

GIF reply body:

```json
{
  "chat_id": 1,
  "message_text": "",
  "reply_to_message_id": 10,
  "message_type": "gif",
  "media_url": "https://media.tenor.com/example.gif",
  "preview_url": "https://media.tenor.com/example-preview.gif"
}
```

Rules:

```txt
message_type can be text or gif
text messages must have non-empty message_text
gif messages must have media_url
reply_to_message_id must point to a message in the same chat
sender must be a member of the chat
```

Success:

```json
{
  "message": "message sent",
  "message_id": 20,
  "chat_id": 1,
  "sender_id": 3,
  "message_text": "hello bro",
  "message_type": "text",
  "media_url": "",
  "preview_url": "",
  "reply_to_message_id": null,
  "notification": {
    "sent": 0,
    "failed": 0,
    "reason": "no device tokens"
  }
}
```

The `notification` object tells whether Firebase push sending happened. If no receiver has registered device tokens, `sent` will be `0`.

### `GET /messages/{chat_id}?limit=50&offset=0`

Fetches messages from a chat with pagination.

It returns newest messages first because of descending order. Frontend can use `offset` to load older messages when scrolling up.

Response includes:

```txt
edit state
delete state
read_count
delivery_count
reply preview
message_type
media_url
preview_url
```

Success:

```json
{
  "message": "messages fetched",
  "limit": 50,
  "offset": 0,
  "messages": [
    {
      "message_id": 20,
      "sender_id": 3,
      "sender_username": "scar",
      "message_text": "yes bro",
      "is_deleted": false,
      "created_at": "2026-05-28 10:35:00",
      "is_edited": false,
      "edited_at": null,
      "read_count": 1,
      "delivery_count": 1,
      "reply_to": {
        "message_id": 10,
        "sender_id": 2,
        "sender_username": "zoro",
        "message_text": "are you coming?",
        "message_type": "text",
        "media_url": "",
        "preview_url": ""
      },
      "message_type": "text",
      "media_url": "",
      "preview_url": ""
    }
  ]
}
```

Deleted messages are returned with safe placeholder content:

```txt
this message was deleted
```

For deleted messages:

```json
{
  "message_text": "this message was deleted",
  "message_type": "text",
  "media_url": "",
  "preview_url": ""
}
```

### `PATCH /messages/{message_id}`

Edits a message.

Rules:

```txt
Only sender can edit
Deleted messages cannot be edited
Messages can only be edited within 5 minutes
Message text cannot be empty
```

Request body:

```json
{
  "message_text": "edited text"
}
```

Success:

```json
{
  "message": "message edited"
}
```

### `DELETE /messages/{message_id}`

Soft deletes a message. Only the sender can delete their own message.

Success:

```json
{
  "message": "This message was deleted"
}
```

## Delivered receipt routes

### `POST /messages/{message_id}/delivered`

Marks one message as delivered for the current user.

Rules:

```txt
Sender's own message is skipped
Deleted messages are skipped
User must be a member of the chat
Duplicate delivery rows are ignored
```

Success when newly marked:

```json
{
  "message": "message marked as delivered",
  "marked": true
}
```

If already marked:

```json
{
  "message": "message already marked as delivered",
  "marked": false
}
```

## Read receipt routes

### `POST /chats/{chat_id}/read`

Marks all unread messages in a chat as read for the current user.

Own messages and deleted messages are skipped.

This also marks those messages as delivered first.

Success:

```json
{
  "message": "chat marked as read",
  "marked_count": 4
}
```

### `POST /messages/{message_id}/read`

Marks one message as read for the current user.

This also marks the message as delivered first.

Success:

```json
{
  "message": "message marked as read",
  "marked": true
}
```

If already read:

```json
{
  "message": "message already marked as read",
  "marked": false
}
```

### `GET /messages/{message_id}/reads`

Returns who read one message.

Success:

```json
{
  "message": "message reads fetched",
  "message_id": 20,
  "read_count": 2,
  "read_by": [
    {
      "user_id": 2,
      "username": "zoro",
      "read_at": "2026-05-28 10:40:00"
    }
  ]
}
```

## Group routes

### `POST /groups`

Creates a group. Current user becomes admin and other users become members.

Request body:

```json
{
  "name": "PrivateChat Team",
  "member_ids": [2, 3, 4]
}
```

Success:

```json
{
  "message": "successfully created group",
  "chat_id": 5
}
```

### `GET /groups`

Fetches all groups where the current user is a member. Includes last message preview and unread count.

Success:

```json
{
  "message": "groups fetched",
  "groups": [
    {
      "chat_id": 5,
      "group_name": "PrivateChat Team",
      "my_role": "admin",
      "created_at": "2026-05-28 10:20:00",
      "last_message": "hello team",
      "last_message_time": "2026-05-28 10:35:00",
      "unread_count": 4
    }
  ]
}
```

### `POST /groups/{chat_id}/members`

Adds a member to a group. Only admins can add members.

Request body:

```json
{
  "user_id": 6
}
```

Success:

```json
{
  "message": "member added"
}
```

### `GET /groups/{chat_id}/members`

Fetches group members. Any group member can view this.

Success:

```json
{
  "message": "members fetched",
  "members": [
    {
      "user_id": 1,
      "username": "scar",
      "role": "admin",
      "joined_at": "2026-05-28 10:20:00"
    }
  ]
}
```

### `PATCH /groups/{chat_id}`

Renames a group. Only admins can rename.

Request body:

```json
{
  "name": "New Group Name"
}
```

Success:

```json
{
  "message": "group renamed"
}
```

### `PATCH /groups/{chat_id}/members/{user_id}/role`

Changes a member role. Only admins can change roles.

Allowed roles:

```txt
admin
member
```

Last admin cannot be demoted.

Request body:

```json
{
  "role": "admin"
}
```

Success:

```json
{
  "message": "role updated"
}
```

### `DELETE /groups/{chat_id}/members/{user_id}`

Removes a member from a group.

Rules:

```txt
Only admins can remove members
Admin cannot remove themselves using this route
Last admin cannot be removed
```

Success:

```json
{
  "message": "member removed"
}
```

### `DELETE /groups/{chat_id}/leave`

Current user leaves a group.

Rules:

```txt
If they are the last member, the group is deleted
If they are the only admin, they must assign another admin first
```

Success:

```json
{
  "message": "successfully left group"
}
```

If last member:

```json
{
  "message": "group deleted because you were the last member"
}
```

### `DELETE /groups/{chat_id}`

Deletes the whole group. Only admins can delete groups.

Success:

```json
{
  "message": "group deleted"
}
```

## Device-token route for push notifications

### `POST /devices/register`

Registers or updates a Firebase/device token for the logged-in user.

Request body:

```json
{
  "device_token": "firebase_token_here",
  "platform": "android"
}
```

Allowed platforms:

```txt
android
ios
web
```

Success:

```json
{
  "message": "device registered"
}
```

Purpose:

```txt
Android app registers FCM token here
Website registers browser FCM token here later
Backend uses tokens from user_devices to send notifications
```

## Push notification behavior

Notifications are sent from backend after messages are created through:

```txt
POST /messages
WebSocket type=message
```

Notification title:

```txt
Private chat: sender username
Group chat: group name
```

Notification body:

```txt
Private text: message text
Private GIF: sent a GIF
Group text: sender_username: message text
Group GIF: sender_username: sent a GIF
```

Notification data payload:

```json
{
  "type": "message",
  "chat_id": "1",
  "message_id": "20",
  "sender_id": "3",
  "message_type": "text"
}
```

If Firebase is not configured or no tokens exist, the message still sends normally. Notification failure does not break chat.

## WebSocket route

### `WS /ws/{chat_id}?token=TOKEN_HERE`

Used for realtime chat events.

User must be a member of the chat.

Supported incoming event types:

```txt
message
typing
delivered
read_receipt
```

### WebSocket message event

Text message:

```json
{
  "type": "message",
  "message_text": "hello",
  "message_type": "text"
}
```

GIF message:

```json
{
  "type": "message",
  "message_text": "",
  "message_type": "gif",
  "media_url": "https://media.tenor.com/example.gif",
  "preview_url": "https://media.tenor.com/example-preview.gif"
}
```

Reply message:

```json
{
  "type": "message",
  "message_text": "yes bro",
  "message_type": "text",
  "reply_to_message_id": 10
}
```

Broadcast response:

```json
{
  "type": "message",
  "message_id": 20,
  "chat_id": 1,
  "sender_id": 3,
  "sender_username": "scar",
  "message_text": "yes bro",
  "is_deleted": false,
  "is_edited": false,
  "created_at": "2026-05-28 10:35:00",
  "edited_at": null,
  "reply_to": {
    "message_id": 10,
    "sender_id": 2,
    "sender_username": "zoro",
    "message_text": "are you coming?",
    "message_type": "text",
    "media_url": "",
    "preview_url": ""
  },
  "message_type": "text",
  "media_url": "",
  "preview_url": "",
  "read_count": 0,
  "delivery_count": 0
}
```

### WebSocket typing event

Incoming:

```json
{
  "type": "typing"
}
```

Broadcast response:

```json
{
  "type": "typing",
  "chat_id": 1,
  "user_id": 3,
  "username": "scar"
}
```

### WebSocket delivered event

Incoming:

```json
{
  "type": "delivered",
  "message_id": 20
}
```

Broadcast response:

```json
{
  "type": "delivered",
  "chat_id": 1,
  "message_id": 20,
  "user_id": 3,
  "username": "scar",
  "marked": true
}
```

### WebSocket read receipt event

Incoming:

```json
{
  "type": "read_receipt",
  "message_id": 20
}
```

This also marks the message as delivered first.

Broadcast response:

```json
{
  "type": "read_receipt",
  "chat_id": 1,
  "message_id": 20,
  "user_id": 3,
  "username": "scar",
  "marked": true
}
```

### WebSocket online/offline events

When a user connects, other users in the same chat get:

```json
{
  "type": "online",
  "chat_id": 1,
  "user_id": 3,
  "username": "scar"
}
```

When a user disconnects, other users in the same chat get:

```json
{
  "type": "offline",
  "chat_id": 1,
  "user_id": 3,
  "username": "scar"
}
```

## Helper files

| File               | Purpose                                                                                                                                    |
| ------------------ | ------------------------------------------------------------------------------------------------------------------------------------------ |
| `auth.py`          | Creates JWT tokens and checks tokens.                                                                                                      |
| `database.py`      | Opens PostgreSQL connection using `.env` locally or Render env variables in production. Uses `connect_timeout=10` and `sslmode="require"`. |
| `security.py`      | Validates username and email format.                                                                                                       |
| `util.py`          | Hashes passwords and verifies passwords.                                                                                                   |
| `devices.py`       | Stores Firebase/device tokens.                                                                                                             |
| `notifications.py` | Loads Firebase Admin SDK, reads local JSON or Render env JSON, finds receiver device tokens, and sends push notifications.                 |

## Current MVP completed backend features

- Registration
- Login with email or username
- Token authentication
- `/me`
- User search
- Private chat create/list/open/delete-for-me
- Group create/list/member management/roles/leave/delete
- Message send/fetch/edit/soft-delete
- Message pagination
- Last message preview
- Unread count
- Replies
- Text messages
- GIF messages
- Read receipts
- Delivered receipts
- WebSocket realtime messaging
- WebSocket typing indicator
- WebSocket online/offline events
- WebSocket delivered receipts
- WebSocket read receipts
- Device-token registration
- Firebase push notification helper
- Render-compatible Firebase env loading

## Not included in MVP

- File sharing
- Voice messages
- Reactions
- Block/report
- Full end-to-end encryption
- Proper rate limiting
- Real online/offline presence across whole app
- Full production abuse protection

## App integration checklist

The Flutter app should use:

```txt
POST /login
POST /register
GET /me
GET /users/search
POST /chats
GET /chats
GET /chats/{chat_id}
GET /messages/{chat_id}?limit=50&offset=0
POST /messages
PATCH /messages/{message_id}
DELETE /messages/{message_id}
POST /messages/{message_id}/delivered
POST /messages/{message_id}/read
POST /chats/{chat_id}/read
GET /messages/{message_id}/reads
POST /devices/register
WS /ws/{chat_id}?token=TOKEN
```

For realtime app chat, main sending should use WebSocket `type=message`.

`POST /messages` can be used as fallback when WebSocket is disconnected.

## Website integration note

The future website can use the same backend.

For browser notifications later:

```txt
Website gets browser FCM token
Website calls POST /devices/register with platform = web
Backend sends to that token exactly like Android
```

The website will need:

```txt
Firebase web app config
firebase-messaging-sw.js
Notification permission request
getToken()
HTTPS in production
```
