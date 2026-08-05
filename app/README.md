# App Development Guide

## Run Locally

```
cd app/src
pyton -m venv venv
source ./venv/bin/activate # To isolate the environment

pip install -r requirements.txt
uvicorn main:app --reload
```

Available endpoints:

- `/` → Hello World
- `/health` → Health check
- `/metrics` → Prometheus metrics
