package httpapi

import (
	"context"
	"errors"
	"log"
	"mime"
	"net"
	"net/http"
	"time"

	"github.com/opsst/PromptLearn/backend/internal/assignmentreview"
)

const maxReviewRequestBytes = 5 << 20

func WithAssignmentReview(service *assignmentreview.Service) RouterOption {
	return func(mux *http.ServeMux) {
		mux.HandleFunc("POST /v1/assignments/{assignment_id}/items/{item_id}/reviews", func(w http.ResponseWriter, r *http.Request) {
			if !allowAssignmentRequest(w, r) {
				return
			}
			var work assignmentreview.Submission
			if !readJSONWithLimit(w, r, &work, maxReviewRequestBytes) {
				return
			}
			ctx, cancel := context.WithTimeout(r.Context(), 60*time.Second)
			defer cancel()
			result, err := service.Review(ctx, r.PathValue("assignment_id"), r.PathValue("item_id"), work)
			if err != nil {
				writeReviewError(w, err)
				return
			}
			writeJSON(w, http.StatusOK, result)
		})
		mux.HandleFunc("POST /v1/assignments/{assignment_id}/submissions", func(w http.ResponseWriter, r *http.Request) {
			if !allowAssignmentRequest(w, r) {
				return
			}
			var request struct {
				ReviewIDs []string `json:"review_ids"`
			}
			if !readJSONWithLimit(w, r, &request, 8<<10) {
				return
			}
			report, err := service.Submit(r.Context(), r.PathValue("assignment_id"), request.ReviewIDs)
			if err != nil {
				writeReviewError(w, err)
				return
			}
			writeJSON(w, http.StatusCreated, report)
		})
	}
}

func allowAssignmentRequest(w http.ResponseWriter, r *http.Request) bool {
	host, _, err := net.SplitHostPort(r.Host)
	if err != nil {
		host = r.Host
	}
	peer, _, err := net.SplitHostPort(r.RemoteAddr)
	if err != nil || !net.ParseIP(peer).IsLoopback() || !IsLoopbackHost(host) {
		writeAPIError(w, http.StatusForbidden, "forbidden", "the review demo is available on this machine only")
		return false
	}
	mediaType, _, err := mime.ParseMediaType(r.Header.Get("Content-Type"))
	if err != nil || mediaType != "application/json" {
		writeAPIError(w, http.StatusUnsupportedMediaType, "unsupported_media_type", "send application/json")
		return false
	}
	return true
}

func writeReviewError(w http.ResponseWriter, err error) {
	switch {
	case errors.Is(err, assignmentreview.ErrInvalidInput):
		writeAPIError(w, http.StatusBadRequest, "invalid_input", err.Error())
	case errors.Is(err, assignmentreview.ErrNotFound):
		writeAPIError(w, http.StatusNotFound, "item_not_found", "assignment item not found")
	case errors.Is(err, assignmentreview.ErrAttemptClosed):
		writeAPIError(w, http.StatusConflict, "attempt_closed", "this assignment attempt has already been submitted")
	case errors.Is(err, context.DeadlineExceeded):
		writeAPIError(w, http.StatusGatewayTimeout, "review_timeout", "assignment review timed out")
	case errors.Is(err, assignmentreview.ErrInvalidDecision):
		log.Printf("assignment review output rejected: %v", err)
		writeAPIError(w, http.StatusBadGateway, "invalid_review", "review could not be matched to the submitted work")
	case errors.Is(err, assignmentreview.ErrFeedbackStore):
		log.Print("assignment review feedback write failed")
		writeAPIError(w, http.StatusServiceUnavailable, "feedback_unavailable", "review feedback could not be saved")
	default:
		log.Printf("review assignment: %v", err)
		writeAPIError(w, http.StatusBadGateway, "review_failed", "assignment review failed")
	}
}
