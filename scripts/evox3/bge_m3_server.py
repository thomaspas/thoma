#!/usr/bin/env python3
"""Minimal OpenAI-compatible embeddings server for BAAI/bge-m3 (LOCAL FULL)."""

from __future__ import annotations

import os
import time
import uuid
from typing import Any

import uvicorn
from fastapi import FastAPI, HTTPException
from pydantic import BaseModel

MODEL_ID = os.environ.get("EVOX3_EMBED_MODEL", "BAAI/bge-m3")
HOST = os.environ.get("EVOX3_BGE_HOST", "127.0.0.1")
PORT = int(os.environ.get("EVOX3_BGE_PORT", "8002"))
DEVICE = os.environ.get("EVOX3_BGE_DEVICE", "cpu")

app = FastAPI(title="EVO-X3 bge-m3 embeddings", version="1.0.0")
_model = None


def get_model():
    global _model
    if _model is None:
        from sentence_transformers import SentenceTransformer

        _model = SentenceTransformer(MODEL_ID, device=DEVICE)
    return _model


class EmbeddingRequest(BaseModel):
    input: Any
    model: str | None = None
    encoding_format: str | None = None
    dimensions: int | None = None


class ModelCard(BaseModel):
    id: str
    object: str = "model"
    owned_by: str = "local"


@app.get("/health")
def health() -> dict[str, str]:
    return {"status": "ok", "model": MODEL_ID}


@app.get("/v1/models")
def list_models() -> dict[str, Any]:
    return {"object": "list", "data": [ModelCard(id=MODEL_ID).model_dump()]}


@app.post("/v1/embeddings")
def create_embeddings(req: EmbeddingRequest) -> dict[str, Any]:
    if isinstance(req.input, str):
        texts = [req.input]
    elif isinstance(req.input, list):
        texts = [str(x) for x in req.input]
    else:
        raise HTTPException(status_code=400, detail="input must be string or list of strings")

    if not texts:
        raise HTTPException(status_code=400, detail="input is empty")

    model = get_model()
    vectors = model.encode(texts, normalize_embeddings=True)
    data = []
    for i, vec in enumerate(vectors):
        data.append(
            {
                "object": "embedding",
                "index": i,
                "embedding": vec.tolist(),
            }
        )
    dim = len(data[0]["embedding"]) if data else 0
    return {
        "object": "list",
        "data": data,
        "model": req.model or MODEL_ID,
        "usage": {
            "prompt_tokens": sum(len(t.split()) for t in texts),
            "total_tokens": sum(len(t.split()) for t in texts),
        },
        "id": f"emb-{uuid.uuid4().hex}",
        "created": int(time.time()),
        "dimensions": dim,
    }


def main() -> None:
    # Eager load so systemd health checks fail fast if HF download is still needed.
    get_model()
    uvicorn.run(app, host=HOST, port=PORT, log_level="info")


if __name__ == "__main__":
    main()
