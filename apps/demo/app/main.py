from fastapi import FastAPI
from pydantic import BaseModel
from datetime import datetime
import socket, os

app = FastAPI(title="Pocket Demo")

class Echo(BaseModel):
    message: str

@app.get("/")
def root():
    return {
        "msg": "Hello from FastAPI 👋",
        "host": socket.gethostname(),
        "time": datetime.utcnow().isoformat() + "Z",
        "version": os.getenv("APP_VERSION", "dev")
    }

@app.post("/echo")
def echo(data: Echo):
    return {"echo": data.message}
