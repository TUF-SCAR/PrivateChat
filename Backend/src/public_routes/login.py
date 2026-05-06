from fastapi import APIRouter
from pydantic import BaseModel
from jose import jwt
from dotenv import load_dotenv
from os import getenv
from datetime import datetime, timedelta, timezone
from src.util import checkPassword
from src.database import get_connection
from src.security import check_email, check_username_char

load_dotenv()


class LogIn(BaseModel):
    email_or_username: str
    password: str


SECRET_KEY = getenv("TOKEN_SECRET_KEY")
ALGORITHM = "HS256"
ACCESS_TOKEN_EXPIRE_MINUTES = 60

router = APIRouter()


@router.post("/login")
def login(user: LogIn):
    email_or_username = user.email_or_username.strip()
    if "@" in email_or_username:
        email_or_username = user.email_or_username.strip().lower()
        is_email = True
        if not check_email(email_or_username):
            return {"error": "invalid email or password"}
    else:
        is_email = False
        if email_or_username == "":
            return {"error": "invalid username or password"}
        if len(email_or_username) < 3:
            return {"error": "invalid username or password"}
        if len(email_or_username) > 25:
            return {"error": "invalid username or password"}
        if not check_username_char(email_or_username):
            return {"error": "invalid username or password"}

    connection = get_connection()
    if connection == None:
        return {"error": "Database connection failed"}

    try:
        cursor = connection.cursor()
        email_exists = False
        username_exists = False
        if is_email:
            cursor.execute(
                "SELECT EXISTS(SELECT 1 FROM users WHERE email = %s);",
                (email_or_username,),
            )
            email_exists = cursor.fetchone()[0]
        else:
            cursor.execute(
                "SELECT EXISTS(SELECT 1 FROM users WHERE username = %s);",
                (email_or_username,),
            )
            username_exists = cursor.fetchone()[0]
    finally:
        cursor.close()
        connection.close()

    if is_email:
        if not email_exists:
            return {"error": "invalid email or password"}
    else:
        if not username_exists:
            return {"error": "invalid username or password"}

    plain_password = user.password

    connection = get_connection()
    if connection == None:
        return {"error": "Database connection failed"}

    try:
        cursor = connection.cursor()
        if is_email:
            if email_exists:
                cursor.execute(
                    "SELECT id, password_hash FROM users WHERE email = %s;",
                    (email_or_username,),
                )
        else:
            if username_exists:
                cursor.execute(
                    "SELECT id, password_hash FROM users WHERE username = %s;",
                    (email_or_username,),
                )
        data = cursor.fetchone()
        user_ID = data[0]
        hash_password = data[1]
    finally:
        cursor.close()
        connection.close()

    password_correct = checkPassword(plain_password, hash_password)

    if not password_correct:
        if is_email:
            return {"error": "invalid email or password"}
        else:
            return {"error": "invalid username or password"}

    expire_time = datetime.now(timezone.utc) + timedelta(
        minutes=ACCESS_TOKEN_EXPIRE_MINUTES
    )
    payload = {
        "user_id": user_ID,
        "exp": expire_time,
    }

    token = jwt.encode(payload, SECRET_KEY, algorithm=ALGORITHM)

    return {
        "message": "login success",
        "access_token": token,
        "token_type": "bearer",
    }
