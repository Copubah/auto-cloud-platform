from fastapi import FastAPI, HTTPException
from pydantic import BaseModel
import os
import uvicorn

app = FastAPI(title="Automated Cloud Platform API", version="1.0.0")

class HealthResponse(BaseModel):
    status: str
    version: str

@app.get("/", response_model=HealthResponse)
async def root():
    return {"status": "ok", "version": "1.0.0"}

@app.get("/health")
async def health_check():
    return {"status": "healthy"}

if __name__ == "__main__":
    uvicorn.run(app, host="0.0.0.0", port=8000)
