package httpapi

import (
	"bytes"
	"context"
	"encoding/json"
	"io"
	"mime/multipart"
	"net/http"
	"net/http/httptest"
	"os"
	"strings"
	"testing"

	"github.com/opsst/PromptLearn/backend/internal/replay"
)

type testTranscriber func(context.Context, string, int) ([]replay.Segment, error)

func (f testTranscriber) Transcribe(ctx context.Context, path string, duration int) ([]replay.Segment, error) {
	return f(ctx, path, duration)
}

func TestReplayPublication(t *testing.T) {
	databaseURL := os.Getenv("REPLAY_TEST_DATABASE_URL")
	if databaseURL == "" {
		t.Skip("set REPLAY_TEST_DATABASE_URL to a fresh database with schema.sql and demo_seed.sql applied")
	}
	store, err := replay.Open(t.Context(), databaseURL)
	if err != nil {
		t.Fatal(err)
	}
	defer store.Close()
	dir := t.TempDir()
	fixture, err := os.ReadFile("../../examples/thai-lesson.transcript.json")
	if err != nil {
		t.Fatal(err)
	}
	whisperCalls := 0
	whisper := testTranscriber(func(_ context.Context, path string, duration int) ([]replay.Segment, error) {
		whisperCalls++
		if _, err := os.Stat(path); err != nil {
			t.Fatal(err)
		}
		if whisperCalls == 1 {
			return nil, replay.ErrNoTranscript
		}
		return replay.ParseTranscript(bytes.NewReader(fixture), duration)
	})
	handler := NewDemoHandler(nil, nil, store, whisper, dir, "")
	do := func(method, path, role, contentType string, body io.Reader) *httptest.ResponseRecorder {
		t.Helper()
		req := httptest.NewRequest(method, "http://localhost"+path, body)
		req.Header.Set("X-Demo-Role", role)
		req.Header.Set("Content-Type", contentType)
		rec := httptest.NewRecorder()
		handler.ServeHTTP(rec, req)
		return rec
	}
	check := func(rec *httptest.ResponseRecorder, status int) {
		t.Helper()
		if rec.Code != status {
			t.Fatalf("status = %d, want %d: %s", rec.Code, status, rec.Body)
		}
	}
	upload := func(transcript []byte) *httptest.ResponseRecorder {
		t.Helper()
		video, err := os.ReadFile("../../examples/thai-lesson.mp4")
		if err != nil {
			t.Fatal(err)
		}
		var body bytes.Buffer
		form := multipart.NewWriter(&body)
		for _, file := range []struct {
			field, name string
			content     []byte
		}{
			{"video", "lesson.mp4", video},
			{"transcript", "transcript.json", transcript},
		} {
			if file.content == nil {
				continue
			}
			part, err := form.CreateFormFile(file.field, file.name)
			if err != nil {
				t.Fatal(err)
			}
			if _, err := part.Write(file.content); err != nil {
				t.Fatal(err)
			}
		}
		if err := form.Close(); err != nil {
			t.Fatal(err)
		}
		return do("POST", "/api/demo/recordings", "teacher", form.FormDataContentType(), &body)
	}
	decode := func(rec *httptest.ResponseRecorder, dst any) {
		t.Helper()
		if err := json.Unmarshal(rec.Body.Bytes(), dst); err != nil {
			t.Fatal(err)
		}
	}

	status := do("GET", "/api/demo/replay", "student", "", nil)
	check(status, http.StatusOK)
	if !strings.Contains(status.Body.String(), `"published":false`) {
		t.Fatal("test database must start with an unpublished lesson")
	}
	check(do("POST", "/api/demo/recordings", "student", "", nil), http.StatusForbidden)
	check(upload([]byte(`[{"startMs":0,"endMs":9999999,"text":"เกินคลิป"}]`)), http.StatusBadRequest)
	check(upload(nil), http.StatusUnprocessableEntity)
	entries, err := os.ReadDir(dir)
	if err != nil || len(entries) != 0 {
		t.Fatalf("invalid upload left files: %v, %v", entries, err)
	}

	create := func(transcript []byte) string {
		t.Helper()
		rec := upload(transcript)
		check(rec, http.StatusCreated)
		var recording replay.Recording
		decode(rec, &recording)
		if recording.ID == "" {
			t.Fatal("missing recordingId")
		}
		return recording.ID
	}
	videoPath := func(id string) string { return "/api/demo/recordings/" + id + "/video" }
	publish := func(id string) {
		t.Helper()
		check(do("PUT", "/api/demo/publication", "teacher", "application/json",
			strings.NewReader(`{"recordingId":"`+id+`"}`)), http.StatusOK)
	}
	first := create(nil)
	check(do("GET", videoPath(first), "student", "", nil), http.StatusNotFound)
	previewPath := "/api/demo/recordings/" + first + "/preview"
	check(do("GET", previewPath, "student", "", nil), http.StatusForbidden)
	check(do("HEAD", previewPath, "", "", nil), http.StatusForbidden)
	preview := do("GET", previewPath, "teacher", "", nil)
	check(preview, http.StatusOK)
	video, err := os.ReadFile("../../examples/thai-lesson.mp4")
	if err != nil {
		t.Fatal(err)
	}
	if !bytes.Equal(preview.Body.Bytes(), video) || preview.Header().Get("Cache-Control") != "no-store" {
		t.Fatal("teacher preview must return the uploaded video with caching disabled")
	}
	publish(first)
	publish(first)

	rec := do("GET", "/api/demo/replay", "student", "", nil)
	check(rec, http.StatusOK)
	var published struct {
		Published bool   `json:"published"`
		VideoURL  string `json:"videoUrl"`
		replay.Recording
	}
	decode(rec, &published)
	if !published.Published || published.VideoURL != videoPath(first) ||
		published.ID != first || len(published.Transcript) < 3 {
		t.Fatalf("unexpected published lesson: %+v", published)
	}

	second := create(fixture)
	if whisperCalls != 2 {
		t.Fatalf("Whisper calls = %d, want 2 for two MP4-only requests", whisperCalls)
	}
	check(do("GET", videoPath(second), "student", "", nil), http.StatusNotFound)
	rangeReq := httptest.NewRequest("GET", "http://localhost"+videoPath(first), nil)
	rangeReq.Header.Set("Range", "bytes=50-89")
	rec = httptest.NewRecorder()
	handler.ServeHTTP(rec, rangeReq)
	check(rec, http.StatusPartialContent)
	if rec.Body.Len() != 40 || rec.Header().Get("Content-Type") != "video/mp4" {
		t.Fatalf("unexpected video range: %d (%s)", rec.Body.Len(), rec.Header().Get("Content-Type"))
	}
	publish(second)
	check(do("GET", videoPath(first), "student", "", nil), http.StatusNotFound)
	check(do("HEAD", videoPath(second), "student", "", nil), http.StatusOK)

}
