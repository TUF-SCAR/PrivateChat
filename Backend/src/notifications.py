from pathlib import Path
import firebase_admin
from firebase_admin import credentials, messaging

from src.database import get_connection

firebase_app_ready = False


def setup_firebase():
    global firebase_app_ready

    if firebase_app_ready:
        return True

    if len(firebase_admin._apps) > 0:
        firebase_app_ready = True
        return True

    service_account_path = (
        Path(__file__).resolve().parent / "firebase-service-account.json"
    )

    if not service_account_path.exists():
        print("Firebase service account file not found:", service_account_path)
        return False

    try:
        cred = credentials.Certificate(str(service_account_path))
        firebase_admin.initialize_app(cred)
        firebase_app_ready = True
        return True
    except Exception as error:
        print("Firebase setup failed:", error)
        return False


def make_notification_body(message_type, message_text):
    if message_type == "gif":
        return "sent a GIF"

    text = message_text.strip() if message_text else ""

    if text == "":
        return "sent a message"

    if len(text) > 80:
        return text[:80] + "..."

    return text


def send_chat_notification(
    chat_id: int,
    sender_id: int,
    message_id: int,
    message_text: str,
    message_type: str,
):
    firebase_ready = setup_firebase()
    if not firebase_ready:
        return {"sent": 0, "failed": 0, "reason": "firebase not ready"}

    connection = get_connection()
    if connection == None:
        return {"sent": 0, "failed": 0, "reason": "database failed"}

    try:
        cursor = connection.cursor()

        cursor.execute(
            "SELECT username FROM users WHERE id = %s;",
            (sender_id,),
        )
        sender_row = cursor.fetchone()
        if sender_row == None:
            return {"sent": 0, "failed": 0, "reason": "sender not found"}

        sender_username = sender_row[0]

        cursor.execute(
            "SELECT is_group, name FROM chats WHERE id = %s;",
            (chat_id,),
        )
        chat_row = cursor.fetchone()
        if chat_row == None:
            return {"sent": 0, "failed": 0, "reason": "chat not found"}

        is_group = chat_row[0]
        chat_name = chat_row[1]

        cursor.execute(
            "SELECT user_devices.device_token FROM user_devices JOIN chat_members ON user_devices.user_id = chat_members.user_id WHERE chat_members.chat_id = %s AND chat_members.user_id != %s;",
            (chat_id, sender_id),
        )
        rows = cursor.fetchall()

    finally:
        cursor.close()
        connection.close()

    device_tokens = []

    for row in rows:
        device_token = row[0]
        if device_token != None and device_token != "":
            device_tokens.append(device_token)

    if len(device_tokens) == 0:
        return {"sent": 0, "failed": 0, "reason": "no device tokens"}

    body = make_notification_body(message_type, message_text)

    if is_group:
        title = chat_name if chat_name else "Group"
        body = sender_username + ": " + body
    else:
        title = sender_username

    sent_count = 0
    failed_count = 0

    for device_token in device_tokens:
        try:
            firebase_message = messaging.Message(
                notification=messaging.Notification(
                    title=title,
                    body=body,
                ),
                data={
                    "type": "message",
                    "chat_id": str(chat_id),
                    "message_id": str(message_id),
                    "sender_id": str(sender_id),
                    "message_type": str(message_type),
                },
                token=device_token,
            )

            messaging.send(firebase_message)
            sent_count += 1

        except Exception as error:
            print("Notification failed:", error)
            failed_count += 1

    return {
        "sent": sent_count,
        "failed": failed_count,
    }
