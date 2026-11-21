// Package assignmentreview checks a single item's show-your-work submission.
package assignmentreview

import (
	"context"
	"errors"
	"fmt"
	"slices"
	"strings"
)

var (
	ErrInvalidInput    = errors.New("invalid work submission")
	ErrNotFound        = errors.New("assignment item not found")
	ErrInvalidDecision = errors.New("reviewer returned an invalid decision")
	ErrFeedbackStore   = errors.New("review feedback could not be saved")
	ErrAttemptClosed   = errors.New("this assignment attempt has already been submitted")
)

type Block struct {
	ID   string `json:"id"`
	Text string `json:"text"`
	Box  Box    `json:"box"`

	imageDataURL string
}

type Submission struct {
	Text           string  `json:"text"`
	Blocks         []Block `json:"blocks"`
	ImageDataURL   string  `json:"image_data_url,omitempty"`
	FocusedBlockID string  `json:"focused_block_id,omitempty"`
	Language       string  `json:"language,omitempty"`
}

// Question is the private item context resolved by the backend.
type Question struct {
	Prompt    string `json:"prompt"`
	Rubric    string `json:"rubric"`
	AnswerKey string `json:"answer_key"`
}

type Repository interface {
	FindQuestion(ctx context.Context, assignmentID, itemID string) (Question, error)
	SaveReview(context.Context, Submission, Result) (string, error)
	LoadSubmissionReviews(context.Context, string, []string) ([]submissionReview, error)
	SaveSubmissionReport(context.Context, SubmissionReport) (SubmissionReport, error)
}

type Reviewer interface {
	Review(context.Context, Question, Submission) (Decision, error)
}

// PaperOCR reads lines and their locations on the original uploaded image.
type PaperOCR interface {
	ReadPaper(context.Context, string) ([]Block, error)
}

type Status string

const (
	Correct       Status = "correct"
	NeedsRevision Status = "needs_revision"
	Unreadable    Status = "unreadable"
)

type Finding struct {
	BlockID string   `json:"block_id"`
	Kind    HintKind `json:"kind"`
}

type Decision struct {
	Status   Status    `json:"status"`
	Findings []Finding `json:"findings"`
}

type Issue struct {
	BlockID     string   `json:"block_id"`
	Box         Box      `json:"box"`
	Kind        HintKind `json:"kind"`
	Observation string   `json:"observation"`
	Hint        string   `json:"hint"`
}

type Result struct {
	ReviewID     string  `json:"review_id"`
	AssignmentID string  `json:"assignment_id"`
	ItemID       string  `json:"item_id"`
	Status       Status  `json:"status"`
	Message      string  `json:"message"`
	Issues       []Issue `json:"issues"`
}

type Service struct {
	repo     Repository
	reviewer Reviewer
	ocr      PaperOCR
}

func NewService(repo Repository, reviewer Reviewer, ocr PaperOCR) *Service {
	return &Service{repo: repo, reviewer: reviewer, ocr: ocr}
}

func (s *Service) Review(ctx context.Context, assignmentID, itemID string, work Submission) (Result, error) {
	if err := validateWork(work); err != nil {
		return Result{}, err
	}
	question, err := s.repo.FindQuestion(ctx, assignmentID, itemID)
	if err != nil {
		return Result{}, err
	}
	if len(work.Blocks) == 0 && work.ImageDataURL != "" && s.ocr != nil {
		work.Blocks, err = s.ocr.ReadPaper(ctx, work.ImageDataURL)
		if err != nil {
			return Result{}, err
		}
		if err := validateBlocks(work.Blocks, ""); err != nil {
			return Result{}, fmt.Errorf("%w: OCR blocks do not match the image contract", ErrInvalidDecision)
		}
		if strings.TrimSpace(work.Text) == "" {
			lines := make([]string, 0, len(work.Blocks))
			for _, block := range work.Blocks {
				lines = append(lines, block.Text)
			}
			work.Text = strings.Join(lines, "\n")
			if len(work.Text) > 32768 {
				return Result{}, fmt.Errorf("%w: OCR text exceeds the size limit", ErrInvalidDecision)
			}
		}
	}
	decision := Decision{Status: Unreadable}
	if len(work.Blocks) != 0 || strings.TrimSpace(work.Text) != "" {
		decision, err = s.reviewer.Review(ctx, question, work)
		if err != nil {
			return Result{}, err
		}
	}
	result, err := buildResult(assignmentID, itemID, work, decision)
	if err != nil {
		return Result{}, err
	}
	result.ReviewID, err = s.repo.SaveReview(ctx, work, result)
	if errors.Is(err, ErrAttemptClosed) || errors.Is(err, ErrNotFound) {
		return Result{}, err
	}
	if err != nil {
		return Result{}, fmt.Errorf("%w: %v", ErrFeedbackStore, err)
	}
	return result, nil
}

func validateWork(work Submission) error {
	if work.Language != "" && work.Language != "en" && work.Language != "th" {
		return fmt.Errorf("%w: language must be en or th", ErrInvalidInput)
	}
	if strings.ContainsRune(work.Text, 0) {
		return fmt.Errorf("%w: OCR text cannot contain a null character", ErrInvalidInput)
	}
	if len(work.Text) > 32768 || len(work.Blocks) > 100 {
		return fmt.Errorf("%w: OCR text or block count exceeds the limit", ErrInvalidInput)
	}
	if work.ImageDataURL == "" && strings.TrimSpace(work.Text) == "" && len(work.Blocks) == 0 {
		return fmt.Errorf("%w: provide OCR text or a paper image", ErrInvalidInput)
	}
	if work.ImageDataURL != "" && !validImage(work.ImageDataURL) {
		return fmt.Errorf("%w: image_data_url must contain a valid Base64 JPEG or PNG within the size limit", ErrInvalidInput)
	}
	return validateBlocks(work.Blocks, work.FocusedBlockID)
}

func validateBlocks(blocks []Block, focusedID string) error {
	if len(blocks) > 100 {
		return fmt.Errorf("%w: OCR block count exceeds the limit", ErrInvalidInput)
	}
	ids := make(map[string]bool, len(blocks))
	for _, block := range blocks {
		if strings.TrimSpace(block.ID) == "" || len(block.ID) > 128 ||
			ids[block.ID] || strings.TrimSpace(block.Text) == "" || len(block.Text) > 2048 ||
			strings.ContainsRune(block.ID, 0) || strings.ContainsRune(block.Text, 0) || !validBox(block.Box) {
			return fmt.Errorf("%w: OCR blocks require a unique id, text and a valid box", ErrInvalidInput)
		}
		ids[block.ID] = true
	}
	if focusedID != "" && !ids[focusedID] {
		return fmt.Errorf("%w: focused_block_id must match a submitted OCR block", ErrInvalidInput)
	}
	return nil
}

func buildResult(assignmentID, itemID string, work Submission, decision Decision) (Result, error) {
	message, known := statusMessages[decision.Status]
	if !known || len(decision.Findings) > 3 ||
		((decision.Status == NeedsRevision) != (len(decision.Findings) > 0)) {
		return Result{}, fmt.Errorf("%w: status does not match the findings", ErrInvalidDecision)
	}

	positions := make(map[string]int, len(work.Blocks))
	for index, block := range work.Blocks {
		positions[block.ID] = index
	}
	result := Result{
		AssignmentID: assignmentID, ItemID: itemID, Status: decision.Status, Message: message.in(work.Language),
		Issues: make([]Issue, 0, len(decision.Findings)),
	}
	seen := make(map[string]bool, len(decision.Findings))
	for _, finding := range decision.Findings {
		index, matched := positions[finding.BlockID]
		text, recognized := prompts[finding.Kind]
		if !matched || !recognized || seen[finding.BlockID] {
			return Result{}, fmt.Errorf("%w: finding refers to an unknown or duplicate OCR block or an unknown hint", ErrInvalidDecision)
		}
		seen[finding.BlockID] = true
		result.Issues = append(result.Issues, Issue{
			BlockID: finding.BlockID, Kind: finding.Kind, Box: work.Blocks[index].Box,
			Observation: text.Observation.in(work.Language), Hint: text.Question.in(work.Language),
		})
	}
	slices.SortFunc(result.Issues, func(a, b Issue) int { return positions[a.BlockID] - positions[b.BlockID] })
	return result, nil
}
