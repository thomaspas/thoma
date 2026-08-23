#!/usr/bin/env python3
"""Minimal OpenAI-compatible embeddings server for BAAI/bge-m3 (LOCAL FULL)."""

from __future__ import annotations

import logging
import os
import threading
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

log = logging.getLogger("bge_m3")
_model = None
_ready = False
_load_error: str | None = None

app = FastAPI(title="EVO-X3 bge-m3 embeddings", version="1.1.0")


def get_model():
    global _model
    if _model is None:
        from sentence_transformers import SentenceTransformer

        log.info("Loading SentenceTransformer(%s) on %s — may take several minutes", MODEL_ID, DEVICE)
        t0 = time.time()
        _model = SentenceTransformer(MODEL_ID, device=DEVICE)
        log.info("Model ready in %.1fs", time.time() - t0)
    return _model


def _load_model_bg() -> None:
    global _ready, _load_error
    try:
        get_model()
        _ready = True
        _load_error = None
    except Exception as exc:  # noqa: BLE001
        _load_error = str(exc)
        log.exception("Model load failed")


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
    if _load_error:
        raise HTTPException(status_code=503, detail=f"model_load_failed: {_load_error}")
    if not _ready:
        # 503 so curl -f fails until model is actually usable.
        raise HTTPException(status_code=503, detail="model_loading")
    return {"status": "ok", "model": MODEL_ID}


@app.get("/v1/models")
def list_models() -> dict[str, Any]:
    return {"object": "list", "data": [ModelCard(id=MODEL_ID).model_dump()]}


@app.post("/v1/embeddings")
def create_embeddings(req: EmbeddingRequest) -> dict[str, Any]:
    if _load_error:
        raise HTTPException(status_code=503, detail=f"model_load_failed: {_load_error}")
    if not _ready:
        raise HTTPException(status_code=503, detail="model_loading")
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
    logging.basicConfig(level=logging.INFO, format="%(asctime)s %(levelname)s %(message)s")
    # Bind :8002 immediately; load HF model in background so 05 can poll /health
    # instead of seeing connection-refused for 6–20 minutes.
    threading.Thread(target=_load_model_bg, name="bge-load", daemon=True).start()
    uvicorn.run(app, host=HOST, port=PORT, log_level="info")


if __name__ == "__main__":
    main()
