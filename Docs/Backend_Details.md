# PrivateChat Backend Details

PrivateChat backend is a FastAPI + PostgreSQL chat backend. It supports account auth, private chats, group chats, messaging, message editing/deleting, pagination, read receipts, replies, WebSocket realtime events, and device-token registration for push notifications.

## Common rule for private routes

Private routes require this header:

```txt
Authorization: Bearer YOUR_TOKEN_HERE
```

The token is created during login and checked by `check_token()`.

## Main database tables

| Table           | Purpose                                                                                               |
| --------------- | ----------------------------------------------------------------------------------------------------- |
| `users`         | Stores username, email, hashed password, and creation time.                                           |
| `chats`         | Stores private chats and group chats. `is_group = false` means private chat, `true` means group chat. |
| `chat_members`  | Stores which users are inside each chat, group roles, and delete-for-me state.                        |
| `messages`      | Stores messages, soft-delete state, edit state, and optional reply target.                            |
| `message_reads` | Stores read receipts. One row means one user read one message.                                        |
| `user_devices`  | Stores Firebase/device tokens for future push notifications.                                          |

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

Returns all private chats for the current user. Deleted-for-me chats are hidden. The response includes last message preview and unread count.

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

Sends a message. Supports normal messages and reply messages.

Normal message body:

```json
{
  "chat_id": 1,
  "message_text": "hello bro"
}
```

Reply message body:

```json
{
  "chat_id": 1,
  "message_text": "yes bro",
  "reply_to_message_id": 10
}
```

Checks token, chat existence, membership, message text, and if replying, checks that the replied message exists in the same chat.

Success:

```json
{
  "message": "message sent",
  "message_id": 20
}
```

### `GET /messages/{chat_id}?limit=50&offset=0`

Fetches messages from a chat with pagination. It returns newest messages first because of descending order. Frontend can use `offset` to load older messages when scrolling up.

Response includes edit state, delete state, read count, and reply preview.

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
      "reply_to": {
        "message_id": 10,
        "sender_id": 2,
        "sender_username": "zoro",
        "message_text": "are you coming?"
      }
    }
  ]
}
```

If a message is soft-deleted, its text is returned as:

```txt
this message was deleted
```

### `PATCH /messages/{message_id}`

Edits a message. Only the sender can edit. Deleted messages cannot be edited. Messages can only be edited within 5 minutes.

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

## Read receipt routes

### `POST /chats/{chat_id}/read`

Marks all unread messages in a chat as read for the current user. Own messages and deleted messages are skipped.

Success:

```json
{
  "message": "chat marked as read",
  "marked_count": 4
}
```

### `POST /messages/{message_id}/read`

Marks one message as read for the current user. Own messages do not need read receipts.

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

Changes a member role. Only admins can change roles. Allowed roles are `admin` and `member`. Last admin cannot be demoted.

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

Removes a member from a group. Only admins can remove members. Admin cannot remove themselves using this route, and the last admin cannot be removed.

Success:

```json
{
  "message": "member removed"
}
```

### `DELETE /groups/{chat_id}/leave`

Current user leaves a group. If they are the last member, the group is deleted. If they are the only admin, they must assign another admin first.

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
android, ios, web
```

Success:

```json
{
  "message": "device registered"
}
```

## WebSocket route

### `WS /ws/{chat_id}?token=TOKEN_HERE`

Used for realtime chat events. User must be a member of the chat.

Supported incoming event types:

### Message event

Normal message:

```json
{
  "type": "message",
  "message_text": "hello"
}
```

Reply message:

```json
{
  "type": "message",
  "message_text": "yes bro",
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
    "message_text": "are you coming?"
  }
}
```

### Typing event

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

### Read receipt event

Incoming:

```json
{
  "type": "read_receipt",
  "message_id": 20
}
```

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

### Online/offline events

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

| File          | Purpose                                          |
| ------------- | ------------------------------------------------ |
| `auth.py`     | Creates JWT tokens and checks tokens.            |
| `database.py` | Opens PostgreSQL connection using `.env` values. |
| `security.py` | Validates username and email format.             |
| `util.py`     | Hashes passwords and verifies passwords.         |
| `devices.py`  | Stores Firebase/device tokens.                   |

## Current MVP status

Completed backend features:

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
- Read receipts
- Reply to message
- WebSocket realtime messaging
- WebSocket typing indicator
- WebSocket online/offline events
- WebSocket read receipts
- Device-token registration for push notifications

Not included in MVP:

- File sharing
- Voice messages
- Reactions
- Block/report
- Full end-to-end encryption
