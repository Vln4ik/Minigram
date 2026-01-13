package config

import (
	"os"
	"strconv"
	"strings"
)

type Config struct {
	HTTPAddr           string
	PublicURL          string
	JWTSecret          string
	DatabaseURL        string
	RedisURL           string
	MigrationsPath     string
	MinIOEndpoint      string
	MinIOAccessKey     string
	MinIOSecretKey     string
	MinIOBucket        string
	MinIOUseSSL        bool
	LiveKitURL         string
	LiveKitAPIKey      string
	LiveKitAPISecret   string
	CORSAllowedOrigins []string
	SMSProvider        string
	SMSMockCode        string
	BotAuthCode        string
	AutoMigrate        bool
}

func Load() Config {
	return Config{
		HTTPAddr:           getEnv("HTTP_ADDR", ":8080"),
		PublicURL:          getEnv("PUBLIC_URL", "http://localhost:8080"),
		JWTSecret:          mustEnv("JWT_SECRET"),
		DatabaseURL:        mustEnv("DATABASE_URL"),
		RedisURL:           mustEnv("REDIS_URL"),
		MigrationsPath:     getEnv("MIGRATIONS_PATH", "./migrations"),
		MinIOEndpoint:      getEnv("MINIO_ENDPOINT", "localhost:9000"),
		MinIOAccessKey:     getEnv("MINIO_ACCESS_KEY", "minioadmin"),
		MinIOSecretKey:     getEnv("MINIO_SECRET_KEY", "minioadmin"),
		MinIOBucket:        getEnv("MINIO_BUCKET", "media"),
		MinIOUseSSL:        getEnvBool("MINIO_USE_SSL", false),
		LiveKitURL:         getEnv("LIVEKIT_URL", "http://localhost:7880"),
		LiveKitAPIKey:      getEnv("LIVEKIT_API_KEY", ""),
		LiveKitAPISecret:   getEnv("LIVEKIT_API_SECRET", ""),
		CORSAllowedOrigins: splitCSV(getEnv("CORS_ALLOWED_ORIGINS", "*")),
		SMSProvider:        getEnv("SMS_PROVIDER", "mock"),
		SMSMockCode:        getEnv("SMS_MOCK_CODE", "000000"),
		BotAuthCode:        getEnv("BOT_AUTH_CODE", ""),
		AutoMigrate:        getEnvBool("AUTO_MIGRATE", true),
	}
}

func splitCSV(value string) []string {
	parts := strings.Split(value, ",")
	var out []string
	for _, part := range parts {
		trimmed := strings.TrimSpace(part)
		if trimmed == "" {
			continue
		}
		out = append(out, trimmed)
	}
	if len(out) == 0 {
		return []string{"*"}
	}
	return out
}

func getEnv(key, fallback string) string {
	if value := os.Getenv(key); value != "" {
		return value
	}
	return fallback
}

func mustEnv(key string) string {
	value := os.Getenv(key)
	if value == "" {
		return ""
	}
	return value
}

func getEnvBool(key string, fallback bool) bool {
	value := os.Getenv(key)
	if value == "" {
		return fallback
	}
	parsed, err := strconv.ParseBool(value)
	if err != nil {
		return fallback
	}
	return parsed
}
