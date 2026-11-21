package assignmentreview

import (
	"encoding/json"
	"image"
	"image/color"
	"image/draw"
	"os"
	"testing"
)

func TestInkBandsKeepAdjacentHandwrittenRowsSeparate(t *testing.T) {
	paper := image.NewGray(image.Rect(0, 0, 1600, 715))
	draw.Draw(paper, paper.Bounds(), image.White, image.Point{}, draw.Src)
	// Two full lines have a 14 px gap. Detached superscripts belong to
	// the second line, even though there is another small gap beneath them.
	first := image.Rect(314, 34, 763, 177)
	exponents := image.Rect(389, 191, 889, 243)
	second := image.Rect(358, 254, 856, 339)
	for _, rect := range []image.Rectangle{first, exponents, second} {
		draw.Draw(paper, rect, image.NewUniform(color.Gray{Y: 60}), image.Point{}, draw.Src)
	}
	bands := inkBands(paper)
	if len(bands) != 2 || bands[0] != first || bands[1] != exponents.Union(second) {
		t.Fatalf("expected two distinct rows including their superscripts, got %v", bands)
	}
}

func TestPaperLinesStayOnTheirOriginalRows(t *testing.T) {
	data, err := os.ReadFile("../../examples/assignment-review.json")
	if err != nil {
		t.Fatal(err)
	}
	var fixture Submission
	if err := json.Unmarshal(data, &fixture); err != nil {
		t.Fatal(err)
	}
	lines, err := extractPaperLines(fixture.ImageDataURL)
	if err != nil || len(lines) != len(fixture.Blocks) {
		t.Fatalf("expected three lines from the fixture, got %d: %v", len(lines), err)
	}
	for i, line := range lines {
		box := fixture.Blocks[i].Box
		middle := box.Y + box.Height/2
		if !validBox(line.box) || middle < line.box.Y || middle > line.box.Y+line.box.Height {
			t.Fatalf("line %d does not cover the source row: %+v (fixture %+v)", i+1, line.box, box)
		}
	}
}
