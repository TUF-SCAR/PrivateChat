# PrivateChat Backend

## Register

> ## `/register` Post Request
>
> This is used to register accounts. It takes **username, email, password,** as arguments. and performs checks on username and email. then it takes the password and [hashes](https://en.wikipedia.org/wiki/Cryptographic_hash_function) it and **stores username, email, hashed_password, in database.**

## Login

> ## `/login` Post Request
>
> This is used to login to existing account and get a authentication token. It takes **username or email and password** as arguments. then it performs checks on username or email and compares the password to the one stored in database (hashed_password). then gives the user a token of authentication. which will be used in private_routes for authentication.

## Me

> ## `/me` Get Request
>
> This is used to check the token of user and return their id and name. It takes authentication token from request header. and check the token and returns the user's id and username.

## Chat

> ## `/chats` Post Request
>
> This is used to make a chat. It takes the other user id with who the current user wants to make a chat with as arguments and also takes authentication token from request header. and checks token and if a chat with same user exists and then creates the chat and returns the chat_id.

> ## `/chats` Get Request
>
> This is used to get all chats that exists for a user. It takes authentication token from request header. and checks the token then returns all chats connected to that user as a list of items.
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

## Messages

> ## `/messages` Post Request
>
> This is used to send a message to a chat. It takes chat_id and message_text as arguments and also takes authentication token from request header. after checking each thing it makes a messages and returns the message_id.

> ## `/messages/{chat_id}` Get Request
>
> This is used to read messages in a chat. It takes chat_id from url and takes authentication token from request header. after checks are done returns all messages in the chat as a list of messages.
>
> ```py
> # Example of what this request returns
> chats = [
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
>       "message_text": "Heyy, I am fine how are you???",
>       "is_deleted": False,
>       "created_at": "2029-05-09 10:00:00"
>   },
> ]
> ```

> ## `/messages/{message_id}` Delete Request
>
> This is used to soft delete a message. It takes message_id from url and takes authentication token from request header. after checks are done it changes the is_deleted to True. The message is still stored in the database.
