package assignmentreview

import (
	"context"
	"encoding/json"
	"errors"
	"os"
	"path/filepath"
	"strings"
	"testing"
)

type reviewerFunc func(context.Context, Question, Submission) (Decision, error)

func (f reviewerFunc) Review(ctx context.Context, question Question, work Submission) (Decision, error) {
	return f(ctx, question, work)
}

func demoWork() Submission {
	return Submission{
		Text: "(x^2)(x^5)\n=x^(2*5)\n=x^10",
		Blocks: []Block{
			{ID: "line-1", Text: "(x^2)(x^5)", Box: Box{X: 0.1, Y: 0.1, Width: 0.4, Height: 0.08}},
			{ID: "line-2", Text: "=x^(2*5)", Box: Box{X: 0.1, Y: 0.25, Width: 0.25, Height: 0.08}},
			{ID: "line-3", Text: "=x^10", Box: Box{X: 0.1, Y: 0.4, Width: 0.2, Height: 0.08}},
		},
	}
}

func TestReviewReturnsOriginalOCRBoxWithGuidingQuestion(t *testing.T) {
	work := demoWork()
	service := NewService(openTestDemo(t), DemoReviewer{}, nil)
	review, err := service.Review(context.Background(), DemoAssignmentID, DemoItemID, work)
	if err != nil {
		t.Fatal(err)
	}
	if review.Status != NeedsRevision || len(review.Issues) != 1 {
		t.Fatalf("unexpected result: %+v", review)
	}
	issue := review.Issues[0]
	if issue.BlockID != "line-2" || issue.Box != work.Blocks[1].Box || !strings.Contains(issue.Hint, "repeated multiplication") {
		t.Fatalf("wrong location or guiding question: %+v", issue)
	}
	if strings.Contains(issue.Hint, "x^7") {
		t.Fatalf("hint revealed the answer: %s", issue.Hint)
	}
}

func TestReviewCorrectWorkReturnsNoHighlights(t *testing.T) {
	work := demoWork()
	work.Blocks[1].Text, work.Blocks[2].Text = "=x^(2+5)", "=x^7"
	work.Text = "(x^2)(x^5)\n=x^(2+5)\n=x^7"
	review, err := NewService(openTestDemo(t), DemoReviewer{}, nil).Review(context.Background(), DemoAssignmentID, DemoItemID, work)
	if err != nil {
		t.Fatal(err)
	}
	if review.Status != Correct || review.Issues == nil || len(review.Issues) != 0 {
		t.Fatalf("expected correct work with an empty issues array, got %+v", review)
	}
}

func TestReviewRefusesUnanchoredModelFinding(t *testing.T) {
	reviewer := reviewerFunc(func(context.Context, Question, Submission) (Decision, error) {
		return Decision{Status: NeedsRevision, Findings: []Finding{{BlockID: "invented", Kind: SameBasePowers}}}, nil
	})
	_, err := NewService(openTestDemo(t), reviewer, nil).Review(context.Background(), DemoAssignmentID, DemoItemID, demoWork())
	if !errors.Is(err, ErrInvalidDecision) {
		t.Fatalf("expected invalid model decision, got %v", err)
	}
}

func TestReviewSkipsModelForInvalidBoxOrUnknownItem(t *testing.T) {
	service := NewService(openTestDemo(t), reviewerFunc(func(context.Context, Question, Submission) (Decision, error) {
		t.Fatal("invalid request should not reach the reviewer")
		return Decision{}, nil
	}), nil)
	if _, err := service.Review(context.Background(), DemoAssignmentID, "other-question", demoWork()); !errors.Is(err, ErrNotFound) {
		t.Fatalf("expected unknown item, got %v", err)
	}
	work := demoWork()
	work.Blocks[1].Box.Width = 2
	if _, err := service.Review(context.Background(), DemoAssignmentID, DemoItemID, work); !errors.Is(err, ErrInvalidInput) {
		t.Fatalf("expected invalid coordinates, got %v", err)
	}
}

func TestReviewPersistsEveryOutcomeBeforeReturning(t *testing.T) {
	repo, err := OpenDemoRepository(t.TempDir(), "mock")
	if err != nil {
		t.Fatal(err)
	}
	service := NewService(repo, DemoReviewer{}, nil)
	first := demoWork()
	corrected := demoWork()
	corrected.Text = "(x^2)(x^5)\n=x^(2+5)\n=x^7"
	corrected.Blocks[1].Text = "=x^(2+5)"
	corrected.Blocks[2].Text = "=x^7"
	inputs := []Submission{first, corrected, {Text: "?"}}
	statuses := []Status{NeedsRevision, Correct, Unreadable}

	for i, work := range inputs {
		result, err := service.Review(context.Background(), DemoAssignmentID, DemoItemID, work)
		if err != nil {
			t.Fatal(err)
		}
		raw, err := os.ReadFile(filepath.Join(repo.dir, result.ReviewID+".json"))
		if err != nil {
			t.Fatalf("review %q was not written before the response: %v", result.ReviewID, err)
		}
		var event demoEvent
		if err := json.Unmarshal(raw, &event); err != nil {
			t.Fatal(err)
		}
		if event.StudentID != DemoStudentID || event.Result.Status != statuses[i] ||
			event.Result.ReviewID != result.ReviewID {
			t.Fatalf("feedback history does not match the review: %+v", event)
		}
	}
	items, err := os.ReadDir(repo.dir)
	if err != nil || len(items) != 3 {
		t.Fatalf("want three distinct feedback events, got %d: %v", len(items), err)
	}
}

func openTestDemo(t *testing.T) *DemoRepository {
	t.Helper()
	repo, err := OpenDemoRepository(t.TempDir(), "mock")
	if err != nil {
		t.Fatal(err)
	}
	return repo
}
