package httpapi

import (
	"encoding/json"
	"net/http"
	"strings"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
)

type authRequest struct {
	Phone string `json:"phone"`
}

type authVerifyRequest struct {
	Phone string `json:"phone"`
	Code  string `json:"code"`
	Name  string `json:"name"`
}

type authBotRequest struct {
	Code string `json:"code"`
	Name string `json:"name"`
}

type userResponse struct {
	ID          string  `json:"id"`
	Phone       string  `json:"phone"`
	DisplayName string  `json:"display_name"`
	AvatarID    *string `json:"avatar_media_id,omitempty"`
}

func (s *Server) handleAuthRequest(w http.ResponseWriter, r *http.Request) {
	var req authRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		writeError(w, http.StatusBadRequest, "invalid_json")
		return
	}
	phone := normalizePhone(req.Phone)
	if phone == "" {
		writeError(w, http.StatusBadRequest, "phone_required")
		return
	}
	if _, err := s.otp.Request(r.Context(), phone); err != nil {
		writeError(w, http.StatusInternalServerError, "otp_failed")
		return
	}
	writeJSON(w, http.StatusOK, map[string]bool{"sent": true})
}

func (s *Server) handleAuthVerify(w http.ResponseWriter, r *http.Request) {
	var req authVerifyRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		writeError(w, http.StatusBadRequest, "invalid_json")
		return
	}
	phone := normalizePhone(req.Phone)
	if phone == "" || req.Code == "" {
		writeError(w, http.StatusBadRequest, "phone_or_code_missing")
		return
	}
	if err := s.otp.Verify(r.Context(), phone, req.Code); err != nil {
		writeError(w, http.StatusUnauthorized, "invalid_code")
		return
	}
	user, err := s.ensureUser(r, phone, req.Name)
	if err != nil {
		writeError(w, http.StatusInternalServerError, "user_lookup_failed")
		return
	}
	token, err := s.tokens.Issue(user.ID, user.Phone)
	if err != nil {
		writeError(w, http.StatusInternalServerError, "token_failed")
		return
	}
	writeJSON(w, http.StatusOK, map[string]any{
		"token": token,
		"user":  user,
	})
}

func (s *Server) handleAuthBot(w http.ResponseWriter, r *http.Request) {
	var req authBotRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		writeError(w, http.StatusBadRequest, "invalid_json")
		return
	}
	code := strings.TrimSpace(req.Code)
	if code == "" {
		writeError(w, http.StatusBadRequest, "code_required")
		return
	}
	if s.cfg.BotAuthCode != "" && code != s.cfg.BotAuthCode {
		writeError(w, http.StatusUnauthorized, "invalid_code")
		return
	}
	phone := "bot:" + code
	user, err := s.ensureUser(r, phone, req.Name)
	if err != nil {
		writeError(w, http.StatusInternalServerError, "user_lookup_failed")
		return
	}
	token, err := s.tokens.Issue(user.ID, user.Phone)
	if err != nil {
		writeError(w, http.StatusInternalServerError, "token_failed")
		return
	}
	writeJSON(w, http.StatusOK, map[string]any{
		"token": token,
		"user":  user,
	})
}

func (s *Server) handleMe(w http.ResponseWriter, r *http.Request) {
	userID, ok := userIDFromContext(r.Context())
	if !ok {
		writeError(w, http.StatusUnauthorized, "unauthorized")
		return
	}
	row := s.db.QueryRow(r.Context(), `select id, phone, display_name, avatar_media_id from users where id = $1`, userID)
	var id uuid.UUID
	var phone, displayName string
	var avatarID *uuid.UUID
	if err := row.Scan(&id, &phone, &displayName, &avatarID); err != nil {
		writeError(w, http.StatusNotFound, "user_not_found")
		return
	}
	writeJSON(w, http.StatusOK, userToResponse(id, phone, displayName, avatarID))
}

func (s *Server) ensureUser(r *http.Request, phone, name string) (userResponse, error) {
	row := s.db.QueryRow(r.Context(), `select id, display_name, avatar_media_id from users where phone = $1`, phone)
	var id uuid.UUID
	var displayName string
	var avatarID *uuid.UUID
	err := row.Scan(&id, &displayName, &avatarID)
	if err == nil {
		return userToResponse(id, phone, displayName, avatarID), nil
	}
	if err != pgx.ErrNoRows {
		return userResponse{}, err
	}
	if strings.TrimSpace(name) == "" {
		name = "User"
	}
	row = s.db.QueryRow(r.Context(), `insert into users (phone, display_name) values ($1, $2) returning id, display_name, avatar_media_id`, phone, name)
	if err := row.Scan(&id, &displayName, &avatarID); err != nil {
		return userResponse{}, err
	}
	return userToResponse(id, phone, displayName, avatarID), nil
}

func normalizePhone(phone string) string {
	return strings.TrimSpace(phone)
}

func userToResponse(id uuid.UUID, phone, displayName string, avatarID *uuid.UUID) userResponse {
	resp := userResponse{
		ID:          id.String(),
		Phone:       phone,
		DisplayName: displayName,
	}
	if avatarID != nil {
		value := avatarID.String()
		resp.AvatarID = &value
	}
	return resp
}
