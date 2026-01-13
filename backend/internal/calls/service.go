package calls

import (
	"errors"
	"time"

	"github.com/livekit/protocol/auth"
)

type Service struct {
	apiKey    string
	apiSecret string
	issuer    string
}

func NewService(apiKey, apiSecret string) *Service {
	return &Service{apiKey: apiKey, apiSecret: apiSecret, issuer: "mini-backend"}
}

func (s *Service) Token(room, identity, name string, ttl time.Duration) (string, error) {
	if s.apiKey == "" || s.apiSecret == "" {
		return "", errors.New("livekit credentials missing")
	}
	at := auth.NewAccessToken(s.apiKey, s.apiSecret)
	at.SetIdentity(identity)
	if name != "" {
		at.SetName(name)
	}
	at.AddGrant(&auth.VideoGrant{
		RoomJoin: true,
		Room:     room,
	})
	if ttl > 0 {
		at.SetValidFor(ttl)
	}
	return at.ToJWT()
}
