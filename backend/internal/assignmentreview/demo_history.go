package assignmentreview

import (
	"context"
	"crypto/rand"
	"encoding/json"
	"errors"
	"os"
	"path/filepath"
	"sync"
	"time"
)

// DemoRepository stores synthetic student reviews in the local data directory.
type DemoRepository struct {
	dir     string
	engine  string
	reports sync.Mutex
}

type reviewEvidence struct {
	Text           string  `json:"text"`
	Blocks         []Block `json:"blocks"`
	FocusedBlockID string  `json:"focused_block_id,omitempty"`
	ImageSupplied  bool    `json:"image_supplied"`
}

func evidenceFrom(work Submission) reviewEvidence {
	return reviewEvidence{
		Text: work.Text, Blocks: work.Blocks,
		FocusedBlockID: work.FocusedBlockID, ImageSupplied: work.ImageDataURL != "",
	}
}

type demoEvent struct {
	StudentID string         `json:"student_id"`
	Engine    string         `json:"engine"`
	Language  string         `json:"language"`
	CreatedAt time.Time      `json:"created_at"`
	Evidence  reviewEvidence `json:"evidence"`
	Result    Result         `json:"result"`
}

func OpenDemoRepository(dir, engine string) (*DemoRepository, error) {
	if err := os.MkdirAll(dir, 0o700); err != nil {
		return nil, err
	}
	return &DemoRepository{dir: dir, engine: engine}, nil
}

func (r *DemoRepository) SaveReview(ctx context.Context, work Submission, result Result) (string, error) {
	if err := ctx.Err(); err != nil {
		return "", err
	}
	result.ReviewID = rand.Text()
	event := demoEvent{
		StudentID: DemoStudentID, Engine: r.engine, Language: reviewLanguage(work), CreatedAt: time.Now().UTC(),
		Evidence: evidenceFrom(work), Result: result,
	}
	if err := writeDemoJSON(r.dir, result.ReviewID, event); err != nil {
		return "", err
	}
	return result.ReviewID, nil
}

func (r *DemoRepository) LoadSubmissionReviews(ctx context.Context, assignmentID string, ids []string) ([]submissionReview, error) {
	reviews := make([]submissionReview, 0, len(ids))
	for _, id := range ids {
		if err := ctx.Err(); err != nil {
			return nil, err
		}
		raw, err := os.ReadFile(filepath.Join(r.dir, id+".json"))
		if errors.Is(err, os.ErrNotExist) {
			return nil, ErrNotFound
		}
		if err != nil {
			return nil, err
		}
		var event demoEvent
		if err := json.Unmarshal(raw, &event); err != nil {
			return nil, err
		}
		if event.StudentID != DemoStudentID || event.Result.AssignmentID != assignmentID || event.Result.ReviewID != id {
			return nil, ErrNotFound
		}
		question, err := r.FindQuestion(ctx, assignmentID, event.Result.ItemID)
		if err != nil {
			return nil, err
		}
		reviews = append(reviews, submissionReview{
			result: event.Result, evidence: event.Evidence, prompt: question.Prompt, maxPoints: 1,
		})
	}
	return reviews, nil
}

func (r *DemoRepository) SaveSubmissionReport(ctx context.Context, report SubmissionReport) (SubmissionReport, error) {
	r.reports.Lock()
	defer r.reports.Unlock()
	if err := ctx.Err(); err != nil {
		return SubmissionReport{}, err
	}
	dir := filepath.Join(r.dir, "submissions")
	if err := os.MkdirAll(dir, 0o700); err != nil {
		return SubmissionReport{}, err
	}
	raw, err := os.ReadFile(filepath.Join(dir, report.ID+".json"))
	if err == nil {
		err = json.Unmarshal(raw, &report)
		return report, err
	}
	if !errors.Is(err, os.ErrNotExist) {
		return SubmissionReport{}, err
	}
	err = writeDemoJSON(dir, report.ID, report)
	return report, err
}

func writeDemoJSON(dir, id string, value any) error {
	file, err := os.CreateTemp(dir, ".pending-*")
	if err != nil {
		return err
	}
	defer os.Remove(file.Name())
	defer file.Close()
	if err := json.NewEncoder(file).Encode(value); err != nil {
		return err
	}
	if err := file.Sync(); err != nil {
		return err
	}
	if err := file.Close(); err != nil {
		return err
	}
	return os.Rename(file.Name(), filepath.Join(dir, id+".json"))
}

func reviewLanguage(work Submission) string {
	if work.Language == "th" {
		return "th"
	}
	return "en"
}
