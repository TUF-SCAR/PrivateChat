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
            chat_id = row[0]

            cursor.execute(
                "UPDATE chat_members SET is_deleted_for_me = FALSE, deleted_at = NULL WHERE chat_id = %s AND user_id = %s;",
                (chat_id, current_user_id),
            )
            connection.commit()

            return {
                "message": "chat already exists",
                "chat_id": chat_id,
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
            "SELECT chats.id, chats.is_group, chats.name, users.id, users.username FROM chats JOIN chat_members AS my_member ON chats.id = my_member.chat_id JOIN chat_members AS other_member ON chats.id = other_member.chat_id JOIN users ON other_member.user_id = users.id WHERE my_member.user_id = %s AND other_member.user_id != %s AND is_group = FALSE AND my_member.is_deleted_for_me = FALSE;",
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


@router.get("/chats/{chat_id}")
def open_chat(chat_id: int, authorization: str = Header(None, alias="Authorization")):
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
            "SELECT EXISTS(SELECT 1 FROM chats WHERE id = %s);",
            (chat_id,),
        )
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
            "SELECT chats.id, chats.is_group, chats.name, chat_members.role FROM chats JOIN chat_members ON chats.id = chat_members.chat_id WHERE chats.id = %s AND chat_members.user_id = %s;",
            (chat_id, current_user_id),
        )
        row = cursor.fetchone()
        if row == None:
            return {"error": "access denied"}
        chat_id_db = row[0]
        is_group = row[1]
        chat_name = row[2]
        my_role = row[3]

        if is_group:
            other_user_id = None
            other_username = None
        else:
            cursor.execute(
                "SELECT users.id, users.username FROM chat_members JOIN users ON chat_members.user_id = users.id WHERE chat_members.chat_id = %s AND users.id != %s;",
                (chat_id, current_user_id),
            )
            row = cursor.fetchone()
            if row == None:
                return {"error": "access denied"}
            other_user_id = row[0]
            other_username = row[1]
    finally:
        cursor.close()
        connection.close()

    chat = {
        "chat_id": chat_id_db,
        "is_group": is_group,
        "chat_name": chat_name,
        "my_role": my_role,
        "other_user_id": other_user_id,
        "other_username": other_username,
    }

    return {
        "message": "chat fetched",
        "chat": chat,
    }


@router.delete("/chats/{chat_id}")
def delete_chat(chat_id: int, authorization: str = Header(None, alias="Authorization")):
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
            "SELECT EXISTS(SELECT 1 FROM chats WHERE id = %s AND is_group = FALSE);",
            (chat_id,),
        )
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
            "UPDATE chat_members SET is_deleted_for_me = TRUE, deleted_at = CURRENT_TIMESTAMP WHERE chat_id = %s AND user_id = %s;",
            (chat_id, current_user_id),
        )
        connection.commit()
    finally:
        cursor.close()
        connection.close()

    return {"message": "chat deleted"}
