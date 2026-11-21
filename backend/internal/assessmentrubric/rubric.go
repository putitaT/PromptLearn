package assessmentrubric

import (
	"context"
	"errors"
	"fmt"
	"math"
	"strings"
)

var (
	ErrInvalidInput = errors.New("invalid rubric request")
	ErrInvalidDraft = errors.New("invalid generated rubric")
)

type Lesson struct {
	Title string   `json:"title"`
	Steps []string `json:"steps"`
}

type Question struct {
	Kind    string   `json:"kind"`
	Prompt  string   `json:"prompt"`
	Points  int      `json:"points"`
	Options []string `json:"options,omitempty"`
}

type Request struct {
	Lesson         Lesson   `json:"lesson"`
	Question       Question `json:"question"`
	TeacherRequest string   `json:"teacher_request,omitempty"`
	Previous       *Draft   `json:"previous,omitempty"`
}

type Criterion struct {
	Name               string   `json:"name"`
	Description        string   `json:"description"`
	FullPoints         float64  `json:"full_points"`
	FullDescription    string   `json:"full_description"`
	PartialPoints      *float64 `json:"partial_points"`
	PartialDescription string   `json:"partial_description"`
	NoneDescription    string   `json:"none_description"`
}

type Mistake struct {
	Example string `json:"example"`
	Reason  string `json:"reason"`
}

type Draft struct {
	Answer          string      `json:"answer"`
	CorrectOption   *int        `json:"correct_option"`
	Alignment       string      `json:"alignment"`
	AlignmentReason string      `json:"alignment_reason"`
	Criteria        []Criterion `json:"criteria"`
	Mistakes        []Mistake   `json:"mistakes"`
	Note            string      `json:"note"`
}

type Generator interface {
	Generate(context.Context, Request) (Draft, error)
}

func (r Request) Validate() error {
	if strings.TrimSpace(r.Lesson.Title) == "" || len(r.Lesson.Steps) == 0 {
		return fmt.Errorf("%w: include the lesson title and steps", ErrInvalidInput)
	}
	for _, step := range r.Lesson.Steps {
		if strings.TrimSpace(step) == "" {
			return fmt.Errorf("%w: lesson steps cannot be empty", ErrInvalidInput)
		}
	}
	q := r.Question
	if strings.TrimSpace(q.Prompt) == "" || q.Points < 1 {
		return fmt.Errorf("%w: a question needs a prompt and positive points", ErrInvalidInput)
	}
	switch q.Kind {
	case "multipleChoice":
		if len(q.Options) < 2 || len(q.Options) > 4 {
			return fmt.Errorf("%w: multiple choice needs two to four options", ErrInvalidInput)
		}
		options := make(map[string]struct{}, len(q.Options))
		for _, option := range q.Options {
			option = strings.ToLower(strings.TrimSpace(option))
			if _, exists := options[option]; option == "" || exists {
				return fmt.Errorf("%w: options must be nonempty and distinct", ErrInvalidInput)
			}
			options[option] = struct{}{}
		}
	case "shortAnswer", "showWork", "trueFalse":
		if len(q.Options) != 0 {
			return fmt.Errorf("%w: only multiple choice accepts options", ErrInvalidInput)
		}
	default:
		return fmt.Errorf("%w: unsupported question type", ErrInvalidInput)
	}
	if r.Previous != nil && strings.TrimSpace(r.TeacherRequest) == "" {
		return fmt.Errorf("%w: describe the change to the existing rubric", ErrInvalidInput)
	}
	return nil
}

func (d Draft) Validate(q Question) error {
	switch d.Alignment {
	case "aligned":
	case "out_of_scope", "unclear":
		if strings.TrimSpace(d.AlignmentReason) == "" {
			return fmt.Errorf("%w: missing alignment reason", ErrInvalidDraft)
		}
	default:
		return fmt.Errorf("%w: unsupported alignment", ErrInvalidDraft)
	}

	if d.CorrectOption != nil {
		count := len(q.Options)
		if q.Kind == "trueFalse" {
			count = 2
		}
		if *d.CorrectOption < 0 || *d.CorrectOption >= count {
			return fmt.Errorf("%w: option is outside the question choices", ErrInvalidDraft)
		}
	}
	if q.Kind != "showWork" && len(d.Criteria) != 0 {
		return fmt.Errorf("%w: only show-work questions have scoring criteria", ErrInvalidDraft)
	}
	if q.Kind == "showWork" && strings.TrimSpace(d.Answer) != "" && len(d.Criteria) == 0 {
		return fmt.Errorf("%w: show-work answer needs scoring criteria", ErrInvalidDraft)
	}
	if len(d.Criteria) > 6 || len(d.Mistakes) > 4 {
		return fmt.Errorf("%w: too many criteria or mistakes", ErrInvalidDraft)
	}
	if len(d.Criteria) > 0 {
		var full float64
		for _, row := range d.Criteria {
			if strings.TrimSpace(row.Name) == "" || row.FullPoints <= 0 || row.FullPoints > float64(q.Points) ||
				(row.PartialPoints != nil && (*row.PartialPoints < 0 || *row.PartialPoints > row.FullPoints)) {
				return fmt.Errorf("%w: invalid scoring criterion", ErrInvalidDraft)
			}
			full += row.FullPoints
		}
		if math.Abs(full-float64(q.Points)) > 0.000001 {
			return fmt.Errorf("%w: full credit must total the question points", ErrInvalidDraft)
		}
	}
	for _, mistake := range d.Mistakes {
		if strings.TrimSpace(mistake.Example) == "" || strings.TrimSpace(mistake.Reason) == "" {
			return fmt.Errorf("%w: mistake needs an example and a reason", ErrInvalidDraft)
		}
	}
	return nil
}
