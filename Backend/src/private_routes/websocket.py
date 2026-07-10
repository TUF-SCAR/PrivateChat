import json
from src.auth import check_token
from src.database import get_connection
from src.notifications import send_chat_notification
from fastapi import APIRouter, WebSocket, WebSocketDisconnect

router = APIRouter()


chat_rooms = {}


@router.websocket("/ws/{chat_id}")
async def websocket_endpoint(websocket: WebSocket, chat_id: int, token: str):

    token_exists = check_token(token)
    status = token_exists["status"]
    if status == 2:
        await websocket.close()
        return  # Database connection failed
    if status == 1:
        await websocket.close()
        return  # Token invalid or expired
    if status == 0:
        current_user_id = token_exists["id"]

    connection = get_connection()
    if connection == None:
        await websocket.close()
        return  # Database connection failed

    try:
        cursor = connection.cursor()
        cursor.execute(
            "SELECT EXISTS(SELECT 1 FROM chat_members WHERE chat_id = %s AND user_id = %s);",
            (chat_id, current_user_id),
        )
        is_member = cursor.fetchone()[0]
        cursor.execute("SELECT username FROM users WHERE id = %s;", (current_user_id,))
        username = cursor.fetchone()[0]
    finally:
        cursor.close()
        connection.close()

    if not is_member:
        await websocket.close()
        return  # not a member in chat

    online_response = {
        "type": "online",
        "chat_id": chat_id,
        "user_id": current_user_id,
        "username": username,
    }

    offline_response = {
        "type": "offline",
        "chat_id": chat_id,
        "user_id": current_user_id,
        "username": username,
    }

    await websocket.accept()

    if chat_id not in chat_rooms:
        chat_rooms[chat_id] = []
    chat_rooms[chat_id].append(websocket)

    for client in chat_rooms[chat_id]:
        if client != websocket:
            await client.send_text(json.dumps(online_response))

    try:
        while True:
            raw_data = await websocket.receive_text()

            try:
                data = json.loads(raw_data)
                event_type = data["type"]
            except Exception as error:
                print(error)
                continue

            if event_type == "message":
                message_text = data.get("message_text") or ""
                message_text = message_text.strip()

                reply_to_message_id = data.get("reply_to_message_id")

                message_type = data.get("message_type") or "text"
                message_type = message_type.strip().lower()

                media_url = data.get("media_url") or ""
                media_url = media_url.strip()

                preview_url = data.get("preview_url") or ""
                preview_url = preview_url.strip()

                if message_type not in ["text", "gif"]:
                    continue

                if message_type == "text":
                    media_url = ""
                    preview_url = ""

                    if message_text == "":
                        continue

                if message_type == "gif":
                    if media_url == "":
                        continue

                connection = get_connection()
                if connection == None:
                    await websocket.close()
                    return

                try:
                    cursor = connection.cursor()

                    if reply_to_message_id != None:
                        cursor.execute(
                            "SELECT chat_id FROM messages WHERE id = %s;",
                            (reply_to_message_id,),
                        )
                        reply_row = cursor.fetchone()

                        if reply_row == None:
                            continue

                        reply_chat_id = reply_row[0]

                        if reply_chat_id != chat_id:
                            continue

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
                        return

                    message_id = row[0]

                    cursor.execute(
                        "UPDATE chat_members SET is_deleted_for_me = FALSE, deleted_at = NULL WHERE chat_id = %s;",
                        (chat_id,),
                    )

                    connection.commit()

                    cursor.execute(
                        "SELECT messages.id, messages.sender_id, users.username, messages.message_text, messages.is_deleted, messages.is_edited, messages.created_at, messages.edited_at, reply_message.id, reply_message.sender_id, reply_sender.username, reply_message.message_text, reply_message.is_deleted, reply_message.message_type, reply_message.media_url, reply_message.preview_url, messages.message_type, messages.media_url, messages.preview_url FROM messages JOIN users ON messages.sender_id = users.id LEFT JOIN messages AS reply_message ON messages.reply_to_message_id = reply_message.id LEFT JOIN users AS reply_sender ON reply_message.sender_id = reply_sender.id WHERE messages.chat_id = %s AND messages.id = %s;",
                        (chat_id, message_id),
                    )
                    row = cursor.fetchone()

                finally:
                    cursor.close()
                    connection.close()

                if row[8] == None:
                    reply_to = None
                else:
                    if row[12]:
                        reply_message_text = "this message was deleted"
                        reply_message_type = "text"
                        reply_media_url = ""
                        reply_preview_url = ""
                    else:
                        reply_message_text = row[11]
                        reply_message_type = row[13] if row[13] != None else "text"
                        reply_media_url = row[14] if row[14] != None else ""
                        reply_preview_url = row[15] if row[15] != None else ""

                    reply_to = {
                        "message_id": row[8],
                        "sender_id": row[9],
                        "sender_username": row[10],
                        "message_text": reply_message_text,
                        "message_type": reply_message_type,
                        "media_url": reply_media_url,
                        "preview_url": reply_preview_url,
                    }

                if row[4]:
                    final_message_text = "this message was deleted"
                    final_message_type = "text"
                    final_media_url = ""
                    final_preview_url = ""
                else:
                    final_message_text = row[3]
                    final_message_type = row[16] if row[16] != None else "text"
                    final_media_url = row[17] if row[17] != None else ""
                    final_preview_url = row[18] if row[18] != None else ""

                response = {
                    "type": "message",
                    "message_id": row[0],
                    "chat_id": chat_id,
                    "sender_id": row[1],
                    "sender_username": row[2],
                    "message_text": final_message_text,
                    "is_deleted": row[4],
                    "is_edited": row[5],
                    "created_at": str(row[6]),
                    "edited_at": str(row[7]) if row[7] != None else None,
                    "reply_to": reply_to,
                    "message_type": final_message_type,
                    "media_url": final_media_url,
                    "preview_url": final_preview_url,
                    "read_count": 0,
                    "delivery_count": 0,
                }

                for client in chat_rooms[chat_id]:
                    await client.send_text(json.dumps(response))

                notification_result = send_chat_notification(
                    chat_id=chat_id,
                    sender_id=current_user_id,
                    message_id=response["message_id"],
                    message_text=response["message_text"],
                    message_type=response["message_type"],
                )

                print("Notification result:", notification_result)

            elif event_type == "typing":
                response = {
                    "type": "typing",
                    "chat_id": chat_id,
                    "user_id": current_user_id,
                    "username": username,
                }

                for client in chat_rooms[chat_id]:
                    if client != websocket:
                        await client.send_text(json.dumps(response))

            elif event_type == "delivered":
                message_id = data["message_id"]

                connection = get_connection()
                if connection == None:
                    await websocket.close()
                    return  # Database connection failed

                try:
                    cursor = connection.cursor()

                    cursor.execute(
                        "SELECT chat_id, sender_id, is_deleted FROM messages WHERE id = %s;",
                        (message_id,),
                    )
                    row = cursor.fetchone()
                    if row == None:
                        continue  # message does not exist

                    message_chat_id = row[0]
                    sender_id = row[1]
                    is_deleted = row[2]

                    if message_chat_id != chat_id:
                        continue
                    if current_user_id == sender_id:
                        continue
                    if is_deleted:
                        continue

                    cursor.execute(
                        "INSERT INTO message_deliveries (message_id, user_id) VALUES (%s, %s) ON CONFLICT (message_id, user_id) DO NOTHING;",
                        (message_id, current_user_id),
                    )
                    marked = cursor.rowcount == 1

                    connection.commit()
                finally:
                    cursor.close()
                    connection.close()

                response = {
                    "type": "delivered",
                    "chat_id": chat_id,
                    "message_id": message_id,
                    "user_id": current_user_id,
                    "username": username,
                    "marked": marked,
                }

                for client in chat_rooms[chat_id]:
                    if client != websocket:
                        await client.send_text(json.dumps(response))

            elif event_type == "read_receipt":
                message_id = data["message_id"]

                connection = get_connection()
                if connection == None:
                    await websocket.close()
                    return  # Database connection failed

                try:
                    cursor = connection.cursor()

                    cursor.execute(
                        "SELECT chat_id, sender_id, is_deleted FROM messages WHERE id = %s;",
                        (message_id,),
                    )
                    row = cursor.fetchone()
                    if row == None:
                        continue  # message does not exist

                    message_chat_id = row[0]
                    sender_id = row[1]
                    is_deleted = row[2]

                    if message_chat_id != chat_id:
                        continue
                    if current_user_id == sender_id:
                        continue
                    if is_deleted:
                        continue

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

                response = {
                    "type": "read_receipt",
                    "chat_id": chat_id,
                    "message_id": message_id,
                    "user_id": current_user_id,
                    "username": username,
                    "marked": marked,
                }

                for client in chat_rooms[chat_id]:
                    if client != websocket:
                        await client.send_text(json.dumps(response))

    except WebSocketDisconnect:
        chat_rooms[chat_id].remove(websocket)
        if chat_rooms[chat_id] == []:
            chat_rooms.pop(chat_id)
        else:
            for client in chat_rooms[chat_id]:
                if client != websocket:
                    await client.send_text(json.dumps(offline_response))
