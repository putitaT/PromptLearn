package replay

import (
	"reflect"
	"testing"
)

func TestSplitAudioAtPauses(t *testing.T) {
	log := `[silencedetect] silence_start: 1.897
[silencedetect] silence_end: 2.423 | silence_duration: 0.526
[silencedetect] silence_start: 3.742
[silencedetect] silence_end: 4.057 | silence_duration: 0.315
[silencedetect] silence_start: 5.562
[silencedetect] silence_end: 5.987 | silence_duration: 0.425
[silencedetect] silence_start: 7.875
[silencedetect] silence_end: 8.635 | silence_duration: 0.760`
	want := []Segment{
		{StartMS: 0, EndMS: 2160},
		{StartMS: 2160, EndMS: 5774},
		{StartMS: 5774, EndMS: 8635},
	}
	if got := splitAudio(8635, detectedSilences(log)); !reflect.DeepEqual(got, want) {
		t.Fatalf("splitAudio = %+v, want %+v", got, want)
	}
}

func TestSplitAudioAvoidsOversizedAndSilentRequests(t *testing.T) {
	want := []Segment{
		{StartMS: 0, EndMS: 30000},
		{StartMS: 30000, EndMS: 60000},
		{StartMS: 60000, EndMS: 65000},
	}
	if got := splitAudio(65000, nil); !reflect.DeepEqual(got, want) {
		t.Fatalf("splitAudio without pauses = %+v, want %+v", got, want)
	}
	if got := splitAudio(4000, []silenceRange{{start: 0, end: 4000}}); len(got) != 0 {
		t.Fatalf("silent clip produced segments: %+v", got)
	}
}
