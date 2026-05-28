from pydantic import BaseModel
from fastapi import APIRouter, Header
from src.auth import check_token
from src.database import get_connection


class Devices(BaseModel):
    device_token: str
    platform: str


router = APIRouter()


@router.post("/devices/register")
def register_device(
    data: Devices, authorization: str = Header(None, alias="Authorization")
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

    platform = data.platform.strip().lower()

    if platform not in ["android", "ios", "web"]:
        return {"error": "invalid platform"}

    device_token = data.device_token.strip()

    if device_token == "":
        return {"error": "invalid device token"}

    connection = get_connection()
    if connection == None:
        return {"error": "Database connection failed"}

    try:
        cursor = connection.cursor()
        cursor.execute(
            "INSERT INTO user_devices (user_id, device_token, platform) VALUES (%s, %s, %s) ON CONFLICT (device_token) DO UPDATE SET user_id = EXCLUDED.user_id, platform = EXCLUDED.platform, last_seen_at = CURRENT_TIMESTAMP;",
            (current_user_id, device_token, platform),
        )
        connection.commit()
    finally:
        cursor.close()
        connection.close()

    return {"message": "device registered"}
