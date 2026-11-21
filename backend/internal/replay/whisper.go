package replay

import (
	"bytes"
	"context"
	_ "embed"
	"errors"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"strconv"
)

//go:embed whisper.py
var whisperScript string

var ErrNoTranscript = errors.New("ไม่พบข้อความที่ถอดเสียงได้จากคลิป")

type Whisper struct {
	python string
	ffmpeg string
	model  string
	useGPU bool
}

func NewWhisper(python, model string, useGPU bool) (*Whisper, error) {
	if python == "" {
		python = "python3"
	}
	binary, err := exec.LookPath(python)
	if err != nil {
		return nil, fmt.Errorf("find Whisper Python: %w", err)
	}
	ffmpeg, err := exec.LookPath("ffmpeg")
	if err != nil {
		return nil, fmt.Errorf("find ffmpeg: %w", err)
	}
	path, err := filepath.Abs(model)
	if err != nil {
		return nil, err
	}
	info, err := os.Stat(path)
	if err != nil || !info.Mode().IsRegular() {
		return nil, errors.New("REPLAY_WHISPER_MODEL must point to a local model file")
	}
	return &Whisper{python: binary, ffmpeg: ffmpeg, model: path, useGPU: useGPU}, nil
}

func (w *Whisper) Transcribe(ctx context.Context, video string, durationMS int) ([]Segment, error) {
	ctx, cancel := context.WithTimeout(ctx, transcriptionLimit)
	defer cancel()

	dir, err := os.MkdirTemp("", "promptlearn-whisper-")
	if err != nil {
		return nil, err
	}
	defer os.RemoveAll(dir)
	audio := filepath.Join(dir, "audio.wav")
	extract := exec.CommandContext(ctx, w.ffmpeg, "-nostdin", "-v", "error", "-protocol_whitelist", "file",
		"-copyts", "-start_at_zero", "-i", video, "-map", "0:a:0", "-vn",
		"-af", "aresample=async=1:first_pts=0", "-ac", "1", "-ar", "16000", "-c:a", "pcm_s16le", audio)
	if err := extract.Run(); err != nil {
		if ctx.Err() != nil {
			return nil, ctx.Err()
		}
		return nil, fmt.Errorf("extract recording audio: %w", err)
	}

	command := exec.CommandContext(ctx, w.python, "-c", whisperScript, w.model, audio, strconv.Itoa(durationMS), strconv.FormatBool(w.useGPU))
	output, err := command.Output()
	if err != nil {
		if ctx.Err() != nil {
			return nil, ctx.Err()
		}
		return nil, fmt.Errorf("run local Whisper: %w", err)
	}
	if bytes.Equal(bytes.TrimSpace(output), []byte("[]")) {
		return nil, ErrNoTranscript
	}
	segments, err := ParseTranscript(bytes.NewReader(output), durationMS)
	if err != nil {
		return nil, fmt.Errorf("invalid transcript from Whisper: %w", err)
	}
	return segments, nil
}
