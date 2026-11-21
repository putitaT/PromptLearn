package assessmentrubric

import (
	"context"
	"encoding/json"
	"errors"
	"testing"

	"github.com/opsst/PromptLearn/backend/internal/openai"
)

type generateJSONFunc func(context.Context, openai.JSONRequest) (json.RawMessage, error)

func (f generateJSONFunc) GenerateJSON(ctx context.Context, req openai.JSONRequest) (json.RawMessage, error) {
	return f(ctx, req)
}

func TestDraftShowWork(t *testing.T) {
	question := Question{Kind: "showWork", Prompt: "Simplify (x²)(x⁵). Show each step.", Points: 1}
	lesson := Lesson{Title: "Multiplying powers", Steps: []string{"Expand powers and look for a pattern."}}
	for _, tc := range []struct {
		name    string
		method  string
		partial string
		wantErr error
	}{
		{name: "valid draft", method: "0.5", partial: "0.25"},
		{name: "wrong total", method: "0.4", partial: "0.25", wantErr: ErrInvalidDraft},
		{name: "too much partial credit", method: "0.5", partial: "0.75", wantErr: ErrInvalidDraft},
	} {
		t.Run(tc.name, func(t *testing.T) {
			generator := OpenAIGenerator{Client: generateJSONFunc(func(_ context.Context, req openai.JSONRequest) (json.RawMessage, error) {
				var input Request
				if err := json.Unmarshal([]byte(req.Input), &input); err != nil {
					t.Fatal(err)
				}
				if req.SchemaName != "assessment_answer_rubric" || !json.Valid(req.Schema) ||
					input.Lesson.Title != lesson.Title || len(input.Lesson.Steps) != 1 ||
					input.Question.Prompt != question.Prompt {
					t.Fatalf("incorrect OpenAI request: %+v", input)
				}
				return json.RawMessage(`{
					"answer":"(x²)(x⁵) = x²⁺⁵ = x⁷",
					"alignment":"aligned",
					"criteria":[{"name":"Method","full_points":` + tc.method +
					`,"partial_points":` + tc.partial + `},{"name":"Answer","full_points":0.5}],
					"mistakes":[{"example":"x¹⁰","reason":"Multiplied exponents"}]
				}`), nil
			})}
			result, err := generator.Generate(context.Background(), Request{Lesson: lesson, Question: question})
			if !errors.Is(err, tc.wantErr) {
				t.Fatalf("Generate() returned %v, want %v", err, tc.wantErr)
			}
			if err == nil && (result.Alignment != "aligned" || len(result.Criteria) != 2 || len(result.Mistakes) != 1) {
				t.Fatalf("unexpected draft: %+v", result)
			}
		})
	}
}

func TestShortAnswerIgnoresExtraCriteria(t *testing.T) {
	generator := OpenAIGenerator{Client: generateJSONFunc(func(_ context.Context, _ openai.JSONRequest) (json.RawMessage, error) {
		return json.RawMessage(`{
			"answer":"2⁷",
			"correct_option":null,
			"alignment":"aligned",
			"alignment_reason":"",
			"criteria":[{"name":"Answer","full_points":1}],
			"mistakes":[{"example":"2¹²","reason":"Multiplied the exponents"}],
			"note":"Accept one power."
		}`), nil
	})}
	draft, err := generator.Generate(context.Background(), Request{
		Lesson:   Lesson{Title: "Multiplying powers", Steps: []string{"Add the exponents."}},
		Question: Question{Kind: "shortAnswer", Prompt: "Simplify 2³ × 2⁴.", Points: 1},
	})
	if err != nil || draft.Answer != "2⁷" || draft.Criteria == nil || len(draft.Criteria) != 0 || len(draft.Mistakes) != 1 {
		t.Fatalf("expected the answer and mistakes without scoring rows, got %+v, %v", draft, err)
	}
}
