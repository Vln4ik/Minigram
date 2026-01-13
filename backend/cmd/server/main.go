package main

import (
	"context"
	"log"
	"net/http"
	"os"
	"os/signal"
	"syscall"
	"time"

	"mini-backend/internal/config"
	httpapi "mini-backend/internal/http"
	"mini-backend/internal/migrate"
	"mini-backend/internal/store"
)

func main() {
	cfg := config.Load()
	missing := requiredEnvMissing(cfg)
	if len(missing) > 0 {
		log.Fatalf("missing required env: %v", missing)
	}

	ctx := context.Background()
	db, err := store.NewPostgres(ctx, cfg.DatabaseURL)
	if err != nil {
		log.Fatalf("postgres connection failed: %v", err)
	}
	defer db.Close()

	redis, err := store.NewRedis(cfg.RedisURL)
	if err != nil {
		log.Fatalf("redis connection failed: %v", err)
	}
	defer redis.Close()

	if cfg.AutoMigrate {
		if err := migrate.Apply(ctx, db, cfg.MigrationsPath); err != nil {
			log.Fatalf("migrations failed: %v", err)
		}
	}

	server, err := httpapi.NewServer(cfg, db, redis)
	if err != nil {
		log.Fatalf("server init failed: %v", err)
	}

	httpServer := &http.Server{
		Addr:         cfg.HTTPAddr,
		Handler:      server.Routes(),
		ReadTimeout:  15 * time.Second,
		WriteTimeout: 15 * time.Second,
		IdleTimeout:  60 * time.Second,
	}

	go func() {
		log.Printf("backend listening on %s", cfg.HTTPAddr)
		if err := httpServer.ListenAndServe(); err != nil && err != http.ErrServerClosed {
			log.Fatalf("http server error: %v", err)
		}
	}()

	shutdown := make(chan os.Signal, 1)
	signal.Notify(shutdown, syscall.SIGINT, syscall.SIGTERM)
	<-shutdown

	ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()
	if err := httpServer.Shutdown(ctx); err != nil {
		log.Printf("graceful shutdown failed: %v", err)
	}
}

func requiredEnvMissing(cfg config.Config) []string {
	var missing []string
	if cfg.JWTSecret == "" {
		missing = append(missing, "JWT_SECRET")
	}
	if cfg.DatabaseURL == "" {
		missing = append(missing, "DATABASE_URL")
	}
	if cfg.RedisURL == "" {
		missing = append(missing, "REDIS_URL")
	}
	return missing
}
