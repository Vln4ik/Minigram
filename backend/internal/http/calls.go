package httpapi

import (
	"encoding/json"
	"net/http"
	"strings"
	"time"

	"github.com/google/uuid"
)

type createCallRequest struct {
	ChatID *string `json:"chat_id"`
}

type joinCallRequest struct {
	CallID string `json:"call_id"`
}

type callResponse struct {
	CallID    string `json:"call_id"`
	Room      string `json:"room"`
	Token     string `json:"token"`
	LiveKitURL string `json:"livekit_url"`
}

func (s *Server) handleCreateCall(w http.ResponseWriter, r *http.Request) {
	userID, ok := userIDFromContext(r.Context())
	if !ok {
		writeError(w, http.StatusUnauthorized, "unauthorized")
		return
	}
	var req createCallRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		writeError(w, http.StatusBadRequest, "invalid_json")
		return
	}
	var chatID *uuid.UUID
	room := "call_" + time.Now().UTC().Format("20060102150405")
	if req.ChatID != nil {
		trimmed := strings.TrimSpace(*req.ChatID)
		if trimmed != "" {
			parsed, err := uuid.Parse(trimmed)
			if err != nil {
				writeError(w, http.StatusBadRequest, "invalid_chat_id")
				return
			}
			member, err := s.isChatMember(r.Context(), trimmed, userID)
			if err != nil {
				writeError(w, http.StatusInternalServerError, "membership_check_failed")
				return
			}
			if !member {
				writeError(w, http.StatusForbidden, "not_member")
				return
			}
			chatID = &parsed
			room = "chat_" + trimmed + "_" + time.Now().UTC().Format("20060102150405")
		}
	}
	row := s.db.QueryRow(r.Context(), `
		insert into calls (chat_id, room_name, created_by)
		values ($1, $2, $3)
		returning id
	`, chatID, room, userID)
	var callID uuid.UUID
	if err := row.Scan(&callID); err != nil {
		writeError(w, http.StatusInternalServerError, "call_create_failed")
		return
	}
	name := s.userDisplayName(r, userID)
	token, err := s.calls.Token(room, userID, name, time.Hour)
	if err != nil {
		writeError(w, http.StatusInternalServerError, "call_token_failed")
		return
	}
	writeJSON(w, http.StatusOK, callResponse{
		CallID:     callID.String(),
		Room:       room,
		Token:      token,
		LiveKitURL: s.cfg.LiveKitURL,
	})
}

func (s *Server) handleJoinCall(w http.ResponseWriter, r *http.Request) {
	userID, ok := userIDFromContext(r.Context())
	if !ok {
		writeError(w, http.StatusUnauthorized, "unauthorized")
		return
	}
	var req joinCallRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		writeError(w, http.StatusBadRequest, "invalid_json")
		return
	}
	if req.CallID == "" {
		writeError(w, http.StatusBadRequest, "call_id_required")
		return
	}
	if _, err := uuid.Parse(req.CallID); err != nil {
		writeError(w, http.StatusBadRequest, "invalid_call_id")
		return
	}
	row := s.db.QueryRow(r.Context(), `select room_name, chat_id from calls where id = $1`, req.CallID)
	var roomName string
	var chatID *uuid.UUID
	if err := row.Scan(&roomName, &chatID); err != nil {
		writeError(w, http.StatusNotFound, "call_not_found")
		return
	}
	if chatID != nil {
		member, err := s.isChatMember(r.Context(), chatID.String(), userID)
		if err != nil {
			writeError(w, http.StatusInternalServerError, "membership_check_failed")
			return
		}
		if !member {
			writeError(w, http.StatusForbidden, "not_member")
			return
		}
	}
	name := s.userDisplayName(r, userID)
	token, err := s.calls.Token(roomName, userID, name, time.Hour)
	if err != nil {
		writeError(w, http.StatusInternalServerError, "call_token_failed")
		return
	}
	writeJSON(w, http.StatusOK, callResponse{
		CallID:     req.CallID,
		Room:       roomName,
		Token:      token,
		LiveKitURL: s.cfg.LiveKitURL,
	})
}

func (s *Server) userDisplayName(r *http.Request, userID string) string {
	row := s.db.QueryRow(r.Context(), `select display_name from users where id = $1`, userID)
	var name string
	if err := row.Scan(&name); err != nil {
		return userID
	}
	return name
}
