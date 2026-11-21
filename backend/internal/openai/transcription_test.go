package openai

import (
	"bytes"
	"io"
	"net/http"
	"net/http/httptest"
	"testing"
)

func TestTranscribeAudioSendsOnlyWAVAndModel(t *testing.T) {
	audio := []byte("sample PCM WAV")
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.Method != http.MethodPost || r.Header.Get("Authorization") != "Bearer test-key" {
			t.Error("unexpected method or authorization")
		}
		if err := r.ParseMultipartForm(1024); err != nil {
			t.Error(err)
			w.WriteHeader(http.StatusBadRequest)
			return
		}
		if r.FormValue("model") != "gpt-transcribe" || len(r.MultipartForm.Value) != 1 || len(r.MultipartForm.File) != 1 {
			t.Error("multipart contains unexpected fields")
		}
		file, header, err := r.FormFile("file")
		if err != nil {
			t.Error(err)
			w.WriteHeader(http.StatusBadRequest)
			return
		}
		defer file.Close()
		data, err := io.ReadAll(file)
		if err != nil || !bytes.Equal(data, audio) || header.Filename != "segment.wav" || header.Header.Get("Content-Type") != "audio/wav" {
			t.Errorf("unexpected audio part %q: %v", header.Filename, err)
		}
		_, _ = w.Write([]byte(`{"text":"  มีค่าเท่ากับ 27  ","languages":[{"code":"th"}]}`))
	}))
	defer server.Close()

	client := NewTranscriptionClient("test-key", server.Client())
	client.endpoint = server.URL
	got, err := client.TranscribeAudio(t.Context(), bytes.NewReader(audio))
	if err != nil || got != "มีค่าเท่ากับ 27" {
		t.Fatalf("TranscribeAudio = %q, %v", got, err)
	}
}
