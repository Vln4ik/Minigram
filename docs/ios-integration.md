iOS client integration notes (Telegram-like UX)

Important:
- Official Telegram iOS client is built for MTProto and Telegram servers.
- To use your backend, you must replace the networking and data layer with your REST/WebSocket API.
- Telegram iOS is GPL; any derivative must remain open-source.

Recommended approach for this MVP:
1) Start from Telegram-iOS open-source repo (not included here). Build in Xcode to verify baseline.
2) Replace the networking layer:
   - Create a new API client for:
     - POST /v1/auth/request
     - POST /v1/auth/verify
     - GET /v1/me
     - GET /v1/chats
     - POST /v1/chats
     - GET /v1/chats/{chat_id}/messages
     - POST /v1/chats/{chat_id}/messages
     - POST /v1/media/presign
     - POST /v1/calls
     - POST /v1/calls/join
     - WS /v1/ws (typing + message events)
3) Map Telegram UI state to API models:
   - Dialog list -> /v1/chats
   - Message history -> /v1/chats/{id}/messages
   - Send message -> /v1/chats/{id}/messages
   - Presence/typing -> WS events
4) Calls:
   - Integrate LiveKit iOS SDK.
   - Use backend /v1/calls or /v1/calls/join to fetch token + LIVEKIT_URL.
   - Configure TURN from the server (coturn) in LiveKit settings if needed.
5) Encryption:
   - Implement Signal Protocol in iOS for secret chats.
   - Store identity/prekeys in the backend tables created in migrations/002_e2e.sql.

This doc is a high-level map. Once you add the Telegram iOS source into this repo, we can wire the exact modules and entry points.
