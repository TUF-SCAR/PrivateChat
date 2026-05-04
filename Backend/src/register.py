from fastapi import FastAPI
from pydantic import BaseModel
from src.util import hashPassword
from src.database import get_connection
from src.security import check_username_char, check_email


class Registration(BaseModel):
    username: str
    email: str
    password: str


app = FastAPI()


@app.post("/register")
def registration(user: Registration):
    username = user.username.strip()
    if username == "":
        return {"error": "username invalid"}
    if len(username) < 3:
        return {"error": "username invalid"}
    if len(username) > 25:
        return {"error": "username invalid"}
    if not check_username_char(username):
        return {"error": "username invalid"}

    email = user.email.strip().lower()
    if not check_email(email):
        return {"error": "email invalid"}

    password = user.password
    if password == "":
        return {"error": "password invalid"}
    if " " in password:
        return {"error": "password invalid"}
    if len(password) < 8:
        return {"error": "password invalid"}
    if len(password.encode("utf-8")) > 72:
        return {"error": "password too long"}

    hashed_password = hashPassword(password)

    try:
        connection = get_connection()
        if connection == None:
            return {"error": "Database connection failed"}
        cursor = connection.cursor()
        cursor.execute(
            "SELECT EXISTS(SELECT 1 FROM users WHERE username = %s);", (username,)
        )
        username_unique = cursor.fetchone()[0]
    finally:
        cursor.close()
        connection.close()

    try:
        connection = get_connection()
        if connection == None:
            return {"error": "Database connection failed"}
        cursor = connection.cursor()
        cursor.execute("SELECT EXISTS(SELECT 1 FROM users WHERE email = %s);", (email,))
        email_unique = cursor.fetchone()[0]
    finally:
        cursor.close()
        connection.close()

    if username_unique:
        return {"error": "username already exists"}
    if email_unique:
        return {"error": "email already exists"}

    try:
        connection = get_connection()
        if connection == None:
            return {"error": "Database connection failed"}
        cursor = connection.cursor()
        cursor.execute(
            "INSERT INTO users (username, email, password_hash) VALUES (%s, %s, %s);",
            (username, email, hashed_password),
        )
        connection.commit()
    finally:
        cursor.close()
        connection.close()

    return {"message": "registration success"}
