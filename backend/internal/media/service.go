package media

import (
	"context"
	"fmt"
	"time"

	"mini-backend/internal/config"

	"github.com/minio/minio-go/v7"
	"github.com/minio/minio-go/v7/pkg/credentials"
)

type Service struct {
	client *minio.Client
	bucket string
}

func NewService(cfg config.Config) (*Service, error) {
	client, err := minio.New(cfg.MinIOEndpoint, &minio.Options{
		Creds:  credentials.NewStaticV4(cfg.MinIOAccessKey, cfg.MinIOSecretKey, ""),
		Secure: cfg.MinIOUseSSL,
	})
	if err != nil {
		return nil, err
	}
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()
	found, err := client.BucketExists(ctx, cfg.MinIOBucket)
	if err != nil {
		return nil, err
	}
	if !found {
		if err := client.MakeBucket(ctx, cfg.MinIOBucket, minio.MakeBucketOptions{}); err != nil {
			return nil, err
		}
	}
	return &Service{client: client, bucket: cfg.MinIOBucket}, nil
}

func (s *Service) PresignPut(ctx context.Context, objectKey string, expiry time.Duration) (string, error) {
	url, err := s.client.PresignedPutObject(ctx, s.bucket, objectKey, expiry)
	if err != nil {
		return "", err
	}
	return url.String(), nil
}

func (s *Service) ObjectKey(userID string, filename string) string {
	stamp := time.Now().UTC().Format("20060102/150405")
	return fmt.Sprintf("%s/%s/%s", userID, stamp, filename)
}
