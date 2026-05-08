from fastapi import APIRouter, Header
from src.auth import check_token
from src.database import get_connection

router = APIRouter()


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
            "SELECT chats.id, chats.is_group, chats.name, users.id, users.username FROM chats JOIN chat_members AS my_member ON chats.id = my_member.chat_id JOIN chat_members AS other_member ON chats.id = other_member.chat_id JOIN users ON other_member.user_id = users.id WHERE my_member.user_id = %s AND other_member.user_id != %s;",
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
