package httpapi

import (
	"net/http"
	"strings"
)

func (s *Server) authMiddleware(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
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
		ctx := withUser(r.Context(), claims.Subject, claims.Phone)
		next.ServeHTTP(w, r.WithContext(ctx))
	})
}

func tokenFromRequest(r *http.Request) string {
	if header := r.Header.Get("Authorization"); header != "" {
		parts := strings.SplitN(header, " ", 2)
		if len(parts) == 2 && strings.EqualFold(parts[0], "Bearer") {
			return strings.TrimSpace(parts[1])
		}
	}
	if token := r.URL.Query().Get("token"); token != "" {
		return token
	}
	return ""
}
