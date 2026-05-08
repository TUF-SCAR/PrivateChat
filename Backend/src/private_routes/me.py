from fastapi import APIRouter, Header
from src.auth import check_token
from src.database import get_connection

router = APIRouter()


@router.get("/me")
def authentication(authorization: str = Header(None, alias="Authorization")):
    token = authorization

    token_exists = check_token(token)
    status = token_exists["status"]
    if status == 2:
        return {"error": "Database connection failed"}
    if status == 1:
        return {"error": "token invalid or expired"}
    if status == 0:
        user_id = token_exists["id"]

    connection = get_connection()
    if connection == None:
        return {"error": "Database connection failed"}

    try:
        cursor = connection.cursor()
        cursor.execute("SELECT username FROM users WHERE id = %s;", (user_id,))
        row = cursor.fetchone()[0]
        if row == None:
            return {"error": "token invalid or expired"}
        username = row[0]
    finally:
        cursor.close()
        connection.close()

    return {
        "message": "token valid",
        "id": user_id,
        "username": username,
    }
