import uvicorn
from fastapi import FastAPI
from pydantic import BaseModel
from src.register import router as register_router
from src.login import router as login_router

app = FastAPI()
app.include_router(register_router)
app.include_router(login_router)

if __name__ == "__main__":
    uvicorn.run("main:app", host="0.0.0.0", port=8000, reload=True)
