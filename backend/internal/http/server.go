package httpapi

import (
	"context"
	"net/http"
	"time"

	"mini-backend/internal/auth"
	"mini-backend/internal/calls"
	"mini-backend/internal/config"
	"mini-backend/internal/media"
	"mini-backend/internal/ws"

	"github.com/go-chi/chi/v5"
	"github.com/go-chi/chi/v5/middleware"
	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/redis/go-redis/v9"
)

type Server struct {
	cfg    config.Config
	db     *pgxpool.Pool
	redis  *redis.Client
	otp    *auth.OTPService
	tokens *auth.TokenService
	media  *media.Service
	calls  *calls.Service
	hub    *ws.Hub
}

func NewServer(cfg config.Config, db *pgxpool.Pool, redis *redis.Client) (*Server, error) {
	mediaSvc, err := media.NewService(cfg)
	if err != nil {
		return nil, err
	}
	return &Server{
		cfg:    cfg,
		db:     db,
		redis:  redis,
		otp:    auth.NewOTPService(redis, cfg.SMSMockCode, 5*time.Minute),
		tokens: auth.NewTokenService(cfg.JWTSecret, "mini-backend", 30*24*time.Hour),
		media:  mediaSvc,
		calls:  calls.NewService(cfg.LiveKitAPIKey, cfg.LiveKitAPISecret),
		hub:    ws.NewHub(),
	}, nil
}

func (s *Server) Routes() http.Handler {
	r := chi.NewRouter()
	r.Use(middleware.RequestID)
	r.Use(middleware.RealIP)
	r.Use(middleware.Recoverer)

	r.Get("/healthz", s.handleHealth)
	r.Get("/readyz", s.handleReady)

	r.Route("/v1", func(r chi.Router) {
		r.Post("/auth/request", s.handleAuthRequest)
		r.Post("/auth/verify", s.handleAuthVerify)
		r.Post("/auth/bot", s.handleAuthBot)

		r.Group(func(r chi.Router) {
			r.Use(s.authMiddleware)
			r.Get("/me", s.handleMe)
			r.Get("/chats", s.handleListChats)
			r.Post("/chats", s.handleCreateChat)
			r.Get("/chats/{chatID}/messages", s.handleListMessages)
			r.Post("/chats/{chatID}/messages", s.handleSendMessage)
			r.Post("/media/presign", s.handleMediaPresign)
			r.Post("/calls", s.handleCreateCall)
			r.Post("/calls/join", s.handleJoinCall)
			r.Get("/ws", s.handleWS)
		})
	})

	return r
}

func (s *Server) handleHealth(w http.ResponseWriter, r *http.Request) {
	writeJSON(w, http.StatusOK, map[string]string{"status": "ok"})
}

func (s *Server) handleReady(w http.ResponseWriter, r *http.Request) {
	ctx, cancel := context.WithTimeout(r.Context(), 2*time.Second)
	defer cancel()

	if err := s.db.Ping(ctx); err != nil {
		writeError(w, http.StatusServiceUnavailable, "database_unavailable")
		return
	}
	if err := s.redis.Ping(ctx).Err(); err != nil {
		writeError(w, http.StatusServiceUnavailable, "redis_unavailable")
		return
	}
	writeJSON(w, http.StatusOK, map[string]string{"status": "ready"})
}
