package httpapi

import (
	"context"
	"encoding/json"
	"net/http"
	"strconv"
	"time"

	"github.com/go-chi/chi/v5"
	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
)

type sendMessageRequest struct {
	Body    string  `json:"body"`
	MediaID *string `json:"media_id"`
}

type messageResponse struct {
	ID        string     `json:"id"`
	ChatID    string     `json:"chat_id"`
	SenderID  string     `json:"sender_id"`
	Body      string     `json:"body,omitempty"`
	MediaID   *string    `json:"media_id,omitempty"`
	CreatedAt time.Time  `json:"created_at"`
	EditedAt  *time.Time `json:"edited_at,omitempty"`
}

func (s *Server) handleListMessages(w http.ResponseWriter, r *http.Request) {
	userID, ok := userIDFromContext(r.Context())
	if !ok {
		writeError(w, http.StatusUnauthorized, "unauthorized")
		return
	}
	chatID := chi.URLParam(r, "chatID")
	if chatID == "" {
		writeError(w, http.StatusBadRequest, "chat_id_required")
		return
	}
	if _, err := uuid.Parse(chatID); err != nil {
		writeError(w, http.StatusBadRequest, "invalid_chat_id")
		return
	}
	member, err := s.isChatMember(r.Context(), chatID, userID)
	if err != nil {
		writeError(w, http.StatusInternalServerError, "membership_check_failed")
		return
	}
	if !member {
		writeError(w, http.StatusForbidden, "not_member")
		return
	}

	limit := 50
	if value := r.URL.Query().Get("limit"); value != "" {
		if parsed, err := strconv.Atoi(value); err == nil && parsed > 0 && parsed <= 200 {
			limit = parsed
		}
	}
	var before time.Time
	hasBefore := false
	beforeValue := r.URL.Query().Get("before")
	if beforeValue != "" {
		if parsed, err := time.Parse(time.RFC3339, beforeValue); err == nil {
			before = parsed
			hasBefore = true
		}
	}

	var query string
	var rowsArgs []any
	if !hasBefore {
		query = `
			select id, chat_id, sender_id, body, media_id, created_at, edited_at
			from messages
			where chat_id = $1
			order by created_at desc
			limit $2
		`
		rowsArgs = []any{chatID, limit}
	} else {
		query = `
			select id, chat_id, sender_id, body, media_id, created_at, edited_at
			from messages
			where chat_id = $1 and created_at < $2
			order by created_at desc
			limit $3
		`
		rowsArgs = []any{chatID, before, limit}
	}

	rows, err := s.db.Query(r.Context(), query, rowsArgs...)
	if err != nil {
		writeError(w, http.StatusInternalServerError, "message_list_failed")
		return
	}
	defer rows.Close()
	messages := make([]messageResponse, 0)
	for rows.Next() {
		var id, chat, sender uuid.UUID
		var body *string
		var mediaID *uuid.UUID
		var created time.Time
		var edited *time.Time
		if err := rows.Scan(&id, &chat, &sender, &body, &mediaID, &created, &edited); err != nil {
			writeError(w, http.StatusInternalServerError, "message_list_failed")
			return
		}
		resp := messageResponse{
			ID:        id.String(),
			ChatID:    chat.String(),
			SenderID:  sender.String(),
			CreatedAt: created,
			EditedAt:  edited,
		}
		if body != nil {
			resp.Body = *body
		}
		if mediaID != nil {
			value := mediaID.String()
			resp.MediaID = &value
		}
		messages = append(messages, resp)
	}
	writeJSON(w, http.StatusOK, map[string]any{"messages": messages})
}

func (s *Server) handleSendMessage(w http.ResponseWriter, r *http.Request) {
	userID, ok := userIDFromContext(r.Context())
	if !ok {
		writeError(w, http.StatusUnauthorized, "unauthorized")
		return
	}
	chatID := chi.URLParam(r, "chatID")
	if chatID == "" {
		writeError(w, http.StatusBadRequest, "chat_id_required")
		return
	}
	if _, err := uuid.Parse(chatID); err != nil {
		writeError(w, http.StatusBadRequest, "invalid_chat_id")
		return
	}
	member, err := s.isChatMember(r.Context(), chatID, userID)
	if err != nil {
		writeError(w, http.StatusInternalServerError, "membership_check_failed")
		return
	}
	if !member {
		writeError(w, http.StatusForbidden, "not_member")
		return
	}
	var req sendMessageRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		writeError(w, http.StatusBadRequest, "invalid_json")
		return
	}
	if req.Body == "" && req.MediaID == nil {
		writeError(w, http.StatusBadRequest, "message_empty")
		return
	}
	var messageID uuid.UUID
	var mediaID *uuid.UUID
	if req.MediaID != nil && *req.MediaID != "" {
		parsed, err := uuid.Parse(*req.MediaID)
		if err != nil {
			writeError(w, http.StatusBadRequest, "invalid_media_id")
			return
		}
		mediaID = &parsed
	}
	row := s.db.QueryRow(r.Context(), `
		insert into messages (chat_id, sender_id, body, media_id)
		values ($1, $2, $3, $4)
		returning id, created_at
	`, chatID, userID, req.Body, mediaID)
	var created time.Time
	if err := row.Scan(&messageID, &created); err != nil {
		writeError(w, http.StatusInternalServerError, "message_create_failed")
		return
	}
	response := messageResponse{
		ID:        messageID.String(),
		ChatID:    chatID,
		SenderID:  userID,
		Body:      req.Body,
		CreatedAt: created,
	}
	if mediaID != nil {
		value := mediaID.String()
		response.MediaID = &value
	}
	payload, _ := json.Marshal(map[string]any{
		"type":    "message.new",
		"chat_id": chatID,
		"message": response,
	})
	memberIDs, err := s.chatMemberIDs(r.Context(), chatID)
	if err == nil {
		s.hub.Broadcast(memberIDs, payload)
	}
	writeJSON(w, http.StatusOK, response)
}

func (s *Server) chatMemberIDs(ctx context.Context, chatID string) ([]string, error) {
	rows, err := s.db.Query(ctx, `select user_id from chat_members where chat_id = $1`, chatID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	var ids []string
	for rows.Next() {
		var id uuid.UUID
		if err := rows.Scan(&id); err != nil {
			return nil, err
		}
		ids = append(ids, id.String())
	}
	return ids, rows.Err()
}

func (s *Server) isChatMember(ctx context.Context, chatID, userID string) (bool, error) {
	row := s.db.QueryRow(ctx, `select 1 from chat_members where chat_id = $1 and user_id = $2`, chatID, userID)
	var one int
	if err := row.Scan(&one); err != nil {
		if err == pgx.ErrNoRows {
			return false, nil
		}
		return false, err
	}
	return true, nil
}
