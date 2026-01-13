package httpapi

import (
	"context"
	"encoding/json"
	"net/http"

	"mini-backend/internal/ws"

	"github.com/gorilla/websocket"
)

var upgrader = websocket.Upgrader{
	ReadBufferSize:  1024,
	WriteBufferSize: 1024,
	CheckOrigin: func(r *http.Request) bool {
		return true
	},
}

type wsEvent struct {
	Type   string `json:"type"`
	ChatID string `json:"chat_id"`
}

func (s *Server) handleWS(w http.ResponseWriter, r *http.Request) {
	token := tokenFromRequest(r)
	if token == "" {
		writeError(w, http.StatusUnauthorized, "missing_token")
		return
	}
	claims, err := s.tokens.Parse(token)
	if err != nil {
		writeError(w, http.StatusUnauthorized, "invalid_token")
		return
	}
	conn, err := upgrader.Upgrade(w, r, nil)
	if err != nil {
		return
	}
	ctx := context.Background()
	client := ws.NewClient(claims.Subject, conn, s.hub)
	s.hub.Register(client)
	client.Run(func(message []byte) {
		var event wsEvent
		if err := json.Unmarshal(message, &event); err != nil {
			return
		}
		if event.Type == "typing" && event.ChatID != "" {
			member, err := s.isChatMember(ctx, event.ChatID, claims.Subject)
			if err != nil || !member {
				return
			}
			payload, _ := json.Marshal(map[string]any{
				"type":    "typing",
				"chat_id": event.ChatID,
				"user_id": claims.Subject,
			})
			memberIDs, err := s.chatMemberIDs(ctx, event.ChatID)
			if err != nil {
				return
			}
			s.hub.Broadcast(memberIDs, payload)
		}
	})
}
