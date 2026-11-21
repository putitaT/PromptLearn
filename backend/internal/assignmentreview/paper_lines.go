package assignmentreview

import (
	"bytes"
	"encoding/base64"
	"fmt"
	"image"
	"image/color"
	"image/draw"
	"image/png"
	"strings"
)

type paperLine struct {
	box          Box
	imageDataURL string
}

// extractPaperLines uses the notebook's dark ink on a light background.
// Coordinates are measured on the original raster before adding OCR padding.
func extractPaperLines(dataURL string) ([]paperLine, error) {
	_, encoded, _ := strings.Cut(dataURL, ",")
	content, err := base64.StdEncoding.DecodeString(encoded)
	if err != nil {
		return nil, fmt.Errorf("%w: invalid paper image data", ErrInvalidInput)
	}
	img, _, err := image.Decode(bytes.NewReader(content))
	if err != nil {
		return nil, fmt.Errorf("%w: could not decode paper image", ErrInvalidInput)
	}
	page := img.Bounds()
	bands := inkBands(img)
	const maxBands = 20
	if len(bands) > maxBands {
		return nil, nil
	}
	lines := make([]paperLine, 0, len(bands))
	for _, band := range bands {
		if band.Dy() > page.Dy()*2/3 {
			return nil, nil
		}
		box := band.Inset(-2).Intersect(page)
		// Keep small strokes readable and add whitespace around clipped ink.
		const padding = 8
		crop := image.NewRGBA(image.Rect(0, 0, box.Dx()+2*padding, box.Dy()+2*padding))
		draw.Draw(crop, crop.Bounds(), image.White, image.Point{}, draw.Src)
		draw.Draw(crop, crop.Bounds().Inset(padding), img, box.Min, draw.Over)
		var buffer bytes.Buffer
		if err := png.Encode(&buffer, crop); err != nil {
			return nil, err
		}
		lines = append(lines, paperLine{
			box: Box{
				X:      float64(box.Min.X-page.Min.X) / float64(page.Dx()),
				Y:      float64(box.Min.Y-page.Min.Y) / float64(page.Dy()),
				Width:  float64(box.Dx()) / float64(page.Dx()),
				Height: float64(box.Dy()) / float64(page.Dy()),
			},
			imageDataURL: "data:image/png;base64," + base64.StdEncoding.EncodeToString(buffer.Bytes()),
		})
	}
	return lines, nil
}

func inkBands(img image.Image) []image.Rectangle {
	bounds := img.Bounds()
	strokeGap := max(1, bounds.Dy()/180)
	var bands []image.Rectangle
	for y := bounds.Min.Y; y < bounds.Max.Y; y++ {
		left, right := bounds.Max.X, bounds.Min.X
		for x := bounds.Min.X; x < bounds.Max.X; x++ {
			// The grid dots and the highlighter are lighter than the pen.
			if color.GrayModel.Convert(img.At(x, y)).(color.Gray).Y < 150 {
				left = min(left, x)
				right = x + 1
			}
		}
		if left >= right {
			continue
		}
		row := image.Rect(left, y, right, y+1)
		last := len(bands) - 1
		if last >= 0 && y-bands[last].Max.Y <= strokeGap {
			bands[last] = bands[last].Union(row)
		} else {
			bands = append(bands, row)
		}
	}
	return joinInkFragments(bands, max(3, bounds.Dy()/50))
}

func joinInkFragments(bands []image.Rectangle, maxGap int) []image.Rectangle {
	lines := make([]image.Rectangle, 0, len(bands))
	for index, band := range bands {
		last := len(lines) - 1
		if last >= 0 {
			above := lines[last]
			gap := band.Min.Y - above.Max.Y
			if gap <= maxGap && (isShortFragment(band, above) || isShortFragment(above, band)) {
				// Detached superscripts can sit between two rows. Attach the
				// shorter fragment to the closer row, preferring the one below on a tie.
				if index+1 < len(bands) && isShortFragment(band, above) {
					below := bands[index+1]
					if isShortFragment(band, below) && below.Min.Y-band.Max.Y <= gap {
						lines = append(lines, band)
						continue
					}
				}
				lines[last] = above.Union(band)
				continue
			}
		}
		lines = append(lines, band)
	}
	return lines
}

func isShortFragment(fragment, row image.Rectangle) bool {
	return fragment.Dy()*3 <= row.Dy()*2
}
