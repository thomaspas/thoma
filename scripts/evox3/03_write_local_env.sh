#!/usr/bin/env bash
# Write/update IncubativeSecondBrain .env for LOCAL FULL (llama :11434 + bge :8002).
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
source "$SCRIPT_DIR/_lib.sh"

require_cmd python3

[ -d "$EVOX3_JINHUA_DIR" ] || die "Missing $EVOX3_JINHUA_DIR — run 02_ensure_jinhua_clone_and_docker.sh first"

ENV_PATH="$EVOX3_JINHUA_DIR/.env"
EXAMPLE_PATH="$EVOX3_JINHUA_DIR/.env.example"

if [ ! -f "$ENV_PATH" ]; then
  [ -f "$EXAMPLE_PATH" ] || die "Missing .env.example in $EVOX3_JINHUA_DIR"
  cp "$EXAMPLE_PATH" "$ENV_PATH"
  ok "Created .env from .env.example"
else
  log "Updating existing .env in place"
fi

# Align LLM_MODEL with live llama-server id (avoids chat failures when id != "qwen").
EVOX3_LLM_MODEL="$(resolve_llm_model "$ENV_PATH")"
export EVOX3_LLM_MODEL
log "Using LLM_MODEL=${EVOX3_LLM_MODEL}"

# Preserve AUTH_SECRET_KEY if already set and non-empty; otherwise generate.
EXISTING_AUTH="$(python3 - <<PY
from pathlib import Path
p = Path("$ENV_PATH")
for line in p.read_text().splitlines():
    if line.startswith("AUTH_SECRET_KEY=") and len(line.split("=",1)[1].strip()) >= 32:
        print(line.split("=",1)[1].strip())
        break
PY
)"

if [ -n "$EXISTING_AUTH" ]; then
  AUTH_SECRET_KEY="$EXISTING_AUTH"
  ok "Keeping existing AUTH_SECRET_KEY"
else
  AUTH_SECRET_KEY="$(python3 -c 'import secrets; print(secrets.token_urlsafe(48))')"
  ok "Generated new AUTH_SECRET_KEY"
fi

python3 - <<PY
from pathlib import Path

path = Path("$ENV_PATH")
text = path.read_text()
replacements = {
    "AUTH_SECRET_KEY=": "AUTH_SECRET_KEY=${AUTH_SECRET_KEY}",
    "AUTH_TOKEN_TTL_HOURS=": "AUTH_TOKEN_TTL_HOURS=168",
    "LLM_PROVIDER=": "LLM_PROVIDER=openai",
    "EMBEDDING_PROVIDER=": "EMBEDDING_PROVIDER=openai",
    "OPENAI_API_KEY=": "OPENAI_API_KEY=sk-local",
    "OPENAI_BASE_URL=": "OPENAI_BASE_URL=${EVOX3_LLM_BASE_URL}",
    "LLM_API_KEY=": "LLM_API_KEY=sk-local",
    "LLM_BASE_URL=": "LLM_BASE_URL=${EVOX3_LLM_BASE_URL}",
    "LLM_MODEL=": "LLM_MODEL=${EVOX3_LLM_MODEL}",
    "EMBEDDING_API_KEY=": "EMBEDDING_API_KEY=sk-local",
    "EMBEDDING_BASE_URL=": "EMBEDDING_BASE_URL=${EVOX3_EMBED_BASE_URL}",
    "EMBEDDING_MODEL=": "EMBEDDING_MODEL=${EVOX3_EMBED_MODEL}",
    "EMBEDDING_DIM=": "EMBEDDING_DIM=1024",
    "EMBEDDING_DIMENSIONS=": "EMBEDDING_DIMENSIONS=0",
    "RERANKER_PROVIDER=": "RERANKER_PROVIDER=none",
    "WORKER_DISPATCH=": "WORKER_DISPATCH=inline",
    "GRAPH_ENABLED=": "GRAPH_ENABLED=true",
    "MEMORY_GRAPH_ENABLED=": "MEMORY_GRAPH_ENABLED=false",
    "MCP_ENABLED=": "MCP_ENABLED=false",
    "STORAGE_BACKEND=": "STORAGE_BACKEND=local",
}

out = []
seen = set()
for line in text.splitlines():
    key = None
    for prefix in replacements:
        if line.startswith(prefix):
            key = prefix
            break
    if key is not None:
        out.append(replacements[key])
        seen.add(key)
    else:
        out.append(line)

for prefix, value in replacements.items():
    if prefix not in seen:
        out.append(value)

path.write_text("\\n".join(out) + "\\n")
print("ENV_OK")
print(f"LLM -> ${EVOX3_LLM_BASE_URL} model=${EVOX3_LLM_MODEL}")
print(f"EMBED -> ${EVOX3_EMBED_BASE_URL} model=${EVOX3_EMBED_MODEL}")
print("RERANKER_PROVIDER=none WORKER_DISPATCH=inline")
PY

ok "03_write_local_env.sh complete — $ENV_PATH"
