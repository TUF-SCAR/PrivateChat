from pydantic import BaseModel
from fastapi import APIRouter, Header
from src.auth import check_token
from src.database import get_connection


class Chat(BaseModel):
    other_user_id: int


router = APIRouter()


@router.post("/chats")
def make_chat(
    other_user: Chat, authorization: str = Header(None, alias="Authorization")
):
    other_user_id = other_user.other_user_id
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
            "SELECT EXISTS(SELECT 1 FROM users WHERE id = %s);", (other_user_id,)
        )
        other_user_exists = cursor.fetchone()[0]
    finally:
        cursor.close()
        connection.close()

    if not other_user_exists:
        return {"error": "other user does not exist"}

    if other_user_id == current_user_id:
        return {"error": "cannot create chat with yourself"}

    connection = get_connection()
    if connection == None:
        return {"error": "Database connection failed"}

    try:
        cursor = connection.cursor()
        cursor.execute(
            "SELECT chats.id FROM chats JOIN chat_members AS member1 ON chats.id = member1.chat_id JOIN chat_members AS member2 ON chats.id = member2.chat_id WHERE chats.is_group = FALSE AND member1.user_id = %s AND member2.user_id = %s;",
            (current_user_id, other_user_id),
        )
        row = cursor.fetchone()
        if row != None:
            return {
                "message": "chat already exists",
                "chat_id": row[0],
            }
    finally:
        cursor.close()
        connection.close()

    connection = get_connection()
    if connection == None:
        return {"error": "Database connection failed"}

    try:
        cursor = connection.cursor()
        cursor.execute(
            "INSERT INTO chats (is_group, name) VALUES (FALSE, NULL) RETURNING id;"
        )
        row = cursor.fetchone()
        if row == None:
            return {"error": "Database error"}
        chat_id = row[0]
        cursor.execute(
            "INSERT INTO chat_members (chat_id, user_id) VALUES (%s, %s);",
            (chat_id, current_user_id),
        )
        cursor.execute(
            "INSERT INTO chat_members (chat_id, user_id) VALUES (%s, %s);",
            (chat_id, other_user_id),
        )
        connection.commit()
    finally:
        cursor.close()
        connection.close()

    return {
        "message": "successfully created chat",
        "chat_id": chat_id,
    }


@router.get("/chats")
def all_chat(authorization: str = Header(None, alias="Authorization")):

    token = authorization

    token_exists = check_token(token)
    status = token_exists["status"]
    if status == 2:
        return {"error": "Database connection failed"}
    if status == 1:
        return {"error": "token invalid or expired"}
    if status == 0:
        current_user_id = token_exists["id"]

    chats = []

    connection = get_connection()
    if connection == None:
        return {"error": "Database connection failed"}

    try:
        cursor = connection.cursor()
        cursor.execute(
            "SELECT chats.id, chats.is_group, chats.name, users.id, users.username FROM chats JOIN chat_members AS my_member ON chats.id = my_member.chat_id JOIN chat_members AS other_member ON chats.id = other_member.chat_id JOIN users ON other_member.user_id = users.id WHERE my_member.user_id = %s AND other_member.user_id != %s AND is_group = FALSE;",
            (current_user_id, current_user_id),
        )
        rows = cursor.fetchall()
    finally:
        cursor.close()
        connection.close()

    for row in rows:
        chat = {
            "chat_id": row[0],
            "is_group": row[1],
            "chat_name": row[2],
            "other_user_id": row[3],
            "other_username": row[4],
        }
        chats.append(chat)

    return {
        "message": "chats fetched",
        "chats": chats,
    }
