package httpapi

import (
	"encoding/json"
	"net/http"
	"time"

	"github.com/google/uuid"
)

type mediaPresignRequest struct {
	Filename string `json:"filename"`
	Size     int64  `json:"size"`
	Mime     string `json:"mime"`
}

type mediaPresignResponse struct {
	MediaID   string    `json:"media_id"`
	ObjectKey string    `json:"object_key"`
	UploadURL string    `json:"upload_url"`
	ExpiresAt time.Time `json:"expires_at"`
}

func (s *Server) handleMediaPresign(w http.ResponseWriter, r *http.Request) {
	userID, ok := userIDFromContext(r.Context())
	if !ok {
		writeError(w, http.StatusUnauthorized, "unauthorized")
		return
	}
	var req mediaPresignRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		writeError(w, http.StatusBadRequest, "invalid_json")
		return
	}
	if req.Filename == "" || req.Size <= 0 || req.Mime == "" {
		writeError(w, http.StatusBadRequest, "invalid_media_request")
		return
	}
	objectKey := s.media.ObjectKey(userID, req.Filename)
	row := s.db.QueryRow(r.Context(), `
		insert into media (owner_id, object_key, size, mime)
		values ($1, $2, $3, $4)
		returning id
	`, userID, objectKey, req.Size, req.Mime)
	var mediaID uuid.UUID
	if err := row.Scan(&mediaID); err != nil {
		writeError(w, http.StatusInternalServerError, "media_create_failed")
		return
	}
	expires := 15 * time.Minute
	uploadURL, err := s.media.PresignPut(r.Context(), objectKey, expires)
	if err != nil {
		writeError(w, http.StatusInternalServerError, "presign_failed")
		return
	}
	writeJSON(w, http.StatusOK, mediaPresignResponse{
		MediaID:   mediaID.String(),
		ObjectKey: objectKey,
		UploadURL: uploadURL,
		ExpiresAt: time.Now().Add(expires),
	})
}
