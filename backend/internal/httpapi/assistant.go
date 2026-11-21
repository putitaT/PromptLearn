package httpapi

import (
	"context"
	"errors"
	"log"
	"mime"
	"net"
	"net/http"
	"time"

	"github.com/opsst/PromptLearn/backend/internal/assistant"
)

func WithAssistant(responder assistant.Responder) RouterOption {
	return func(mux *http.ServeMux) {
		mux.HandleFunc("POST /v1/assistant/chat", assistantChat(responder))
	}
}

func assistantChat(responder assistant.Responder) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		host := r.Host
		if name, _, err := net.SplitHostPort(r.Host); err == nil {
			host = name
		}
		peer, _, err := net.SplitHostPort(r.RemoteAddr)
		// Android Emulator maps 10.0.2.2 to the development machine's loopback.
		if err != nil || !net.ParseIP(peer).IsLoopback() || (!IsLoopbackHost(host) && host != "10.0.2.2") {
			writeAPIError(w, http.StatusForbidden, "forbidden", "PL AI is available on the development machine only")
			return
		}
		mediaType, _, err := mime.ParseMediaType(r.Header.Get("Content-Type"))
		if err != nil || mediaType != "application/json" {
			writeAPIError(w, http.StatusUnsupportedMediaType, "unsupported_media_type", "send application/json")
			return
		}
		var request assistant.Request
		if !readJSONWithLimit(w, r, &request, 256<<10) {
			return
		}
		if err := request.Validate(); err != nil {
			writeAPIError(w, http.StatusBadRequest, "invalid_input", err.Error())
			return
		}
		if responder == nil {
			writeAPIError(w, http.StatusServiceUnavailable, "assistant_unavailable", "OpenAI is not configured on the backend")
			return
		}

		ctx, cancel := context.WithTimeout(r.Context(), 60*time.Second)
		defer cancel()
		reply, err := responder.Respond(ctx, request)
		switch {
		case errors.Is(err, context.DeadlineExceeded):
			writeAPIError(w, http.StatusGatewayTimeout, "assistant_timeout", "PL AI timed out")
		case err != nil:
			log.Printf("PL AI request failed: %v", err)
			writeAPIError(w, http.StatusBadGateway, "assistant_failed", "PL AI could not generate a reply")
		default:
			writeJSON(w, http.StatusOK, reply)
		}
	}
}
