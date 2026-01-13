package auth

import (
	"context"
	"crypto/rand"
	"fmt"
	"log"
	"math/big"
	"time"

	"github.com/redis/go-redis/v9"
)

type OTPService struct {
	redis    *redis.Client
	ttl      time.Duration
	mockCode string
}

func NewOTPService(redis *redis.Client, mockCode string, ttl time.Duration) *OTPService {
	return &OTPService{redis: redis, ttl: ttl, mockCode: mockCode}
}

func (o *OTPService) Request(ctx context.Context, phone string) (string, error) {
	code := o.mockCode
	if code == "" {
		generated, err := generateCode(6)
		if err != nil {
			return "", err
		}
		code = generated
	}
	key := otpKey(phone)
	if err := o.redis.Set(ctx, key, code, o.ttl).Err(); err != nil {
		return "", err
	}
	log.Printf("otp code for %s: %s", phone, code)
	return code, nil
}

func (o *OTPService) Verify(ctx context.Context, phone, code string) error {
	key := otpKey(phone)
	stored, err := o.redis.Get(ctx, key).Result()
	if err != nil {
		return err
	}
	if stored != code {
		return fmt.Errorf("invalid_code")
	}
	return o.redis.Del(ctx, key).Err()
}

func otpKey(phone string) string {
	return "otp:" + phone
}

func generateCode(length int) (string, error) {
	max := new(big.Int).Exp(big.NewInt(10), big.NewInt(int64(length)), nil)
	n, err := rand.Int(rand.Reader, max)
	if err != nil {
		return "", err
	}
	format := fmt.Sprintf("%%0%dd", length)
	return fmt.Sprintf(format, n.Int64()), nil
}
