package assignmentreview

import (
	"context"
	"errors"
	"os"
	"path/filepath"
	"slices"
	"testing"
)

func TestSubmissionFreezesAllQuestionsAndSavesMistakesSeparately(t *testing.T) {
	ctx := context.Background()
	repo := openTestDemo(t)
	service := NewService(repo, DemoReviewer{}, nil)
	itemIDs := []string{"q1", "q2", "q3", "q5"}
	ids := make([]string, len(itemIDs))
	work := demoWork()
	for i, itemID := range itemIDs {
		status := Correct
		var findings []Finding
		switch i {
		case 0:
			status = NeedsRevision
			findings = []Finding{{BlockID: "line-2", Kind: SameBasePowers}}
		case 2:
			status = Unreadable
		}
		result, err := buildResult(HomeworkAssignmentID, itemID, work, Decision{
			Status: status, Findings: findings,
		})
		if err != nil {
			t.Fatal(err)
		}
		ids[i], err = repo.SaveReview(ctx, work, result)
		if err != nil {
			t.Fatal(err)
		}
	}

	report, err := service.Submit(ctx, HomeworkAssignmentID, ids)
	if err != nil {
		t.Fatal(err)
	}
	if report.Points != 2 || report.MaxPoints != 4 || report.Pending != 1 || len(report.Questions) != 4 {
		t.Fatalf("unexpected totals: %+v", report)
	}
	if report.Questions[2].AwardedPoints != nil ||
		report.Questions[0].AwardedPoints == nil || *report.Questions[0].AwardedPoints != 0 ||
		report.Questions[0].RecognizedWork != work.Text ||
		report.Questions[3].Position != 4 || report.Questions[3].ItemID != "q5" ||
		report.Questions[3].Prompt != "Solve for x: x + 7 = 22." {
		t.Fatalf("unexpected question outcomes: %+v", report.Questions)
	}
	if len(report.Mistakes) != 1 || report.Mistakes[0].Position != 1 ||
		report.Mistakes[0].Work != work.Blocks[1].Text || report.Mistakes[0].Box != work.Blocks[1].Box {
		t.Fatalf("unexpected mistakes: %+v", report.Mistakes)
	}
	if _, err := os.Stat(filepath.Join(repo.dir, "submissions", report.ID+".json")); err != nil {
		t.Fatalf("report was not saved: %v", err)
	}

	slices.Reverse(ids)
	retry, err := service.Submit(ctx, HomeworkAssignmentID, ids)
	if err != nil || retry.ID != report.ID || !retry.SubmittedAt.Equal(report.SubmittedAt) {
		t.Fatalf("retry should return the exact existing report: %+v, %v", retry, err)
	}
	ids[3] = ids[0]
	if _, err := service.Submit(ctx, HomeworkAssignmentID, ids); !errors.Is(err, ErrInvalidInput) {
		t.Fatalf("duplicate ID should be rejected, got %v", err)
	}
}
