from fastapi import APIRouter, Header
from pydantic import BaseModel
from src.auth import check_token
from src.database import get_connection


class Messages(BaseModel):
    chat_id: int
    message_text: str


router = APIRouter()


@router.post("/messages")
def send_messages(
    message: Messages, authorization: str = Header(None, alias="Authorization")
):
    chat_id = message.chat_id
    message_text = message.message_text.strip()
    token = authorization

    if message_text == "":
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
        cursor.execute("SELECT EXISTS(SELECT 1 FROM chats WHERE id = %s);", (chat_id,))
        chat_exists = cursor.fetchone()[0]
    finally:
        cursor.close()
        connection.close()

    if not chat_exists:
        return {"error": "chat does not exist"}

    connection = get_connection()
    if connection == None:
        return {"error": "Database connection failed"}

    try:
        cursor = connection.cursor()
        cursor.execute(
            "SELECT EXISTS(SELECT 1 FROM chat_members WHERE chat_id = %s AND user_id = %s);",
            (chat_id, current_user_id),
        )
        user_exists = cursor.fetchone()[0]
    finally:
        cursor.close()
        connection.close()

    if not user_exists:
        return {"error": "access denied"}

    connection = get_connection()
    if connection == None:
        return {"error": "Database connection failed"}

    try:
        cursor = connection.cursor()
        cursor.execute(
            "INSERT INTO messages (chat_id, sender_id, message_text) VALUES (%s, %s, %s) RETURNING id;",
            (chat_id, current_user_id, message_text),
        )
        row = cursor.fetchone()
        if row == None:
            return {"error": "Database error"}
        message_id = row[0]
        connection.commit()
    finally:
        cursor.close()
        connection.close()

    return {
        "message": "message sent",
        "message_id": message_id,
    }


@router.get("/messages/{chat_id}")
def read_messages(
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
        cursor.execute(
            "SELECT EXISTS(SELECT 1 FROM chat_members WHERE chat_id = %s AND user_id = %s);",
            (chat_id, current_user_id),
        )
        is_member = cursor.fetchone()[0]
    finally:
        cursor.close()
        connection.close()

    if not is_member:
        return {"error": "access denied or chat does not exist"}

    messages = []

    connection = get_connection()
    if connection == None:
        return {"error": "Database connection failed"}

    try:
        cursor = connection.cursor()
        cursor.execute(
            "SELECT messages.id, messages.sender_id, users.username, messages.message_text, messages.is_deleted, messages.created_at FROM messages JOIN users ON messages.sender_id = users.id WHERE messages.chat_id = %s ORDER BY messages.created_at ASC;",
            (chat_id,),
        )
        rows = cursor.fetchall()
    finally:
        cursor.close()
        connection.close()

    for row in rows:
        message = {
            "message_id": row[0],
            "sender_id": row[1],
            "sender_name": row[2],
            "message_text": row[3],
            "is_deleted": row[4],
            "created_at": str(row[5]),
        }
        messages.append(message)

    return {
        "message": "messages fetched",
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
