package ws

import (
	"log"
	"time"

	"github.com/gorilla/websocket"
)

const (
	writeWait      = 10 * time.Second
	pongWait       = 60 * time.Second
	pingPeriod     = 50 * time.Second
	maxMessageSize = 128 * 1024
)

type Client struct {
	UserID string
	Conn   *websocket.Conn
	send   chan []byte
	hub    *Hub
}

func NewClient(userID string, conn *websocket.Conn, hub *Hub) *Client {
	return &Client{
		UserID: userID,
		Conn:   conn,
		send:   make(chan []byte, 64),
		hub:    hub,
	}
}

func (c *Client) Send(payload []byte) {
	select {
	case c.send <- payload:
	default:
		log.Printf("ws send buffer full for %s", c.UserID)
	}
}

func (c *Client) Run(readHandler func(message []byte)) {
	go c.writePump()
	c.readPump(readHandler)
}

func (c *Client) readPump(readHandler func(message []byte)) {
	defer func() {
		c.hub.Unregister(c)
		_ = c.Conn.Close()
	}()
	c.Conn.SetReadLimit(maxMessageSize)
	_ = c.Conn.SetReadDeadline(time.Now().Add(pongWait))
	c.Conn.SetPongHandler(func(string) error {
		_ = c.Conn.SetReadDeadline(time.Now().Add(pongWait))
		return nil
	})
	for {
		_, message, err := c.Conn.ReadMessage()
		if err != nil {
			return
		}
		if readHandler != nil {
			readHandler(message)
		}
	}
}

func (c *Client) writePump() {
	ticker := time.NewTicker(pingPeriod)
	defer func() {
		ticker.Stop()
		_ = c.Conn.Close()
	}()
	for {
		select {
		case message, ok := <-c.send:
			_ = c.Conn.SetWriteDeadline(time.Now().Add(writeWait))
			if !ok {
				_ = c.Conn.WriteMessage(websocket.CloseMessage, []byte{})
				return
			}
			if err := c.Conn.WriteMessage(websocket.TextMessage, message); err != nil {
				return
			}
		case <-ticker.C:
			_ = c.Conn.SetWriteDeadline(time.Now().Add(writeWait))
			if err := c.Conn.WriteMessage(websocket.PingMessage, nil); err != nil {
				return
			}
		}
	}
}
