import uvicorn
from fastapi import FastAPI
from src.private_routes.me import router as me_router
from src.public_routes.login import router as login_router
from src.private_routes.chat import router as chat_router
from src.public_routes.register import router as register_router

app = FastAPI()
app.include_router(register_router)
app.include_router(login_router)
app.include_router(me_router)
app.include_router(chat_router)

if __name__ == "__main__":
    uvicorn.run("main:app", host="0.0.0.0", port=8000, reload=True)
