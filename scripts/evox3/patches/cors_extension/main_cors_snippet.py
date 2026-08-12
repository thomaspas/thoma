from __future__ import annotations

# EVOX3_CORS_EXTENSION: allow chrome-extension:// origins for ANGELICA Capture MV3.
OLD = '''    app.add_middleware(
        CORSMiddleware,
        allow_origins=[
            "http://localhost:5173",
            "http://127.0.0.1:5173",
        ],
        allow_methods=["*"],
        allow_headers=["*"],
    )'''

NEW = '''    app.add_middleware(
        CORSMiddleware,
        allow_origins=[
            "http://localhost:5173",
            "http://127.0.0.1:5173",
        ],
        # EVOX3_CORS_EXTENSION: allow chrome-extension:// origins for ANGELICA Capture MV3.
        allow_origin_regex=r"chrome-extension://.*",
        allow_methods=["*"],
        allow_headers=["*"],
    )'''
