package assignmentreview

import (
	"context"
	"crypto/sha256"
	"encoding/hex"
	"fmt"
	"slices"
	"strings"
	"time"
)

type submissionReview struct {
	result    Result
	evidence  reviewEvidence
	prompt    string
	maxPoints float64
}

type SubmittedQuestion struct {
	Position       int      `json:"position"`
	ReviewID       string   `json:"review_id"`
	ItemID         string   `json:"item_id"`
	Prompt         string   `json:"prompt"`
	RecognizedWork string   `json:"recognized_work"`
	Status         Status   `json:"status"`
	Message        string   `json:"message"`
	MaxPoints      float64  `json:"max_points"`
	AwardedPoints  *float64 `json:"awarded_points"`
}

type SubmissionMistake struct {
	Position int    `json:"position"`
	Work     string `json:"work"`
	Issue
}

type SubmissionReport struct {
	ID           string              `json:"id"`
	AssignmentID string              `json:"assignment_id"`
	SubmittedAt  time.Time           `json:"submitted_at"`
	Points       float64             `json:"points"`
	MaxPoints    float64             `json:"max_points"`
	Pending      int                 `json:"pending"`
	Questions    []SubmittedQuestion `json:"questions"`
	Mistakes     []SubmissionMistake `json:"mistakes"`
}

// Submit freezes the selected review for each question and records a
// formative score for that exact set of reviewed answers.
func (s *Service) Submit(ctx context.Context, assignmentID string, reviewIDs []string) (SubmissionReport, error) {
	if assignmentID != HomeworkAssignmentID {
		return SubmissionReport{}, ErrNotFound
	}
	if len(reviewIDs) != len(homeworkQuestions) {
		return SubmissionReport{}, fmt.Errorf("%w: submit one review for each homework question", ErrInvalidInput)
	}
	seen := make(map[string]bool, len(reviewIDs))
	for _, id := range reviewIDs {
		if !validReviewID(id) || seen[id] {
			return SubmissionReport{}, fmt.Errorf("%w: each review ID must be distinct and valid", ErrInvalidInput)
		}
		seen[id] = true
	}
	reviews, err := s.repo.LoadSubmissionReviews(ctx, assignmentID, reviewIDs)
	if err != nil {
		return SubmissionReport{}, err
	}
	report, err := buildSubmissionReport(assignmentID, reviews)
	if err != nil {
		return SubmissionReport{}, err
	}
	report, err = s.repo.SaveSubmissionReport(ctx, report)
	if err != nil {
		return SubmissionReport{}, fmt.Errorf("%w: %v", ErrFeedbackStore, err)
	}
	return report, nil
}

func buildSubmissionReport(assignmentID string, reviews []submissionReview) (SubmissionReport, error) {
	if len(reviews) != len(homeworkQuestions) {
		return SubmissionReport{}, fmt.Errorf("%w: submit one review for each homework question", ErrInvalidInput)
	}
	report := SubmissionReport{
		AssignmentID: assignmentID,
		SubmittedAt:  time.Now().UTC(),
		Questions:    make([]SubmittedQuestion, len(reviews)),
		Mistakes:     make([]SubmissionMistake, 0),
	}
	for _, review := range reviews {
		result := review.result
		position := demoPosition(assignmentID, result.ItemID)
		if result.AssignmentID != assignmentID || position == 0 || report.Questions[position-1].ReviewID != "" {
			return SubmissionReport{}, fmt.Errorf("%w: reviews must cover distinct questions of this assignment", ErrInvalidInput)
		}
		question := SubmittedQuestion{
			Position: position, ReviewID: result.ReviewID, ItemID: result.ItemID,
			Prompt: review.prompt, Status: result.Status, Message: result.Message,
			RecognizedWork: review.evidence.Text, MaxPoints: review.maxPoints,
		}
		report.MaxPoints += question.MaxPoints
		switch result.Status {
		case Correct:
			points := question.MaxPoints
			question.AwardedPoints = &points
			report.Points += points
		case NeedsRevision:
			points := float64(0)
			question.AwardedPoints = &points
			for _, issue := range result.Issues {
				report.Mistakes = append(report.Mistakes, SubmissionMistake{
					Position: position, Issue: issue, Work: blockText(review.evidence.Blocks, issue.BlockID),
				})
			}
		case Unreadable:
			report.Pending++
		default:
			return SubmissionReport{}, ErrInvalidDecision
		}
		report.Questions[position-1] = question
	}
	ids := make([]string, 0, len(report.Questions)+1)
	ids = append(ids, assignmentID)
	for _, question := range report.Questions {
		ids = append(ids, question.ReviewID)
	}
	hash := sha256.Sum256([]byte(strings.Join(ids, ":")))
	report.ID = hex.EncodeToString(hash[:])
	slices.SortStableFunc(report.Mistakes, func(a, b SubmissionMistake) int { return a.Position - b.Position })
	return report, nil
}

func blockText(blocks []Block, id string) string {
	for _, block := range blocks {
		if block.ID == id {
			return block.Text
		}
	}
	return ""
}

func validReviewID(id string) bool {
	return len(id) > 0 && len(id) <= 64 && strings.IndexFunc(id, func(r rune) bool {
		return !(r >= 'a' && r <= 'z' || r >= 'A' && r <= 'Z' || r >= '0' && r <= '9' || r == '-')
	}) == -1
}
