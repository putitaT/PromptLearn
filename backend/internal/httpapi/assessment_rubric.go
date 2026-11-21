package httpapi

import (
	"context"
	"errors"
	"log"
	"mime"
	"net"
	"net/http"
	"time"

	"github.com/opsst/PromptLearn/backend/internal/assessmentrubric"
)

func WithAssessmentRubrics(generator assessmentrubric.Generator) RouterOption {
	return func(mux *http.ServeMux) {
		mux.HandleFunc("POST /v1/assessments/rubric/draft", func(w http.ResponseWriter, r *http.Request) {
			host := r.Host
			if name, _, err := net.SplitHostPort(r.Host); err == nil {
				host = name
			}
			peer, _, err := net.SplitHostPort(r.RemoteAddr)
			if err != nil || !net.ParseIP(peer).IsLoopback() || !IsLoopbackHost(host) {
				writeAPIError(w, http.StatusForbidden, "forbidden", "the assessment rubric demo is available on this machine only")
				return
			}
			mediaType, _, err := mime.ParseMediaType(r.Header.Get("Content-Type"))
			if err != nil || mediaType != "application/json" {
				writeAPIError(w, http.StatusUnsupportedMediaType, "unsupported_media_type", "send application/json")
				return
			}
			var input assessmentrubric.Request
			if !readJSONWithLimit(w, r, &input, 64<<10) {
				return
			}
			if err := input.Validate(); err != nil {
				writeAPIError(w, http.StatusBadRequest, "invalid_input", err.Error())
				return
			}
			if generator == nil {
				writeAPIError(w, http.StatusServiceUnavailable, "rubric_ai_unavailable", "OpenAI is not configured on the backend")
				return
			}

			ctx, cancel := context.WithTimeout(r.Context(), 60*time.Second)
			defer cancel()
			result, err := generator.Generate(ctx, input)
			switch {
			case errors.Is(err, context.DeadlineExceeded):
				writeAPIError(w, http.StatusGatewayTimeout, "rubric_timeout", "rubric drafting timed out")
			case err != nil:
				log.Printf("assessment rubric draft failed: %v", err)
				writeAPIError(w, http.StatusBadGateway, "rubric_failed", "could not draft an answer from the lesson and question")
			default:
				writeJSON(w, http.StatusOK, result)
			}
		})
	}
}
