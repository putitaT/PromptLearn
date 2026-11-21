package httpapi

import (
	"bytes"
	"context"
	"encoding/base64"
	"encoding/json"
	"image"
	"image/png"
	"net/http"
	"net/http/httptest"
	"os"
	"path/filepath"
	"strings"
	"testing"

	"github.com/opsst/PromptLearn/backend/internal/assignmentreview"
)

type paperOCRFunc func(context.Context, string) ([]assignmentreview.Block, error)

func (f paperOCRFunc) ReadPaper(ctx context.Context, image string) ([]assignmentreview.Block, error) {
	return f(ctx, image)
}

func TestHomeworkNotebookImageOnlyReturnsAndSavesTheRecognizedRegion(t *testing.T) {
	var imageBytes bytes.Buffer
	if err := png.Encode(&imageBytes, image.NewGray(image.Rect(0, 0, 32, 32))); err != nil {
		t.Fatal(err)
	}
	dataURL := "data:image/png;base64," + base64.StdEncoding.EncodeToString(imageBytes.Bytes())
	box := assignmentreview.Box{X: 0.2, Y: 0.4, Width: 0.3, Height: 0.12}
	ocr := paperOCRFunc(func(_ context.Context, image string) ([]assignmentreview.Block, error) {
		if image != dataURL {
			t.Fatal("OCR must receive the entire uploaded image")
		}
		return []assignmentreview.Block{{ID: "line-2", Text: "x^(2*3)=x^6", Box: box}}, nil
	})
	dir := t.TempDir()
	repo, err := assignmentreview.OpenDemoRepository(dir, "mock")
	if err != nil {
		t.Fatal(err)
	}
	service := assignmentreview.NewService(repo, assignmentreview.DemoReviewer{}, ocr)
	handler := NewHandler(nil, nil, WithAssignmentReview(service))
	body, err := json.Marshal(map[string]string{"image_data_url": dataURL, "language": "en"})
	if err != nil {
		t.Fatal(err)
	}
	req := httptest.NewRequest(http.MethodPost, "http://localhost/v1/assignments/hw-3-1/items/q1/reviews", bytes.NewReader(body))
	req.RemoteAddr = "127.0.0.1:1234"
	req.Header.Set("Content-Type", "application/json")
	res := httptest.NewRecorder()
	handler.ServeHTTP(res, req)
	if res.Code != http.StatusOK {
		t.Fatalf("status %d: %s", res.Code, res.Body)
	}
	var result assignmentreview.Result
	if err := json.NewDecoder(res.Body).Decode(&result); err != nil {
		t.Fatal(err)
	}
	if result.Status != assignmentreview.NeedsRevision || len(result.Issues) != 1 ||
		result.Issues[0].Box != box || result.Issues[0].Kind != assignmentreview.SameBasePowers {
		t.Fatalf("unexpected result: %+v", result)
	}
	saved, err := os.ReadFile(filepath.Join(dir, result.ReviewID+".json"))
	if err != nil || !bytes.Contains(saved, []byte("x^(2*3)=x^6")) || bytes.Contains(saved, []byte(dataURL)) {
		t.Fatalf("expected stored OCR evidence without image bytes: %v", err)
	}
}

func TestAssignmentReviewAcceptsPaperImageAndReturnsOCRBox(t *testing.T) {
	var imageBytes bytes.Buffer
	if err := png.Encode(&imageBytes, image.NewGray(image.Rect(0, 0, 32, 32))); err != nil {
		t.Fatal(err)
	}
	box := assignmentreview.Box{X: 0.1, Y: 0.2, Width: 0.45, Height: 0.09}
	work := assignmentreview.Submission{
		Text:           "(x^2)(x^5)\n=x^(2*5)\n=x^10",
		Blocks:         []assignmentreview.Block{{ID: "b2", Text: "=x^(2*5)", Box: box}},
		ImageDataURL:   "data:image/png;base64," + base64.StdEncoding.EncodeToString(imageBytes.Bytes()),
		FocusedBlockID: "b2",
	}
	body, err := json.Marshal(work)
	if err != nil {
		t.Fatal(err)
	}

	service := assignmentreview.NewService(openTestReviewRepo(t), assignmentreview.DemoReviewer{}, nil)
	handler := NewHandler(nil, nil, WithAssignmentReview(service))
	req := httptest.NewRequest(http.MethodPost, "http://localhost/v1/assignments/hw-3-2/items/q4/reviews", bytes.NewReader(body))
	req.RemoteAddr = "127.0.0.1:1234"
	req.Header.Set("Content-Type", "application/json")
	res := httptest.NewRecorder()
	handler.ServeHTTP(res, req)
	if res.Code != http.StatusOK {
		t.Fatalf("status %d: %s", res.Code, res.Body)
	}

	var review assignmentreview.Result
	if err := json.NewDecoder(res.Body).Decode(&review); err != nil {
		t.Fatal(err)
	}
	if review.Status != assignmentreview.NeedsRevision || len(review.Issues) != 1 ||
		review.Issues[0].BlockID != "b2" || review.Issues[0].Box != box {
		t.Fatalf("unexpected data: %+v", review)
	}
}

func TestAssignmentReviewRejectsMissingOCRCoordinates(t *testing.T) {
	service := assignmentreview.NewService(openTestReviewRepo(t), assignmentreview.DemoReviewer{}, nil)
	handler := NewHandler(nil, nil, WithAssignmentReview(service))
	req := httptest.NewRequest(http.MethodPost, "http://localhost/v1/assignments/hw-3-2/items/q4/reviews",
		strings.NewReader(`{"text":"=x^(2*5)","blocks":[{"id":"b2","text":"=x^(2*5)","box":{"y":0.2,"width":0.45,"height":0.09}}]}`))
	req.RemoteAddr = "127.0.0.1:1234"
	req.Header.Set("Content-Type", "application/json")
	res := httptest.NewRecorder()
	handler.ServeHTTP(res, req)
	if res.Code != http.StatusBadRequest {
		t.Fatalf("status %d: %s", res.Code, res.Body)
	}
}

func openTestReviewRepo(t *testing.T) *assignmentreview.DemoRepository {
	t.Helper()
	repo, err := assignmentreview.OpenDemoRepository(t.TempDir(), "mock")
	if err != nil {
		t.Fatal(err)
	}
	return repo
}

func TestAssignmentReviewDemoRejectsNonLoopbackPeer(t *testing.T) {
	repo := openTestReviewRepo(t)
	service := assignmentreview.NewService(repo, assignmentreview.DemoReviewer{}, nil)
	handler := NewHandler(nil, nil, WithAssignmentReview(service))
	req := httptest.NewRequest(http.MethodPost, "http://localhost/v1/assignments/hw-3-2/items/q4/reviews",
		strings.NewReader(`{"text":"?"}`))
	req.RemoteAddr = "192.0.2.1:1234"
	req.Header.Set("Content-Type", "application/json")
	res := httptest.NewRecorder()
	handler.ServeHTTP(res, req)
	if res.Code != http.StatusForbidden {
		t.Fatalf("status %d: %s", res.Code, res.Body)
	}
}
