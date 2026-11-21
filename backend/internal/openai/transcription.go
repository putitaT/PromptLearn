package openai

import (
	"bytes"
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"mime/multipart"
	"net/http"
	"net/textproto"
	"strings"
)

type TranscriptionClient struct {
	key      string
	http     *http.Client
	endpoint string
}

func NewTranscriptionClient(key string, client *http.Client) *TranscriptionClient {
	return &TranscriptionClient{key: key, http: client, endpoint: "https://api.openai.com/v1/audio/transcriptions"}
}

func (c *TranscriptionClient) TranscribeAudio(ctx context.Context, audio io.Reader) (string, error) {
	var body bytes.Buffer
	form := multipart.NewWriter(&body)
	if err := form.WriteField("model", "gpt-transcribe"); err != nil {
		return "", err
	}
	header := make(textproto.MIMEHeader)
	header.Set("Content-Disposition", `form-data; name="file"; filename="segment.wav"`)
	header.Set("Content-Type", "audio/wav")
	part, err := form.CreatePart(header)
	if err != nil {
		return "", err
	}
	if _, err := io.Copy(part, audio); err != nil {
		return "", err
	}
	if err := form.Close(); err != nil {
		return "", err
	}

	req, err := http.NewRequestWithContext(ctx, http.MethodPost, c.endpoint, &body)
	if err != nil {
		return "", err
	}
	req.Header.Set("Authorization", "Bearer "+c.key)
	req.Header.Set("Content-Type", form.FormDataContentType())
	resp, err := c.http.Do(req)
	if err != nil {
		return "", err
	}
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusOK {
		return "", fmt.Errorf("OpenAI transcription returned HTTP %d", resp.StatusCode)
	}

	var result struct {
		Text *string `json:"text"`
	}
	if err := json.NewDecoder(io.LimitReader(resp.Body, maxResponseBytes)).Decode(&result); err != nil {
		return "", fmt.Errorf("decode OpenAI transcription: %w", err)
	}
	if result.Text == nil {
		return "", errors.New("OpenAI transcription response is missing text")
	}
	return strings.TrimSpace(*result.Text), nil
}
