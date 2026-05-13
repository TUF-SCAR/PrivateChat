# PrivateChat Backend

This file explains the backend routes used in **PrivateChat**.

Important common rule:

> Private routes need an **authentication token** in the request header.
>
> Header used:
>
> ```txt
> Authorization: Bearer YOUR_TOKEN_HERE
> ```
>
> Read more: [Authorization header](https://en.wikipedia.org/wiki/HTTP_header), [JSON Web Token](https://en.wikipedia.org/wiki/JSON_Web_Token)

---

## Register

> ## `/register` Post Request
>
> This is used to **register a new account**.
>
> It takes **username, email, password** as arguments.
>
> The backend checks:
>
> - **username is valid**
> - **email is valid**
> - **password is valid**
> - **username is not already used**
> - **email is not already used**
>
> Then it takes the password, [hashes](https://en.wikipedia.org/wiki/Cryptographic_hash_function) it, and stores **username, email, password_hash** in the database.
>
> Important: The backend stores **hashed password**, not the real password.
>
> ```json
> {
>   "username": "scar",
>   "email": "scar@example.com",
>   "password": "password123"
> }
> ```
>
> Success response:
>
> ```json
> {
>   "message": "registration success"
> }
> ```

---

## Login

> ## `/login` Post Request
>
> This is used to **login to an existing account** and get an **authentication token**.
>
> It takes **email_or_username** and **password** as arguments.
>
> The backend checks if the user is logging in using **email** or **username**.
>
> Then it compares the entered password with the stored **password_hash** using password verification.
>
> Read more: [Password hashing](https://en.wikipedia.org/wiki/Password_hashing), [JSON Web Token](https://en.wikipedia.org/wiki/JSON_Web_Token)
>
> ```json
> {
>   "email_or_username": "scar",
>   "password": "password123"
> }
> ```
>
> Success response:
>
> ```json
> {
>   "message": "login success",
>   "access_token": "token_here",
>   "token_type": "bearer"
> }
> ```
>
> Important: This token is used in **private_routes** for authentication.

---

## Me

> ## `/me` Get Request
>
> This is used to **check if the token is valid** and return the logged-in user's details.
>
> It takes the **authentication token** from the request header.
>
> Then it checks the token and returns the user's **id** and **username**.
>
> Success response:
>
> ```json
> {
>   "message": "token valid",
>   "id": 1,
>   "username": "scar"
> }
> ```

---

## Users

> ## `/users/search` Get Request
>
> This is used to **search users by username**.
>
> It takes **username** as a query parameter and also takes the **authentication token** from the request header.
>
> It returns up to **10 users** matching the search text.
>
> Important: It does **not return the current logged-in user** in the search result.
>
> Example request:
>
> ```txt
> /users/search?username=pa
> ```
>
> Example response:
>
> ```json
> {
>   "message": "users fetched",
>   "users": [
>     {
>       "id": 2,
>       "username": "pappu"
>     }
>   ]
> }
> ```

---

## Chat

> ## `/chats` Post Request
>
> This is used to **make a private chat**.
>
> It takes **other_user_id** as an argument and also takes the **authentication token** from the request header.
>
> The backend checks:
>
> - **token is valid**
> - **other user exists**
> - **current user is not trying to chat with themselves**
> - **same private chat does not already exist**
>
> If the private chat already exists, it returns the existing **chat_id**.
>
> ```json
> {
>   "other_user_id": 4
> }
> ```
>
> Success response:
>
> ```json
> {
>   "message": "successfully created chat",
>   "chat_id": 1
> }
> ```

> ## `/chats` Get Request
>
> This is used to get all **private chats** that exist for the logged-in user.
>
> It takes the **authentication token** from the request header.
>
> Important: This route now returns only **private chats**, not group chats.
>
> Group chats are fetched using `/groups`.
>
> ```py
> # Example of what this request returns
> chats = [
>   {
>       "chat_id": 1,
>       "is_group": False,
>       "chat_name": None,
>       "other_user_id": 4,
>       "other_username": "tappu",
>   },
>   {
>       "chat_id": 3,
>       "is_group": False,
>       "chat_name": None,
>       "other_user_id": 2,
>       "other_username": "pappu",
>   },
> ]
> ```

---

## Messages

> ## `/messages` Post Request
>
> This is used to **send a message** to a chat.
>
> It takes **chat_id** and **message_text** as arguments and also takes the **authentication token** from the request header.
>
> The backend checks:
>
> - **message is not empty**
> - **token is valid**
> - **chat exists**
> - **current user is a member of the chat**
>
> Then it stores the message and returns the **message_id**.
>
> ```json
> {
>   "chat_id": 1,
>   "message_text": "Hello bro"
> }
> ```
>
> Success response:
>
> ```json
> {
>   "message": "message sent",
>   "message_id": 10
> }
> ```

> ## `/messages/{chat_id}` Get Request
>
> This is used to **read messages in a chat**.
>
> It takes **chat_id** from the URL and takes the **authentication token** from the request header.
>
> The backend checks if the current user is a member of the chat.
>
> Then it returns all messages in that chat.
>
> Important: If a message is **soft deleted**, the original text is hidden and the API returns **"this message was deleted"** instead.
>
> Read more: [Soft deletion](https://en.wikipedia.org/wiki/Deletion#Soft_deletion)
>
> ```py
> # Example of what this request returns
> messages = [
>   {
>       "message_id": 1,
>       "sender_id": 1,
>       "sender_name": "tappu",
>       "message_text": "Hello, how are you??",
>       "is_deleted": False,
>       "created_at": "2026-05-09 10:00:00"
>   },
>   {
>       "message_id": 2,
>       "sender_id": 2,
>       "sender_name": "pappu",
>       "message_text": "this message was deleted",
>       "is_deleted": True,
>       "created_at": "2026-05-09 10:02:00"
>   },
> ]
> ```

> ## `/messages/{message_id}` Delete Request
>
> This is used to **soft delete a message**.
>
> It takes **message_id** from the URL and takes the **authentication token** from the request header.
>
> The backend checks:
>
> - **token is valid**
> - **message exists**
> - **current user is the sender of the message**
>
> Then it changes **is_deleted** to **True**.
>
> Important: The message row is still stored in the database, but the message text is hidden when reading messages.
>
> Success response:
>
> ```json
> {
>   "message": "This message was deleted"
> }
> ```

---

## Groups

> ## `/groups` Post Request
>
> This is used to **create a group chat**.
>
> It takes **name** and **member_ids** as arguments and also takes the **authentication token** from the request header.
>
> The backend checks:
>
> - **group name is valid**
> - **group name is not more than 100 characters**
> - **at least one other member is added**
> - **all member ids exist**
>
> Then it creates a group in **chats** with **is_group = True**.
>
> The current user is added as **admin**.
>
> Other users are added as **member**.
>
> Read more: [Role-based access control](https://en.wikipedia.org/wiki/Role-based_access_control)
>
> ```json
> {
>   "name": "PrivateChat Team",
>   "member_ids": [2, 3, 4]
> }
> ```
>
> Success response:
>
> ```json
> {
>   "message": "successfully created group",
>   "chat_id": 5
> }
> ```

> ## `/groups` Get Request
>
> This is used to **fetch all groups** where the current user is a member.
>
> It takes the **authentication token** from the request header.
>
> It returns the group id, group name, current user's role, and created time.
>
> Example response:
>
> ```json
> {
>   "message": "groups fetched",
>   "groups": [
>     {
>       "chat_id": 5,
>       "group_name": "PrivateChat Team",
>       "my_role": "admin",
>       "created_at": "2026-05-14 10:30:00"
>     }
>   ]
> }
> ```

> ## `/groups/{chat_id}/members` Post Request
>
> This is used to **add a member to a group**.
>
> It takes **chat_id** from the URL, **user_id** from the body, and the **authentication token** from the request header.
>
> Only **admin** can add members.
>
> The backend checks:
>
> - **group exists**
> - **current user is admin**
> - **target user exists**
> - **target user is not already a member**
>
> ```json
> {
>   "user_id": 6
> }
> ```
>
> Success response:
>
> ```json
> {
>   "message": "member added"
> }
> ```

> ## `/groups/{chat_id}/members/{user_id}` Delete Request
>
> This is used to **remove a member from a group**.
>
> It takes **chat_id** and **user_id** from the URL and takes the **authentication token** from the request header.
>
> Only **admin** can remove members.
>
> The backend checks:
>
> - **group exists**
> - **current user is admin**
> - **target user is a member**
> - **admin is not removing themselves**
> - **target user is not the last admin**
>
> Important: Admin cannot use this route to remove themselves. For that, use `/groups/{chat_id}/leave`.
>
> Success response:
>
> ```json
> {
>   "message": "member removed"
> }
> ```

> ## `/groups/{chat_id}/leave` Delete Request
>
> This is used when the **current logged-in user leaves a group**.
>
> It takes **chat_id** from the URL and takes the **authentication token** from the request header.
>
> The backend checks:
>
> - **group exists**
> - **current user is a member**
> - **if current user is the only admin**
> - **how many members are in the group**
>
> Rules:
>
> - If the user is the **last member**, the whole group is deleted.
> - If the user is the **only admin**, they cannot leave until another admin exists.
> - Otherwise, the user is removed from **chat_members**.
>
> Success response:
>
> ```json
> {
>   "message": "successfully left group"
> }
> ```
>
> If last member leaves:
>
> ```json
> {
>   "message": "group deleted because you were the last member"
> }
> ```

> ## `/groups/{chat_id}/members/{user_id}/role` Patch Request
>
> This is used to **change a group member's role**.
>
> It takes **chat_id** and **user_id** from the URL, **role** from the body, and the **authentication token** from the request header.
>
> Only **admin** can change roles.
>
> Allowed roles:
>
> - **admin**
> - **member**
>
> The backend checks:
>
> - **role is valid**
> - **group exists**
> - **current user is admin**
> - **target user is a member**
> - **last admin is not being changed to member**
>
> Read more: [Role-based access control](https://en.wikipedia.org/wiki/Role-based_access_control)
>
> ```json
> {
>   "role": "admin"
> }
> ```
>
> Success response:
>
> ```json
> {
>   "message": "role updated"
> }
> ```
>
> If the role is already set:
>
> ```json
> {
>   "message": "role already set"
> }
> ```

> ## `/groups/{chat_id}/members` Get Request
>
> This is used to **fetch all members of a group**.
>
> It takes **chat_id** from the URL and takes the **authentication token** from the request header.
>
> Any group member can view the group member list.
>
> The backend checks:
>
> - **group exists**
> - **current user is a member**
>
> Example response:
>
> ```json
> {
>   "message": "members fetched",
>   "members": [
>     {
>       "user_id": 1,
>       "username": "scar",
>       "role": "admin",
>       "joined_at": "2026-05-14 10:30:00"
>     }
>   ]
> }
> ```

> ## `/groups/{chat_id}` Patch Request
>
> This is used to **rename a group**.
>
> It takes **chat_id** from the URL, **name** from the body, and the **authentication token** from the request header.
>
> Only **admin** can rename a group.
>
> The backend checks:
>
> - **new group name is valid**
> - **new group name is not more than 100 characters**
> - **group exists**
> - **current user is admin**
>
> ```json
> {
>   "name": "New Group Name"
> }
> ```
>
> Success response:
>
> ```json
> {
>   "message": "group renamed"
> }
> ```

> ## `/groups/{chat_id}` Delete Request
>
> This is used to **delete a whole group**.
>
> It takes **chat_id** from the URL and takes the **authentication token** from the request header.
>
> Only **admin** can delete a group.
>
> The backend checks:
>
> - **group exists**
> - **current user is admin**
>
> Important: Deleting a group deletes the group from **chats**. Because the database uses **ON DELETE CASCADE**, related **chat_members** and **messages** are also deleted automatically.
>
> Read more: [Foreign key](https://en.wikipedia.org/wiki/Foreign_key), [Referential integrity](https://en.wikipedia.org/wiki/Referential_integrity)
>
> Success response:
>
> ```json
> {
>   "message": "group deleted"
> }
> ```

---

## Helper Files

> ## `auth.py`
>
> This file handles **token creation** and **token checking**.
>
> `make_token()` creates a [JWT](https://en.wikipedia.org/wiki/JSON_Web_Token).
>
> `check_token()` checks if the token is valid, expired, or invalid.
>
> It also checks if the user still exists in the database.

> ## `database.py`
>
> This file handles the PostgreSQL database connection.
>
> It uses values from the `.env` file like **DATABASE_NAME, DATABASE_USER, DATABASE_PASSWORD, DATABASE_HOST, DATABASE_PORT**.
>
> Read more: [PostgreSQL](https://en.wikipedia.org/wiki/PostgreSQL), [Environment variable](https://en.wikipedia.org/wiki/Environment_variable)

> ## `security.py`
>
> This file contains helper functions for checking **username** and **email** format.

> ## `util.py`
>
> This file contains password helper functions.
>
> `hashPassword()` hashes the password.
>
> `checkPassword()` checks a plain password against the stored password hash.
>
> Read more: [bcrypt](https://en.wikipedia.org/wiki/Bcrypt)

---

## Current Important Notes

> PrivateChat currently supports:
>
> - **User registration**
> - **Login with email or username**
> - **Token-based authentication**
> - **Private chats**
> - **Sending messages**
> - **Reading messages**
> - **Soft deleting messages**
> - **Searching users**
> - **Creating groups**
> - **Adding/removing group members**
> - **Leaving groups**
> - **Changing member roles**
> - **Fetching group members**
> - **Fetching all groups**
> - **Renaming groups**
> - **Deleting groups**
>
> Features planned for later:
>
> - **Edit message within 5 minutes**
> - **Temporary hard delete after soft delete**
> - **Voice messages**
> - **File sharing**
> - **End-to-end encryption**
>
> Read more: [End-to-end encryption](https://en.wikipedia.org/wiki/End-to-end_encryption), [File sharing](https://en.wikipedia.org/wiki/File_sharing)
