from jose import jwt, JWTError, ExpiredSignatureError
from src.database import get_connection
from dotenv import load_dotenv
from os import getenv

load_dotenv()


def check_token(token: str):

    if token == "" or token == None:
        return {"status": 1}

    if token.startswith("Bearer "):
        token = token[7:]

    SECRET_KEY = getenv("TOKEN_SECRET_KEY")
    ALGORITHM = "HS256"

    try:
        payload = jwt.decode(token, SECRET_KEY, algorithms=[ALGORITHM])
        if "user_id" not in payload:
            return {"status": 1}
        user_id = payload["user_id"]
    except ExpiredSignatureError:
        return {"status": 1}
    except JWTError:
        return {"status": 1}

    connection = get_connection()
    if connection == None:
        return {"status": 2}

    try:
        cursor = connection.cursor()
        cursor.execute("SELECT id FROM users WHERE id = %s;", (user_id,))
        user_id = cursor.fetchone()
    finally:
        cursor.close()
        connection.close()

    if user_id == None:
        return {"status": 1}

    user_id = user_id[0]

    return {
        "status": 0,
        "id": user_id,
    }
