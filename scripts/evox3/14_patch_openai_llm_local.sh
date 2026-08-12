#!/usr/bin/env bash
# Patch Jinhua OpenAILLMClient for local llama-server + Qwen thinking models:
# - HTTP timeout / few retries (avoid infinite hang)
# - disable thinking via extra_body + /no_think suffix
# Idempotent. Restart API after applying.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
source "$SCRIPT_DIR/_lib.sh"

PROVIDERS="$EVOX3_JINHUA_DIR/secondbrain/llm/providers.py"
BAK="$EVOX3_JINHUA_DIR/secondbrain/llm/providers.py.evox3-orig"
MARKER="$EVOX3_JINHUA_DIR/.evox3-llm-nothink"
PATCH_VER="1"

[ -f "$PROVIDERS" ] || die "Missing $PROVIDERS — is Jinhua cloned?"

if [ -f "$MARKER" ] && [ "$(tr -d '[:space:]' <"$MARKER")" = "$PATCH_VER" ] \
  && grep -q 'EVOX3_LLM_NOTHINK' "$PROVIDERS" 2>/dev/null; then
  ok "LLM no-think patch already applied (v${PATCH_VER})"
  exit 0
fi

if [ ! -f "$BAK" ]; then
  cp "$PROVIDERS" "$BAK"
  ok "Backed up providers.py -> providers.py.evox3-orig"
fi

python3 - "$PROVIDERS" "$BAK" <<'PY'
from pathlib import Path
import re
import sys

path = Path(sys.argv[1])
bak = Path(sys.argv[2])
text = bak.read_text()

# 1) OpenAI(...) kwargs: add timeout + max_retries
old_init = '''        kwargs = {"api_key": settings.resolved_llm_api_key}
        if settings.resolved_llm_base_url:
            kwargs["base_url"] = settings.resolved_llm_base_url
        self._client = OpenAI(**kwargs)
        self._model = settings.llm_model'''

new_init = '''        kwargs = {"api_key": settings.resolved_llm_api_key}
        if settings.resolved_llm_base_url:
            kwargs["base_url"] = settings.resolved_llm_base_url
        # EVOX3_LLM_NOTHINK: avoid infinite hang on local llama-server
        kwargs["timeout"] = 180.0
        kwargs["max_retries"] = 1
        self._client = OpenAI(**kwargs)
        self._model = settings.llm_model'''

if old_init not in text:
    raise SystemExit("Could not locate OpenAILLMClient __init__ kwargs block")
text = text.replace(old_init, new_init, 1)

# 2) Replace _chat to disable Qwen thinking + cap tokens
old_chat = '''    def _chat(self, system: str, user: str) -> str:
        resp = self._client.chat.completions.create(
            model=self._model,
            messages=[
                {"role": "system", "content": system},
                {"role": "user", "content": user},
            ],
            temperature=0.2,
        )
        return resp.choices[0].message.content or ""'''

new_chat = '''    def _chat(self, system: str, user: str) -> str:
        # EVOX3_LLM_NOTHINK: Qwen3 thinking can block ingest/chat for minutes
        user_nt = user if "/no_think" in user else (user.rstrip() + "\\n/no_think")
        resp = self._client.chat.completions.create(
            model=self._model,
            messages=[
                {"role": "system", "content": system},
                {"role": "user", "content": user_nt},
            ],
            temperature=0.2,
            max_tokens=1024,
            extra_body={"chat_template_kwargs": {"enable_thinking": False}},
        )
        return resp.choices[0].message.content or ""'''

if old_chat not in text:
    raise SystemExit("Could not locate OpenAILLMClient._chat")
text = text.replace(old_chat, new_chat, 1)

if "EVOX3_LLM_NOTHINK" not in text:
    raise SystemExit("Patch incomplete")
path.write_text(text)
print("LLM_PATCHED")
PY

printf '%s\n' "$PATCH_VER" >"$MARKER"
ok "Patched $PROVIDERS (timeout + /no_think)"

if command -v systemctl >/dev/null 2>&1; then
  log "Restarting evox3-jinhua-api.service"
  systemctl --user restart evox3-jinhua-api.service || warn "Could not restart API unit"
fi
ok "14_patch_openai_llm_local.sh complete — re-run ingest after API is up"
