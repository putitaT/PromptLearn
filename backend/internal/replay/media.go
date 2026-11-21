package replay

import (
	"context"
	"encoding/json"
	"errors"
	"io"
	"math"
	"os/exec"
	"strconv"
	"strings"
	"time"
)

const (
	MaxVideoBytes      = 50_000_000
	MaxTranscriptBytes = 256 << 10
)

type Transcriber interface {
	Transcribe(context.Context, string, int) ([]Segment, error)
}

var ErrInvalidVideo = errors.New("เลือกไฟล์ MP4 ที่ใช้วิดีโอ H.264 และเสียง AAC")
var ErrInvalidTranscript = errors.New("ตรวจ transcript ให้มีข้อความและเวลาที่เรียงตามลำดับและอยู่ในช่วงคลิป")

type Media struct {
	DurationMS int
	HasAudio   bool
}

func Probe(ctx context.Context, path string) (Media, error) {
	ctx, cancel := context.WithTimeout(ctx, 10*time.Second)
	defer cancel()
	output, err := exec.CommandContext(ctx, "ffprobe", "-v", "error", "-protocol_whitelist", "file",
		"-f", "mov", "-show_entries", "format=duration:format_tags=major_brand:stream=codec_name,codec_type",
		"-of", "json", path).Output()
	if err != nil {
		return Media{}, ErrInvalidVideo
	}
	var info struct {
		Format struct {
			Duration string
			Tags     struct {
				MajorBrand string `json:"major_brand"`
			}
		}
		Streams []struct {
			Codec string `json:"codec_name"`
			Type  string `json:"codec_type"`
		}
	}
	if err := json.Unmarshal(output, &info); err != nil {
		return Media{}, ErrInvalidVideo
	}
	seconds, err := strconv.ParseFloat(info.Format.Duration, 64)
	duration := math.Ceil(seconds * 1000)
	if err != nil || math.IsNaN(duration) || duration <= 0 || duration > math.MaxInt32 ||
		info.Format.Tags.MajorBrand == "" || info.Format.Tags.MajorBrand == "qt  " {
		return Media{}, ErrInvalidVideo
	}
	var hasVideo, hasAudio bool
	for _, stream := range info.Streams {
		switch stream.Type {
		case "video":
			if stream.Codec != "h264" {
				return Media{}, ErrInvalidVideo
			}
			hasVideo = true
		case "audio":
			if stream.Codec != "aac" {
				return Media{}, ErrInvalidVideo
			}
			hasAudio = true
		}
	}
	if !hasVideo {
		return Media{}, ErrInvalidVideo
	}
	return Media{DurationMS: int(duration), HasAudio: hasAudio}, nil
}

func ParseTranscript(r io.Reader, duration int) ([]Segment, error) {
	var input []struct {
		StartMS *int   `json:"startMs"`
		EndMS   *int   `json:"endMs"`
		Text    string `json:"text"`
	}
	decoder := json.NewDecoder(r)
	decoder.DisallowUnknownFields()
	if err := decoder.Decode(&input); err != nil || len(input) == 0 {
		return nil, ErrInvalidTranscript
	}
	if err := decoder.Decode(new(any)); err != io.EOF {
		return nil, ErrInvalidTranscript
	}
	segments := make([]Segment, 0, len(input))
	previousStart := -1
	for _, cue := range input {
		text := strings.TrimSpace(cue.Text)
		if cue.StartMS == nil || cue.EndMS == nil || text == "" ||
			*cue.StartMS <= previousStart || *cue.EndMS <= *cue.StartMS || *cue.EndMS > duration {
			return nil, ErrInvalidTranscript
		}
		segments = append(segments, Segment{StartMS: *cue.StartMS, EndMS: *cue.EndMS, Text: text})
		previousStart = *cue.StartMS
	}
	return segments, nil
}
