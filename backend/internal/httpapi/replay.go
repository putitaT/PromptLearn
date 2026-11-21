package httpapi

import (
	"context"
	"errors"
	"io"
	"log"
	"net"
	"net/http"
	"os"
	"path/filepath"
	"strings"

	"github.com/opsst/PromptLearn/backend/internal/course"
	"github.com/opsst/PromptLearn/backend/internal/replay"
	"github.com/opsst/PromptLearn/backend/internal/syllabus"
)

// NewDemoHandler adds opt-in, local replay routes alongside the regular API.
func NewDemoHandler(syllabi *syllabus.Service, courses course.Repository, store *replay.Store, transcriber replay.Transcriber, mediaDir, webDir string, options ...RouterOption) http.Handler {
	mux := newRouter(syllabi, courses, options...)
	demo := replayDemo{store: store, transcriber: transcriber, mediaDir: mediaDir}
	mux.HandleFunc("POST /api/demo/recordings", demo.upload)
	mux.HandleFunc("PUT /api/demo/publication", demo.publish)
	mux.HandleFunc("GET /api/demo/replay", demo.published)
	mux.HandleFunc("GET /api/demo/recordings/{id}/video", demo.video)
	mux.HandleFunc("GET /api/demo/recordings/{id}/preview", demo.preview)
	if webDir != "" {
		mux.Handle("GET /", http.FileServer(http.Dir(webDir)))
	}
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		// A local address alone does not stop requests sent with a foreign Host.
		host := r.Host
		if name, _, err := net.SplitHostPort(host); err == nil {
			host = name
		}
		if !IsLoopbackHost(host) {
			writeAPIError(w, http.StatusForbidden, "forbidden", "เดโมเปิดได้จากเครื่องนี้เท่านั้น")
			return
		}
		mux.ServeHTTP(w, r)
	})
}

func IsLoopbackHost(host string) bool {
	return strings.EqualFold(host, "localhost") || net.ParseIP(host).IsLoopback()
}

type replayDemo struct {
	store       *replay.Store
	transcriber replay.Transcriber
	mediaDir    string
}

func (d replayDemo) upload(w http.ResponseWriter, r *http.Request) {
	if !demoTeacher(w, r) {
		return
	}
	r.Body = http.MaxBytesReader(w, r.Body, replay.MaxVideoBytes+replay.MaxTranscriptBytes+(64<<10))
	if err := r.ParseMultipartForm(1 << 20); err != nil {
		var limit *http.MaxBytesError
		if errors.As(err, &limit) {
			writeAPIError(w, http.StatusRequestEntityTooLarge, "request_too_large", "ขนาดไฟล์คลิปต้องไม่เกิน 50 MB")
		} else {
			writeAPIError(w, http.StatusBadRequest, "invalid_media", "เลือกไฟล์ MP4")
		}
		return
	}
	defer r.MultipartForm.RemoveAll()
	video, header, err := r.FormFile("video")
	if err != nil {
		writeAPIError(w, http.StatusBadRequest, "invalid_media", "เลือกไฟล์ MP4")
		return
	}
	defer video.Close()
	if !strings.EqualFold(filepath.Ext(header.Filename), ".mp4") {
		writeAPIError(w, http.StatusBadRequest, "invalid_media", replay.ErrInvalidVideo.Error())
		return
	}
	if header.Size > replay.MaxVideoBytes {
		writeAPIError(w, http.StatusRequestEntityTooLarge, "request_too_large", "ขนาดไฟล์คลิปต้องไม่เกิน 50 MB")
		return
	}
	file, err := os.CreateTemp(d.mediaDir, "recording-*.mp4")
	if err != nil {
		replayFailure(w, err)
		return
	}
	path := file.Name()
	keep := false
	defer func() {
		if !keep {
			_ = os.Remove(path)
		}
	}()
	size, copyErr := io.Copy(file, video)
	closeErr := file.Close()
	if err := errors.Join(copyErr, closeErr); err != nil {
		replayFailure(w, err)
		return
	}
	media, err := replay.Probe(r.Context(), path)
	if err != nil {
		writeAPIError(w, http.StatusBadRequest, "invalid_media", err.Error())
		return
	}
	segments, ok := d.transcript(w, r, path, media)
	if !ok {
		return
	}
	id, err := d.store.Save(r.Context(), filepath.Base(path), size, media.DurationMS, segments)
	if err != nil {
		replayFailure(w, err)
		return
	}
	keep = true
	writeJSON(w, http.StatusCreated, map[string]string{"recordingId": id})
}

func (d replayDemo) transcript(w http.ResponseWriter, r *http.Request, path string, media replay.Media) ([]replay.Segment, bool) {
	file, header, err := r.FormFile("transcript")
	if err == nil {
		defer file.Close()
		if header.Size > replay.MaxTranscriptBytes {
			writeAPIError(w, http.StatusRequestEntityTooLarge, "request_too_large", "ไฟล์ transcript ต้องไม่เกิน 256 KiB")
			return nil, false
		}
		segments, err := replay.ParseTranscript(file, media.DurationMS)
		if err != nil {
			writeAPIError(w, http.StatusBadRequest, "invalid_media", err.Error())
			return nil, false
		}
		return segments, true
	}
	if !errors.Is(err, http.ErrMissingFile) || len(r.MultipartForm.Value["transcript"]) > 0 {
		writeAPIError(w, http.StatusBadRequest, "invalid_media", "เลือกไฟล์ transcript JSON")
		return nil, false
	}
	if !media.HasAudio {
		writeAPIError(w, http.StatusUnprocessableEntity, "invalid_audio", "คลิปต้องมีแทร็กเสียงสำหรับถอดเสียง")
		return nil, false
	}
	if d.transcriber == nil {
		writeAPIError(w, http.StatusServiceUnavailable, "transcription_unavailable", "ยังไม่ได้ตั้งค่าบริการถอดเสียงบน backend")
		return nil, false
	}
	segments, err := d.transcriber.Transcribe(r.Context(), path, media.DurationMS)
	switch {
	case err == nil:
		return segments, true
	case errors.Is(err, replay.ErrNoTranscript):
		writeAPIError(w, http.StatusUnprocessableEntity, "invalid_audio", err.Error())
	case errors.Is(err, context.DeadlineExceeded):
		writeAPIError(w, http.StatusGatewayTimeout, "transcription_timeout", "ถอดเสียงเกินเวลา ลองใหม่อีกครั้ง")
	case errors.Is(err, replay.ErrAudioProvider):
		log.Printf("replay transcription: %v", err)
		writeAPIError(w, http.StatusBadGateway, "transcription_failed", "บริการถอดเสียงตอบกลับไม่สำเร็จ ลองใหม่อีกครั้ง")
	default:
		replayFailure(w, err)
	}
	return nil, false
}

func (d replayDemo) publish(w http.ResponseWriter, r *http.Request) {
	if !demoTeacher(w, r) {
		return
	}
	var input struct {
		RecordingID string `json:"recordingId"`
	}
	if !readJSONWithLimit(w, r, &input, 1024) {
		return
	}
	if input.RecordingID == "" {
		writeAPIError(w, http.StatusBadRequest, "invalid_media", "เลือกคลิปที่จะเผยแพร่")
		return
	}
	if err := d.store.Publish(r.Context(), input.RecordingID); err != nil {
		replayFailure(w, err)
		return
	}
	writeJSON(w, http.StatusOK, input)
}

func (d replayDemo) published(w http.ResponseWriter, r *http.Request) {
	recording, err := d.store.Published(r.Context())
	if err != nil {
		replayFailure(w, err)
		return
	}
	w.Header().Set("Cache-Control", "no-store")
	if recording == nil {
		writeJSON(w, http.StatusOK, map[string]bool{"published": false})
		return
	}
	writeJSON(w, http.StatusOK, struct {
		Published bool   `json:"published"`
		VideoURL  string `json:"videoUrl"`
		*replay.Recording
	}{true, "/api/demo/recordings/" + recording.ID + "/video", recording})
}

func (d replayDemo) video(w http.ResponseWriter, r *http.Request) {
	key, err := d.store.PublishedKey(r.Context(), r.PathValue("id"))
	d.serveVideo(w, r, key, err)
}

func (d replayDemo) preview(w http.ResponseWriter, r *http.Request) {
	if !demoTeacher(w, r) {
		return
	}
	key, err := d.store.PreviewKey(r.Context(), r.PathValue("id"))
	d.serveVideo(w, r, key, err)
}

func (d replayDemo) serveVideo(w http.ResponseWriter, r *http.Request, key string, err error) {
	w.Header().Set("Cache-Control", "no-store")
	if err != nil {
		replayFailure(w, err)
		return
	}
	if filepath.Base(key) != key || !strings.HasPrefix(key, "recording-") || filepath.Ext(key) != ".mp4" {
		replayFailure(w, replay.ErrNotFound)
		return
	}
	file, err := os.Open(filepath.Join(d.mediaDir, key))
	if errors.Is(err, os.ErrNotExist) {
		replayFailure(w, replay.ErrNotFound)
		return
	}
	if err != nil {
		replayFailure(w, err)
		return
	}
	defer file.Close()
	info, err := file.Stat()
	if err != nil {
		replayFailure(w, err)
		return
	}
	w.Header().Set("Content-Type", "video/mp4")
	http.ServeContent(w, r, key, info.ModTime(), file)
}

func demoTeacher(w http.ResponseWriter, r *http.Request) bool {
	if r.Header.Get("X-Demo-Role") == "teacher" {
		return true
	}
	writeAPIError(w, http.StatusForbidden, "forbidden", "เปิดมุมมองครูเพื่อจัดการคลิป")
	return false
}

func replayFailure(w http.ResponseWriter, err error) {
	if errors.Is(err, replay.ErrNotFound) {
		writeAPIError(w, http.StatusNotFound, "recording_not_found", "ไม่พบคลิป")
		return
	}
	log.Printf("replay demo: %v", err)
	writeAPIError(w, http.StatusInternalServerError, "replay_error", "จัดการคลิปไม่สำเร็จ ลองใหม่อีกครั้ง")
}
