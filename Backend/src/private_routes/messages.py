from fastapi import APIRouter, Header
from pydantic import BaseModel
from src.auth import check_token
from src.database import get_connection
from datetime import datetime, timedelta
from src.notifications import send_chat_notification


class EditMessage(BaseModel):
    message_text: str


class Messages(BaseModel):
    chat_id: int
    message_text: str | None = None
    reply_to_message_id: int | None = None
    message_type: str | None = None
    media_url: str | None = None
    preview_url: str | None = None


router = APIRouter()


@router.post("/messages")
def send_messages(
    message: Messages, authorization: str = Header(None, alias="Authorization")
):
    chat_id = message.chat_id
    message_text = message.message_text.strip() if message.message_text else ""
    reply_to_message_id = message.reply_to_message_id
    message_type = (
        message.message_type.strip().lower() if message.message_type else "text"
    )
    media_url = message.media_url.strip() if message.media_url else ""
    preview_url = message.preview_url.strip() if message.preview_url else ""
    token = authorization

    if message_type == None:
        message_type = "text"

    if message_type not in ["text", "gif"]:
        return {"error": "invalid message type"}

    if message_type == "text":
        media_url = ""
        preview_url = ""
        if message_text == "":
            return {"error": "invalid message"}

    if message_type == "gif":
        if media_url == "":
            return {"error": "invalid gif url"}

    token_exists = check_token(token)
    status = token_exists["status"]
    if status == 2:
        return {"error": "Database connection failed"}
    if status == 1:
        return {"error": "token invalid or expired"}
    if status == 0:
        current_user_id = token_exists["id"]

    connection = get_connection()
    if connection == None:
        return {"error": "Database connection failed"}

    try:
        cursor = connection.cursor()

        cursor.execute("SELECT EXISTS(SELECT 1 FROM chats WHERE id = %s);", (chat_id,))
        chat_exists = cursor.fetchone()[0]
        if not chat_exists:
            return {"error": "chat does not exist"}

        cursor.execute(
            "SELECT EXISTS(SELECT 1 FROM chat_members WHERE chat_id = %s AND user_id = %s);",
            (chat_id, current_user_id),
        )
        user_exists = cursor.fetchone()[0]

        if not user_exists:
            return {"error": "access denied"}

        if reply_to_message_id != None:
            cursor.execute(
                "SELECT chat_id, sender_id FROM messages WHERE id = %s;",
                (reply_to_message_id,),
            )
            row = cursor.fetchone()
            if row == None:
                return {"error": "reply message does not exist"}
            reply_chat_id = row[0]
            if reply_chat_id != chat_id:
                return {"error": "reply message is not in this chat"}

        cursor.execute(
            "INSERT INTO messages (chat_id, sender_id, message_text, reply_to_message_id, message_type, media_url, preview_url) VALUES (%s, %s, %s, %s, %s, %s, %s) RETURNING id;",
            (
                chat_id,
                current_user_id,
                message_text,
                reply_to_message_id,
                message_type,
                media_url,
                preview_url,
            ),
        )
        row = cursor.fetchone()
        if row == None:
            return {"error": "Database error"}
        message_id = row[0]

        cursor.execute(
            "UPDATE chat_members SET is_deleted_for_me = FALSE, deleted_at = NULL WHERE chat_id = %s;",
            (chat_id,),
        )

        connection.commit()
    finally:
        cursor.close()
        connection.close()

    notification_result = send_chat_notification(
        chat_id=chat_id,
        sender_id=current_user_id,
        message_id=message_id,
        message_text=message_text,
        message_type=message_type,
    )

    return {
        "message": "message sent",
        "message_id": message_id,
        "chat_id": chat_id,
        "sender_id": current_user_id,
        "message_text": message_text,
        "message_type": message_type,
        "media_url": media_url,
        "preview_url": preview_url,
        "reply_to_message_id": reply_to_message_id,
        "notification": notification_result,
    }


@router.get("/messages/{chat_id}")
def read_messages(
    chat_id: int,
    limit: int = 50,
    offset: int = 0,
    authorization: str = Header(None, alias="Authorization"),
):
    token = authorization

    token_exists = check_token(token)
    status = token_exists["status"]
    if status == 2:
        return {"error": "Database connection failed"}
    if status == 1:
        return {"error": "token invalid or expired"}
    if status == 0:
        current_user_id = token_exists["id"]

    if limit < 1:
        return {"error": "invalid limit"}
    if limit > 100:
        return {"error": "invalid limit"}
    if offset < 0:
        return {"error": "invalid offset"}

    connection = get_connection()
    if connection == None:
        return {"error": "Database connection failed"}

    try:
        cursor = connection.cursor()

        cursor.execute(
            "SELECT EXISTS(SELECT 1 FROM chat_members WHERE chat_id = %s AND user_id = %s);",
            (chat_id, current_user_id),
        )
        is_member = cursor.fetchone()[0]

        if not is_member:
            return {"error": "access denied or chat does not exist"}

        cursor.execute(
            "SELECT messages.id, messages.sender_id, users.username, messages.message_text, messages.is_deleted, messages.created_at, messages.is_edited, messages.edited_at, (SELECT COUNT(*) FROM message_reads WHERE message_reads.message_id = messages.id) AS read_count, (SELECT COUNT(*) FROM message_deliveries WHERE message_deliveries.message_id = messages.id) AS delivery_count, reply_message.id, reply_message.sender_id, reply_sender.username, reply_message.message_text, reply_message.is_deleted, reply_message.message_type, reply_message.media_url, reply_message.preview_url, messages.message_type, messages.media_url, messages.preview_url FROM messages JOIN users ON messages.sender_id = users.id LEFT JOIN messages AS reply_message ON messages.reply_to_message_id = reply_message.id LEFT JOIN users AS reply_sender ON reply_message.sender_id = reply_sender.id WHERE messages.chat_id = %s ORDER BY messages.created_at DESC LIMIT %s OFFSET %s;",
            (chat_id, limit, offset),
        )
        rows = cursor.fetchall()

    finally:
        cursor.close()
        connection.close()

    messages = []

    for row in rows:
        if row[10] == None:
            reply_to = None
        else:
            if row[14]:
                reply_message_text = "this message was deleted"
                reply_message_type = "text"
                reply_media_url = ""
                reply_preview_url = ""
            else:
                reply_message_text = row[13]
                reply_message_type = row[15] if row[15] != None else "text"
                reply_media_url = row[16] if row[16] != None else ""
                reply_preview_url = row[17] if row[17] != None else ""

            reply_to = {
                "message_id": row[10],
                "sender_id": row[11],
                "sender_username": row[12],
                "message_text": reply_message_text,
                "message_type": reply_message_type,
                "media_url": reply_media_url,
                "preview_url": reply_preview_url,
            }

        if row[4]:
            message_text = "this message was deleted"
            message_type = "text"
            media_url = ""
            preview_url = ""
        else:
            message_text = row[3]
            message_type = row[18] if row[18] != None else "text"
            media_url = row[19] if row[19] != None else ""
            preview_url = row[20] if row[20] != None else ""

        message = {
            "message_id": row[0],
            "sender_id": row[1],
            "sender_username": row[2],
            "message_text": message_text,
            "is_deleted": row[4],
            "created_at": str(row[5]),
            "is_edited": row[6],
            "edited_at": str(row[7]) if row[7] != None else None,
            "read_count": row[8],
            "delivery_count": row[9],
            "reply_to": reply_to,
            "message_type": message_type,
            "media_url": media_url,
            "preview_url": preview_url,
        }

        messages.append(message)

    return {
        "message": "messages fetched",
        "limit": limit,
        "offset": offset,
        "messages": messages,
    }


@router.delete("/messages/{message_id}")
def soft_delete_message(
    message_id: int, authorization: str = Header(None, alias="Authorization")
):
    token = authorization

    token_exists = check_token(token)
    status = token_exists["status"]
    if status == 2:
        return {"error": "Database connection failed"}
    if status == 1:
        return {"error": "token invalid or expired"}
    if status == 0:
        current_user_id = token_exists["id"]

    connection = get_connection()
    if connection == None:
        return {"error": "Database connection failed"}

    try:
        cursor = connection.cursor()
        cursor.execute(
            "SELECT sender_id FROM messages WHERE id = %s;",
            (message_id,),
        )
        row = cursor.fetchone()
        if row == None:
            return {"error": "message not found"}
        sender_id = row[0]
    finally:
        cursor.close()
        connection.close()

    if sender_id != current_user_id:
        return {"error": "access denied"}

    connection = get_connection()
    if connection == None:
        return {"error": "Database connection failed"}

    try:
        cursor = connection.cursor()
        cursor.execute(
            "UPDATE messages SET is_deleted = TRUE WHERE id = %s;", (message_id,)
        )
        connection.commit()
    finally:
        cursor.close()
        connection.close()

    return {"message": "This message was deleted"}


@router.patch("/messages/{message_id}")
def edit_message(
    message_id: int,
    data: EditMessage,
    authorization: str = Header(None, alias="Authorization"),
):
    new_message_text = data.message_text.strip()
    token = authorization

    if new_message_text == "":
        return {"error": "invalid message"}

    token_exists = check_token(token)
    status = token_exists["status"]
    if status == 2:
        return {"error": "Database connection failed"}
    if status == 1:
        return {"error": "token invalid or expired"}
    if status == 0:
        current_user_id = token_exists["id"]

    connection = get_connection()
    if connection == None:
        return {"error": "Database connection failed"}

    try:
        cursor = connection.cursor()

        cursor.execute(
            "SELECT sender_id, is_deleted, created_at FROM messages WHERE id = %s;",
            (message_id,),
        )
        row = cursor.fetchone()
        if row == None:
            return {"error": "message does not exist"}
        sender_id = row[0]
        is_deleted = row[1]

        if sender_id != current_user_id:
            return {"error": "access denied"}

        if is_deleted:
            return {"error": "cannot edit deleted messages"}

        created_at = row[2]
        current_time = datetime.utcnow()
        time_difference = current_time - created_at

        if time_difference > timedelta(minutes=5):
            return {"error": "message can no longer be edited"}

        cursor.execute(
            "UPDATE messages SET message_text = %s, is_edited = TRUE, edited_at = CURRENT_TIMESTAMP WHERE id = %s;",
            (new_message_text, message_id),
        )
        connection.commit()
    finally:
        cursor.close()
        connection.close()

    return {"message": "message edited"}


@router.post("/chats/{chat_id}/read")
def mark_chat_as_read(
    chat_id: int, authorization: str = Header(None, alias="Authorization")
):
    token = authorization

    token_exists = check_token(token)
    status = token_exists["status"]
    if status == 2:
        return {"error": "Database connection failed"}
    if status == 1:
        return {"error": "token invalid or expired"}
    if status == 0:
        current_user_id = token_exists["id"]

    connection = get_connection()
    if connection == None:
        return {"error": "Database connection failed"}

    try:
        cursor = connection.cursor()

        cursor.execute("SELECT EXISTS(SELECT 1 FROM chats WHERE id = %s);", (chat_id,))
        chat_exists = cursor.fetchone()[0]

        if not chat_exists:
            return {"error": "chat does not exist"}

        cursor.execute(
            "SELECT EXISTS(SELECT 1 FROM chat_members WHERE chat_id = %s AND user_id = %s);",
            (chat_id, current_user_id),
        )
        is_member = cursor.fetchone()[0]

        if not is_member:
            return {"error": "access denied"}

        cursor.execute(
            "INSERT INTO message_deliveries (message_id, user_id) SELECT id, %s FROM messages WHERE chat_id = %s AND sender_id != %s AND is_deleted = FALSE ON CONFLICT (message_id, user_id) DO NOTHING;",
            (current_user_id, chat_id, current_user_id),
        )

        cursor.execute(
            "INSERT INTO message_reads (message_id, user_id) SELECT id, %s FROM messages WHERE chat_id = %s AND sender_id != %s AND is_deleted = FALSE ON CONFLICT (message_id, user_id) DO NOTHING;",
            (current_user_id, chat_id, current_user_id),
        )
        marked_count = cursor.rowcount

        connection.commit()
    finally:
        cursor.close()
        connection.close()

    return {
        "message": "chat marked as read",
        "marked_count": marked_count,
    }


@router.post("/messages/{message_id}/read")
def mark_message_as_read(
    message_id: int, authorization: str = Header(None, alias="Authorization")
):
    token = authorization

    token_exists = check_token(token)
    status = token_exists["status"]
    if status == 2:
        return {"error": "Database connection failed"}
    if status == 1:
        return {"error": "token invalid or expired"}
    if status == 0:
        current_user_id = token_exists["id"]

    connection = get_connection()
    if connection == None:
        return {"error": "Database connection failed"}

    try:
        cursor = connection.cursor()

        cursor.execute(
            "SELECT chat_id, sender_id, is_deleted FROM messages WHERE id = %s;",
            (message_id,),
        )
        row = cursor.fetchone()
        if row == None:
            return {"error": "message does not exist"}

        chat_id = row[0]
        sender_id = row[1]
        is_deleted = row[2]

        if is_deleted:
            return {"error": "message deleted"}

        cursor.execute(
            "SELECT EXISTS(SELECT 1 FROM chat_members WHERE chat_id = %s AND user_id = %s);",
            (chat_id, current_user_id),
        )
        current_user_in_chat = cursor.fetchone()[0]
        if not current_user_in_chat:
            return {"error": "access denied"}

        if sender_id == current_user_id:
            return {
                "message": "own message does not need read receipt",
                "marked": False,
            }

        cursor.execute(
            "INSERT INTO message_deliveries (message_id, user_id) VALUES (%s, %s) ON CONFLICT (message_id, user_id) DO NOTHING;",
            (message_id, current_user_id),
        )

        cursor.execute(
            "INSERT INTO message_reads (message_id, user_id) VALUES (%s, %s) ON CONFLICT (message_id, user_id) DO NOTHING;",
            (message_id, current_user_id),
        )
        marked = cursor.rowcount == 1

        connection.commit()
    finally:
        cursor.close()
        connection.close()

    return {
        "message": (
            "message marked as read" if marked else "message already marked as read"
        ),
        "marked": marked,
    }


@router.get("/messages/{message_id}/reads")
def show_message_reads(
    message_id: int, authorization: str = Header(None, alias="Authorization")
):
    token = authorization

    token_exists = check_token(token)
    status = token_exists["status"]
    if status == 2:
        return {"error": "Database connection failed"}
    if status == 1:
        return {"error": "token invalid or expired"}
    if status == 0:
        current_user_id = token_exists["id"]

    read_by = []

    connection = get_connection()
    if connection == None:
        return {"error": "Database connection failed"}

    try:
        cursor = connection.cursor()

        cursor.execute(
            "SELECT chat_id FROM messages WHERE id = %s;",
            (message_id,),
        )
        row = cursor.fetchone()
        if row == None:
            return {"error": "message does not exist"}

        chat_id = row[0]

        cursor.execute(
            "SELECT EXISTS(SELECT 1 FROM chat_members WHERE chat_id = %s AND user_id = %s);",
            (chat_id, current_user_id),
        )
        current_user_in_chat = cursor.fetchone()[0]
        if not current_user_in_chat:
            return {"error": "access denied"}

        cursor.execute(
            "SELECT users.id, users.username, message_reads.read_at FROM message_reads JOIN users ON message_reads.user_id = users.id WHERE message_reads.message_id = %s ORDER BY message_reads.read_at ASC;",
            (message_id,),
        )
        rows = cursor.fetchall()
        read_count = len(rows)
    finally:
        cursor.close()
        connection.close()

    for row in rows:
        reads = {
            "user_id": row[0],
            "username": row[1],
            "read_at": str(row[2]),
        }
        read_by.append(reads)

    return {
        "message": "message reads fetched",
        "message_id": message_id,
        "read_count": read_count,
        "read_by": read_by,
    }


@router.post("/messages/{message_id}/delivered")
def mark_message_as_delivered(
    message_id: int, authorization: str = Header(None, alias="Authorization")
):
    token = authorization

    token_exists = check_token(token)
    status = token_exists["status"]
    if status == 2:
        return {"error": "Database connection failed"}
    if status == 1:
        return {"error": "token invalid or expired"}
    if status == 0:
        current_user_id = token_exists["id"]

    connection = get_connection()
    if connection == None:
        return {"error": "Database connection failed"}

    try:
        cursor = connection.cursor()

        cursor.execute(
            "SELECT chat_id, sender_id, is_deleted FROM messages WHERE id = %s;",
            (message_id,),
        )
        row = cursor.fetchone()
        if row == None:
            return {"error": "message does not exist"}

        chat_id = row[0]
        sender_id = row[1]
        is_deleted = row[2]

        if is_deleted:
            return {"error": "message deleted"}

        cursor.execute(
            "SELECT EXISTS(SELECT 1 FROM chat_members WHERE chat_id = %s AND user_id = %s);",
            (chat_id, current_user_id),
        )
        current_user_in_chat = cursor.fetchone()[0]
        if not current_user_in_chat:
            return {"error": "access denied"}

        if sender_id == current_user_id:
            return {
                "message": "own message does not need delivery receipt",
                "marked": False,
            }

        cursor.execute(
            "INSERT INTO message_deliveries (message_id, user_id) VALUES (%s, %s) ON CONFLICT (message_id, user_id) DO NOTHING;",
            (message_id, current_user_id),
        )
        marked = cursor.rowcount == 1

        connection.commit()
    finally:
        cursor.close()
        connection.close()

    return {
        "message": (
            "message marked as delivered"
            if marked
            else "message already marked as delivered"
        ),
        "marked": marked,
    }
