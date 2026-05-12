from fastapi import APIRouter, Header
from src.auth import check_token
from src.database import get_connection

router = APIRouter()


@router.get("/users/search")
def search_users(
    username: str, authorization: str = Header(None, alias="Authorization")
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

    username = username.strip()
    if username == "":
        return {"error": "invalid username"}

    search_text = "%" + username + "%"

    connection = get_connection()
    if connection == None:
        return {"error": "Database connection failed"}

    users = []

    try:
        cursor = connection.cursor()
        cursor.execute(
            "SELECT id, username FROM users WHERE username ILIKE %s AND id != %s LIMIT 10;",
            (search_text, current_user_id),
        )
        rows = cursor.fetchall()
        if rows == []:
            return {
                "message": "users fetched",
                "users": rows,
            }
    finally:
        cursor.close()
        connection.close()

    for row in rows:
        user = {
            "id": row[0],
            "username": row[1],
        }
        users.append(user)

    return {
        "message": "users fetched",
        "users": users,
    }
