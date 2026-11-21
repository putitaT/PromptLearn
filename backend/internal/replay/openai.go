package replay

import (
	"bytes"
	"context"
	"encoding/binary"
	"errors"
	"fmt"
	"io"
	"math"
	"os"
	"os/exec"
	"path/filepath"
	"regexp"
	"strconv"
	"time"

	"golang.org/x/sync/errgroup"
)

const (
	audioSampleRate    = 16_000
	audioBytesPerMS    = audioSampleRate * 2 / 1000
	minAudioSegmentMS  = 2_000
	maxAudioSegmentMS  = 30_000
	transcriptionLimit = 2 * time.Minute
)

var ErrAudioProvider = errors.New("OpenAI transcription request failed")

type audioTranscriptionClient interface {
	TranscribeAudio(context.Context, io.Reader) (string, error)
}

type OpenAITranscriber struct {
	ffmpeg string
	client audioTranscriptionClient
}

func NewOpenAITranscriber(client audioTranscriptionClient) (*OpenAITranscriber, error) {
	ffmpeg, err := exec.LookPath("ffmpeg")
	if err != nil {
		return nil, fmt.Errorf("find ffmpeg: %w", err)
	}
	return &OpenAITranscriber{ffmpeg: ffmpeg, client: client}, nil
}

func (t *OpenAITranscriber) Transcribe(ctx context.Context, video string, durationMS int) ([]Segment, error) {
	ctx, cancel := context.WithTimeout(ctx, transcriptionLimit)
	defer cancel()

	dir, err := os.MkdirTemp("", "promptlearn-audio-")
	if err != nil {
		return nil, err
	}
	defer os.RemoveAll(dir)
	path := filepath.Join(dir, "audio.pcm")
	var log bytes.Buffer
	extract := exec.CommandContext(ctx, t.ffmpeg, "-nostdin", "-hide_banner", "-nostats", "-v", "info",
		"-protocol_whitelist", "file", "-copyts", "-start_at_zero", "-i", video, "-map", "0:a:0", "-vn",
		"-af", "aresample=16000:async=1:min_hard_comp=0.001:first_pts=0,aformat=sample_fmts=s16:channel_layouts=mono,silencedetect=noise=-32dB:d=0.2",
		"-f", "s16le", path)
	extract.Stderr = &log
	if err := extract.Run(); err != nil {
		if ctx.Err() != nil {
			return nil, ctx.Err()
		}
		return nil, fmt.Errorf("extract recording audio: %w", err)
	}

	audio, err := os.Open(path)
	if err != nil {
		return nil, err
	}
	defer audio.Close()
	stat, err := audio.Stat()
	if err != nil {
		return nil, err
	}
	audioMS := int((stat.Size() + audioBytesPerMS - 1) / audioBytesPerMS)
	audioMS = min(audioMS, durationMS)
	segments := splitAudio(audioMS, detectedSilences(log.String()))
	group, groupCtx := errgroup.WithContext(ctx)
	group.SetLimit(3)
	for i := range segments {
		group.Go(func() error {
			if err := groupCtx.Err(); err != nil {
				return err
			}
			cue := &segments[i]
			offset := int64(cue.StartMS) * audioBytesPerMS
			size := min(int64(cue.EndMS)*audioBytesPerMS, stat.Size()) - offset
			reader := io.MultiReader(bytes.NewReader(wavHeader(uint32(size))), io.NewSectionReader(audio, offset, size))
			text, err := t.client.TranscribeAudio(groupCtx, reader)
			if err != nil {
				if ctx.Err() != nil {
					return ctx.Err()
				}
				return fmt.Errorf("%w: %v", ErrAudioProvider, err)
			}
			cue.Text = text
			return nil
		})
	}
	if err := group.Wait(); err != nil {
		return nil, err
	}
	nonempty := segments[:0]
	for _, cue := range segments {
		if cue.Text != "" {
			nonempty = append(nonempty, cue)
		}
	}
	if len(nonempty) == 0 {
		return nil, ErrNoTranscript
	}
	return nonempty, nil
}

type silenceRange struct{ start, end int }

var silenceEvent = regexp.MustCompile(`silence_(start|end): (-?[0-9]+(?:\.[0-9]+)?)`)

func detectedSilences(log string) []silenceRange {
	var pauses []silenceRange
	start := -1
	for _, match := range silenceEvent.FindAllStringSubmatch(log, -1) {
		seconds, err := strconv.ParseFloat(match[2], 64)
		if err != nil {
			continue
		}
		millis := max(0, int(math.Round(seconds*1000)))
		if match[1] == "start" {
			start = millis
		} else if start >= 0 {
			pauses = append(pauses, silenceRange{start: start, end: millis})
			start = -1
		}
	}
	return pauses
}

func splitAudio(duration int, pauses []silenceRange) []Segment {
	var cues []Segment
	// A silent track should not be sent for transcription.
	if len(pauses) == 1 && pauses[0].start == 0 && pauses[0].end >= duration-1 {
		return nil
	}
	for start, pause := 0, 0; start < duration; {
		end := min(start+maxAudioSegmentMS, duration)
		for pause < len(pauses) {
			gap := pauses[pause]
			midpoint := gap.start + (gap.end-gap.start)/2
			if midpoint > end {
				break
			}
			pause++
			if midpoint-start >= minAudioSegmentMS && duration-midpoint >= minAudioSegmentMS {
				end = midpoint
				break
			}
		}
		cues = append(cues, Segment{StartMS: start, EndMS: end})
		start = end
	}
	return cues
}

func wavHeader(size uint32) []byte {
	header := make([]byte, 44)
	copy(header, "RIFF")
	binary.LittleEndian.PutUint32(header[4:], size+36)
	copy(header[8:], "WAVEfmt ")
	binary.LittleEndian.PutUint32(header[16:], 16)
	binary.LittleEndian.PutUint16(header[20:], 1) // PCM
	binary.LittleEndian.PutUint16(header[22:], 1) // mono
	binary.LittleEndian.PutUint32(header[24:], audioSampleRate)
	binary.LittleEndian.PutUint32(header[28:], audioSampleRate*2)
	binary.LittleEndian.PutUint16(header[32:], 2) // bytes per sample
	binary.LittleEndian.PutUint16(header[34:], 16)
	copy(header[36:], "data")
	binary.LittleEndian.PutUint32(header[40:], size)
	return header
}
