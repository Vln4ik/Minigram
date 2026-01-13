Backend deployment (Ubuntu + Docker)

1) Copy deploy/ to your server and create .env
   cp .env.example .env
   edit .env (set PUBLIC_URL, JWT_SECRET, LIVEKIT_* and TURN settings)

2) Update deploy/livekit.yaml to match LIVEKIT_API_KEY/SECRET from .env

3) Start services
   docker compose --env-file .env up -d --build

4) Verify health
   curl http://<server-ip>:8080/healthz

Ports to open (MVP):
- 8080/tcp (backend API)
- 7880/tcp (LiveKit WS/HTTP)
- 7881/tcp (LiveKit RTC TCP)
- 50000-50100/udp (LiveKit RTC UDP)
- 3478/tcp+udp (TURN)
- 49160-49200/udp (TURN relay)
- 9000/tcp (MinIO API) and 9001/tcp (console) if needed

Notes:
- For production, put a reverse proxy (Caddy/Nginx) in front of 8080 and 7880 with TLS.
- LIVEKIT_URL should point to the public URL clients use (wss:// for TLS).
- SMS is mocked via SMS_MOCK_CODE in this MVP.
