Mini backend (MVP)

Base URL: http://<host>:8080

Health:
- GET /healthz
- GET /readyz

Auth:
- POST /v1/auth/request {"phone":"+79990001122"}
- POST /v1/auth/verify {"phone":"+79990001122","code":"000000","name":"Ivan"}
- POST /v1/auth/bot {"code":"123456","name":"Ivan"}

Chats:
- GET /v1/chats (Bearer token)
- POST /v1/chats (Bearer token)
  - direct: {"kind":"direct","user_id":"<uuid>"}
  - group:  {"kind":"group","title":"Team","member_ids":["<uuid>","<uuid>"]}

Messages:
- GET /v1/chats/{chat_id}/messages
- POST /v1/chats/{chat_id}/messages {"body":"hi"}

Media:
- POST /v1/media/presign {"filename":"photo.jpg","size":12345,"mime":"image/jpeg"}

Calls (LiveKit):
- POST /v1/calls {"chat_id":"<uuid>"} (optional chat_id)
- POST /v1/calls/join {"call_id":"<uuid>"}

WebSocket:
- GET /v1/ws?token=<jwt>
  - incoming: {"type":"typing","chat_id":"<uuid>"}
  - outgoing: {"type":"message.new", "chat_id":"<uuid>", "message":{...}}

All authenticated endpoints require: Authorization: Bearer <token>
