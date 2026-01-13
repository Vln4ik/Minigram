package auth

import (
	"errors"
	"time"

	"github.com/golang-jwt/jwt/v5"
)

type TokenService struct {
	secret []byte
	issuer string
	ttl    time.Duration
}

type Claims struct {
	Phone string `json:"phone"`
	jwt.RegisteredClaims
}

func NewTokenService(secret, issuer string, ttl time.Duration) *TokenService {
	return &TokenService{secret: []byte(secret), issuer: issuer, ttl: ttl}
}

func (t *TokenService) Issue(userID, phone string) (string, error) {
	if len(t.secret) == 0 {
		return "", errors.New("jwt secret missing")
	}
	now := time.Now()
	claims := Claims{
		Phone: phone,
		RegisteredClaims: jwt.RegisteredClaims{
			Issuer:    t.issuer,
			Subject:   userID,
			IssuedAt:  jwt.NewNumericDate(now),
			ExpiresAt: jwt.NewNumericDate(now.Add(t.ttl)),
		},
	}
	token := jwt.NewWithClaims(jwt.SigningMethodHS256, claims)
	return token.SignedString(t.secret)
}

func (t *TokenService) Parse(token string) (*Claims, error) {
	parsed, err := jwt.ParseWithClaims(token, &Claims{}, func(_ *jwt.Token) (any, error) {
		return t.secret, nil
	})
	if err != nil {
		return nil, err
	}
	claims, ok := parsed.Claims.(*Claims)
	if !ok || !parsed.Valid {
		return nil, errors.New("invalid token")
	}
	return claims, nil
}
