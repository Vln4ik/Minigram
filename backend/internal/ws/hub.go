package ws

import (
	"sync"
)

type Hub struct {
	mu      sync.RWMutex
	clients map[string]map[*Client]struct{}
}

func NewHub() *Hub {
	return &Hub{clients: make(map[string]map[*Client]struct{})}
}

func (h *Hub) Register(client *Client) {
	h.mu.Lock()
	defer h.mu.Unlock()
	set, ok := h.clients[client.UserID]
	if !ok {
		set = make(map[*Client]struct{})
		h.clients[client.UserID] = set
	}
	set[client] = struct{}{}
}

func (h *Hub) Unregister(client *Client) {
	h.mu.Lock()
	defer h.mu.Unlock()
	set, ok := h.clients[client.UserID]
	if !ok {
		return
	}
	delete(set, client)
	if len(set) == 0 {
		delete(h.clients, client.UserID)
	}
}

func (h *Hub) Broadcast(userIDs []string, payload []byte) {
	h.mu.RLock()
	defer h.mu.RUnlock()
	for _, userID := range userIDs {
		set, ok := h.clients[userID]
		if !ok {
			continue
		}
		for client := range set {
			client.Send(payload)
		}
	}
}
