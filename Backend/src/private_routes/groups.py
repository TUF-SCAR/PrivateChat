from fastapi import APIRouter, Header
from pydantic import BaseModel
from src.auth import check_token
from src.database import get_connection


class GroupName(BaseModel):
    name: str


class UserRole(BaseModel):
    role: str


class Users(BaseModel):
    user_id: int


class Groups(BaseModel):
    name: str
    member_ids: list[int]


router = APIRouter()


@router.post("/groups")
def make_group(data: Groups, authorization: str = Header(None, alias="Authorization")):
    token = authorization

    token_exists = check_token(token)
    status = token_exists["status"]
    if status == 2:
        return {"error": "Database connection failed"}
    if status == 1:
        return {"error": "token invalid or expired"}
    if status == 0:
        current_user_id = token_exists["id"]

    group_name = data.name.strip()
    if group_name == "":
        return {"error": "group name invalid"}
    if len(group_name) > 100:
        return {"error": "group name invalid"}

    group_members = list(set(data.member_ids))
    if current_user_id in group_members:
        group_members.remove(current_user_id)
    if group_members == []:
        return {"error": "need atleast one member"}

    connection = get_connection()
    if connection == None:
        return {"error": "Database connection failed"}

    users_not_found = []

    try:
        cursor = connection.cursor()
        for id in group_members:
            cursor.execute("SELECT EXISTS(SELECT 1 FROM users WHERE id = %s);", (id,))
            if not cursor.fetchone()[0]:
                users_not_found.append(id)
    finally:
        cursor.close()
        connection.close()

    if users_not_found != []:
        return {
            "error": "some users not found",
            "incorrect_user_ids": users_not_found,
        }

    connection = get_connection()
    if connection == None:
        return {"error": "Database connection failed"}

    try:
        cursor = connection.cursor()
        cursor.execute(
            "INSERT INTO chats (is_group, name) VALUES (TRUE, %s) RETURNING id;",
            (group_name,),
        )
        row = cursor.fetchone()
        if row == None:
            return {"error": "Database error"}
        chat_id = row[0]
        cursor.execute(
            "INSERT INTO chat_members (chat_id, user_id, role) VALUES (%s, %s, 'admin');",
            (chat_id, current_user_id),
        )
        for id in group_members:
            cursor.execute(
                "INSERT INTO chat_members (chat_id, user_id, role) VALUES (%s, %s, 'member');",
                (chat_id, id),
            )
        connection.commit()
    finally:
        cursor.close()
        connection.close()

    return {
        "message": "successfully created group",
        "chat_id": chat_id,
    }


@router.post("/groups/{chat_id}/members")
def add_members(
    chat_id: int, users: Users, authorization: str = Header(None, alias="Authorization")
):
    token = authorization
    other_user_id = users.user_id

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
            "SELECT EXISTS(SELECT 1 FROM chats WHERE id = %s AND is_group = TRUE);",
            (chat_id,),
        )
        chat_exists = cursor.fetchone()[0]
        if not chat_exists:
            return {"error": "chat does not exist"}

        cursor.execute(
            "SELECT EXISTS(SELECT 1 FROM chat_members WHERE chat_id = %s AND user_id = %s AND role = 'admin');",
            (chat_id, current_user_id),
        )
        is_user_admin = cursor.fetchone()[0]
        if not is_user_admin:
            return {"error": "access denied"}

        cursor.execute(
            "SELECT EXISTS(SELECT 1 FROM users WHERE id = %s);", (other_user_id,)
        )
        other_user_exists = cursor.fetchone()[0]
        if not other_user_exists:
            return {"error": "user does not exist"}

        cursor.execute(
            "SELECT EXISTS(SELECT 1 FROM chat_members WHERE chat_id = %s AND user_id = %s);",
            (chat_id, other_user_id),
        )
        is_member = cursor.fetchone()[0]
        if is_member:
            return {"error": "user already a member"}

        cursor.execute(
            "INSERT INTO chat_members (chat_id, user_id, role) VALUES (%s, %s, 'member');",
            (chat_id, other_user_id),
        )

        connection.commit()
    finally:
        cursor.close()
        connection.close()

    return {"message": "member added"}


@router.delete("/groups/{chat_id}/members/{user_id}")
def delete_member(
    chat_id: int, user_id: int, authorization: str = Header(None, alias="Authorization")
):
    token = authorization
    other_user_id = user_id

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
            "SELECT EXISTS(SELECT 1 FROM chats WHERE id = %s AND is_group = TRUE);",
            (chat_id,),
        )
        chat_exists = cursor.fetchone()[0]
        if not chat_exists:
            return {"error": "chat does not exist"}

        cursor.execute(
            "SELECT EXISTS(SELECT 1 FROM chat_members WHERE chat_id = %s AND user_id = %s AND role = 'admin');",
            (chat_id, current_user_id),
        )
        is_user_admin = cursor.fetchone()[0]
        if not is_user_admin:
            return {"error": "access denied"}

        cursor.execute(
            "SELECT EXISTS(SELECT 1 FROM chat_members WHERE chat_id = %s AND user_id = %s);",
            (chat_id, other_user_id),
        )
        is_member = cursor.fetchone()[0]
        if not is_member:
            return {"error": "not a member"}

        if current_user_id == other_user_id:
            return {"error": "cannot remove yourself"}

        cursor.execute(
            "SELECT EXISTS(SELECT 1 FROM chat_members WHERE chat_id = %s AND user_id = %s AND role = 'admin');",
            (chat_id, other_user_id),
        )
        is_target_admin = cursor.fetchone()[0]

        cursor.execute(
            "SELECT COUNT(*) FROM chat_members WHERE chat_id = %s AND role = 'admin';",
            (chat_id,),
        )
        admin_count = cursor.fetchone()[0]

        if is_target_admin and admin_count == 1:
            return {"error": "cannot remove last admin"}

        cursor.execute(
            "DELETE FROM chat_members WHERE chat_id = %s AND user_id = %s;",
            (chat_id, other_user_id),
        )

        connection.commit()
    finally:
        cursor.close()
        connection.close()

    return {"message": "member removed"}


@router.delete("/groups/{chat_id}/leave")
def leave_group(chat_id: int, authorization: str = Header(None, alias="Authorization")):
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
            "SELECT EXISTS(SELECT 1 FROM chats WHERE id = %s AND is_group = TRUE);",
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
            return {"error": "not a member"}

        cursor.execute(
            "SELECT EXISTS(SELECT 1 FROM chat_members WHERE chat_id = %s AND user_id = %s AND role = 'admin');",
            (chat_id, current_user_id),
        )
        is_user_admin = cursor.fetchone()[0]

        cursor.execute(
            "SELECT COUNT(*) FROM chat_members WHERE chat_id = %s AND role = 'admin';",
            (chat_id,),
        )
        admin_count = cursor.fetchone()[0]

        cursor.execute(
            "SELECT COUNT(*) FROM chat_members WHERE chat_id = %s;", (chat_id,)
        )
        group_members = cursor.fetchone()[0]

        if group_members == 1:
            cursor.execute("DELETE FROM chats WHERE id = %s;", (chat_id,))
            connection.commit()
            return {"message": "group deleted because you were the last member"}
        elif is_user_admin and admin_count == 1:
            return {"error": "admin cannot leave group before assigning another admin"}
        else:
            cursor.execute(
                "DELETE FROM chat_members WHERE chat_id = %s AND user_id = %s;",
                (chat_id, current_user_id),
            )
            connection.commit()
    finally:
        cursor.close()
        connection.close()

    return {"message": "successfully left group"}


@router.patch("/groups/{chat_id}/members/{user_id}/role")
def change_role(
    data: UserRole,
    chat_id: int,
    user_id: int,
    authorization: str = Header(None, alias="Authorization"),
):
    new_role = data.role.strip().lower()
    target_user_id = user_id
    token = authorization

    token_exists = check_token(token)
    status = token_exists["status"]
    if status == 2:
        return {"error": "Database connection failed"}
    if status == 1:
        return {"error": "token invalid or expired"}
    if status == 0:
        current_user_id = token_exists["id"]

    if new_role not in ["admin", "member"]:
        return {"error": "invalid role"}

    connection = get_connection()
    if connection == None:
        return {"error": "Database connection failed"}
    try:
        cursor = connection.cursor()

        cursor.execute(
            "SELECT EXISTS(SELECT 1 FROM chats WHERE id = %s AND is_group = TRUE);",
            (chat_id,),
        )
        chat_exists = cursor.fetchone()[0]
        if not chat_exists:
            return {"error": "chat does not exist"}

        cursor.execute(
            "SELECT EXISTS(SELECT 1 FROM chat_members WHERE chat_id = %s AND user_id = %s AND role = 'admin');",
            (chat_id, current_user_id),
        )
        is_user_admin = cursor.fetchone()[0]
        if not is_user_admin:
            return {"error": "access denied"}

        cursor.execute(
            "SELECT role FROM chat_members WHERE chat_id = %s AND user_id = %s;",
            (chat_id, target_user_id),
        )
        row = cursor.fetchone()
        if row == None:
            return {"error": "not a member"}
        target_user_role = row[0]

        if new_role == target_user_role:
            return {"message": "role already set"}

        if target_user_role == "admin" and new_role == "member":
            cursor.execute(
                "SELECT COUNT(*) FROM chat_members WHERE chat_id = %s AND role = 'admin';",
                (chat_id,),
            )
            admin_count = cursor.fetchone()[0]
            if admin_count == 1:
                return {"error": "cannot remove the last admin"}

        cursor.execute(
            "UPDATE chat_members SET role = %s WHERE chat_id = %s AND user_id = %s;",
            (new_role, chat_id, target_user_id),
        )
        connection.commit()
    finally:
        cursor.close()
        connection.close()

    return {"message": "role updated"}


@router.get("/groups/{chat_id}/members")
def all_members(chat_id: int, authorization: str = Header(None, alias="Authorization")):
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

    members = []

    try:
        cursor = connection.cursor()

        cursor.execute(
            "SELECT EXISTS(SELECT 1 FROM chats WHERE id = %s AND is_group = TRUE);",
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
            "SELECT users.id, users.username, chat_members.role, chat_members.joined_at FROM chat_members JOIN users ON chat_members.user_id = users.id WHERE chat_members.chat_id = %s ORDER BY chat_members.joined_at ASC;",
            (chat_id,),
        )
        rows = cursor.fetchall()
    finally:
        cursor.close()
        connection.close()

    for row in rows:
        member = {
            "user_id": row[0],
            "username": row[1],
            "role": row[2],
            "joined_at": str(row[3]),
        }
        members.append(member)

    return {
        "message": "members fetched",
        "members": members,
    }


@router.get("/groups")
def all_groups(authorization: str = Header(None, alias="Authorization")):
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

    groups = []

    try:
        cursor = connection.cursor()
        cursor.execute(
            "SELECT chats.id, chats.name, chat_members.role, chats.created_at FROM chats JOIN chat_members ON chats.id = chat_members.chat_id WHERE chats.is_group = TRUE AND chat_members.user_id = %s ORDER BY chats.created_at DESC;",
            (current_user_id,),
        )
        rows = cursor.fetchall()
    finally:
        cursor.close()
        connection.close()

    for row in rows:
        group = {
            "chat_id": row[0],
            "group_name": row[1],
            "my_role": row[2],
            "created_at": str(row[3]),
        }
        groups.append(group)

    return {
        "message": "groups fetched",
        "groups": groups,
    }


@router.patch("/groups/{chat_id}")
def change_name(
    chat_id: int,
    data: GroupName,
    authorization: str = Header(None, alias="Authorization"),
):
    new_group_name = data.name.strip()
    token = authorization

    token_exists = check_token(token)
    status = token_exists["status"]
    if status == 2:
        return {"error": "Database connection failed"}
    if status == 1:
        return {"error": "token invalid or expired"}
    if status == 0:
        current_user_id = token_exists["id"]

    if new_group_name == "" or len(new_group_name) > 100:
        return {"error": "invalid group name"}

    connection = get_connection()
    if connection == None:
        return {"error": "Database connection failed"}

    try:
        cursor = connection.cursor()

        cursor.execute(
            "SELECT EXISTS(SELECT 1 FROM chats WHERE id = %s AND is_group = TRUE);",
            (chat_id,),
        )
        chat_exists = cursor.fetchone()[0]
        if not chat_exists:
            return {"error": "chat does not exist"}

        cursor.execute(
            "SELECT EXISTS(SELECT 1 FROM chat_members WHERE chat_id = %s AND user_id = %s AND role = 'admin');",
            (chat_id, current_user_id),
        )
        is_user_admin = cursor.fetchone()[0]
        if not is_user_admin:
            return {"error": "access denied"}

        cursor.execute(
            "UPDATE chats SET name = %s WHERE id = %s;", (new_group_name, chat_id)
        )
        connection.commit()
    finally:
        cursor.close()
        connection.close()

    return {"message": "group renamed"}


@router.delete("/groups/{chat_id}")
def delete_group(
    chat_id: int, authorization: str = Header(None, alias="Authorization")
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

    connection = get_connection()
    if connection == None:
        return {"error": "Database connection failed"}

    try:
        cursor = connection.cursor()

        cursor.execute(
            "SELECT EXISTS(SELECT 1 FROM chats WHERE id = %s AND is_group = TRUE);",
            (chat_id,),
        )
        chat_exists = cursor.fetchone()[0]
        if not chat_exists:
            return {"error": "chat does not exist"}

        cursor.execute(
            "SELECT EXISTS(SELECT 1 FROM chat_members WHERE chat_id = %s AND user_id = %s AND role = 'admin');",
            (chat_id, current_user_id),
        )
        is_user_admin = cursor.fetchone()[0]
        if not is_user_admin:
            return {"error": "access denied"}

        cursor.execute("DELETE FROM chats WHERE id = %s;", (chat_id,))
        connection.commit()
    finally:
        cursor.close()
        connection.close()

    return {"message": "group deleted"}
