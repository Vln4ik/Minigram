package httpapi

import "context"

type contextKey string

const (
	contextKeyUserID contextKey = "user_id"
	contextKeyPhone  contextKey = "phone"
)

func withUser(ctx context.Context, userID, phone string) context.Context {
	ctx = context.WithValue(ctx, contextKeyUserID, userID)
	return context.WithValue(ctx, contextKeyPhone, phone)
}

func userIDFromContext(ctx context.Context) (string, bool) {
	value := ctx.Value(contextKeyUserID)
	userID, ok := value.(string)
	return userID, ok
}

func phoneFromContext(ctx context.Context) (string, bool) {
	value := ctx.Value(contextKeyPhone)
	phone, ok := value.(string)
	return phone, ok
}
