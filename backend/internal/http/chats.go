package httpapi

import (
	"encoding/json"
	"net/http"
	"time"

	"github.com/google/uuid"
)

type createChatRequest struct {
	Kind      string   `json:"kind"`
	Title     string   `json:"title"`
	MemberIDs []string `json:"member_ids"`
	UserID    string   `json:"user_id"`
}

type chatResponse struct {
	ID        string     `json:"id"`
	Kind      string     `json:"kind"`
	Title     string     `json:"title,omitempty"`
	CreatedAt time.Time  `json:"created_at"`
	Members   []string   `json:"members,omitempty"`
	LastMsgAt *time.Time `json:"last_message_at,omitempty"`
}

func (s *Server) handleCreateChat(w http.ResponseWriter, r *http.Request) {
	userID, ok := userIDFromContext(r.Context())
	if !ok {
		writeError(w, http.StatusUnauthorized, "unauthorized")
		return
	}
	var req createChatRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		writeError(w, http.StatusBadRequest, "invalid_json")
		return
	}
	kind := req.Kind
	if kind == "" {
		kind = "direct"
	}
	memberIDs := make([]string, 0, len(req.MemberIDs)+2)
	switch kind {
	case "direct":
		if req.UserID == "" {
			writeError(w, http.StatusBadRequest, "user_id_required")
			return
		}
		memberIDs = append(memberIDs, req.UserID)
	case "group":
		if len(req.MemberIDs) == 0 {
			writeError(w, http.StatusBadRequest, "member_ids_required")
			return
		}
		memberIDs = append(memberIDs, req.MemberIDs...)
	default:
		writeError(w, http.StatusBadRequest, "invalid_kind")
		return
	}
	memberIDs = append(memberIDs, userID)

	validMembers, err := validateUUIDs(memberIDs)
	if err != nil {
		writeError(w, http.StatusBadRequest, "invalid_member_id")
		return
	}

	chatID, err := s.createChat(r, kind, req.Title, userID, validMembers)
	if err != nil {
		writeError(w, http.StatusInternalServerError, "chat_create_failed")
		return
	}
	writeJSON(w, http.StatusOK, chatResponse{
		ID:        chatID,
		Kind:      kind,
		Title:     req.Title,
		CreatedAt: time.Now().UTC(),
		Members:   validMembers,
	})
}

func (s *Server) handleListChats(w http.ResponseWriter, r *http.Request) {
	userID, ok := userIDFromContext(r.Context())
	if !ok {
		writeError(w, http.StatusUnauthorized, "unauthorized")
		return
	}
	rows, err := s.db.Query(r.Context(), `
		select c.id, c.kind, c.title, c.created_at
		from chats c
		join chat_members cm on cm.chat_id = c.id
		where cm.user_id = $1
		order by c.created_at desc
	`, userID)
	if err != nil {
		writeError(w, http.StatusInternalServerError, "chat_list_failed")
		return
	}
	defer rows.Close()
	chats := make([]chatResponse, 0)
	for rows.Next() {
		var id uuid.UUID
		var kind string
		var title *string
		var created time.Time
		if err := rows.Scan(&id, &kind, &title, &created); err != nil {
			writeError(w, http.StatusInternalServerError, "chat_list_failed")
			return
		}
		resp := chatResponse{
			ID:        id.String(),
			Kind:      kind,
			CreatedAt: created,
		}
		if title != nil {
			resp.Title = *title
		}
		chats = append(chats, resp)
	}
	writeJSON(w, http.StatusOK, map[string]any{"chats": chats})
}

func (s *Server) createChat(r *http.Request, kind, title, creatorID string, memberIDs []string) (string, error) {
	ctx := r.Context()
	tx, err := s.db.Begin(ctx)
	if err != nil {
		return "", err
	}
	defer func() {
		if err != nil {
			_ = tx.Rollback(ctx)
		}
	}()
	var chatID uuid.UUID
	if err = tx.QueryRow(ctx, `insert into chats (kind, title, created_by) values ($1, $2, $3) returning id`, kind, title, creatorID).Scan(&chatID); err != nil {
		return "", err
	}
	for _, memberID := range dedupeStrings(memberIDs) {
		if _, err = tx.Exec(ctx, `insert into chat_members (chat_id, user_id) values ($1, $2)`, chatID, memberID); err != nil {
			return "", err
		}
	}
	if err = tx.Commit(ctx); err != nil {
		return "", err
	}
	return chatID.String(), nil
}

func dedupeStrings(values []string) []string {
	seen := make(map[string]struct{})
	var out []string
	for _, value := range values {
		if value == "" {
			continue
		}
		if _, ok := seen[value]; ok {
			continue
		}
		seen[value] = struct{}{}
		out = append(out, value)
	}
	return out
}

func validateUUIDs(values []string) ([]string, error) {
	var out []string
	for _, value := range values {
		parsed, err := uuid.Parse(value)
		if err != nil {
			return nil, err
		}
		out = append(out, parsed.String())
	}
	return out, nil
}
