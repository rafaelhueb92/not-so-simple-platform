from fastapi import FastAPI
from starlette.responses import PlainTextResponse
from prometheus_client import Counter, generate_latest, CONTENT_TYPE_LATEST, REGISTRY
import os

REQUEST_COUNT = Counter("hello_requests_total", "Total requests")

app = FastAPI()

@app.get("/", response_class=PlainTextResponse)
def read_root():
    REQUEST_COUNT.inc()
    return "Hello World"

@app.get("/health", response_class=PlainTextResponse)
def health_check():
    return "ok"

@app.get("/metrics")
def metrics():
    data = generate_latest(REGISTRY)
    return PlainTextResponse(content=data, media_type=CONTENT_TYPE_LATEST)
