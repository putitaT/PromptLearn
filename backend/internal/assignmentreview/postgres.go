package assignmentreview

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"

	"github.com/opsst/PromptLearn/backend/internal/database"
)

const (
	demoAssignmentUUID     = "a1000000-0000-4000-8000-000000000016"
	homeworkAssignmentUUID = "a1000000-0000-4000-8000-000000000028"
)

func demoAssignmentKey(assignmentID string) string {
	if assignmentID == HomeworkAssignmentID {
		return homeworkAssignmentUUID
	}
	return demoAssignmentUUID
}

// PostgresDemoRepository uses a server-selected synthetic student and assignment.
// A production repository needs the student identity from an authenticated session.
type PostgresDemoRepository struct {
	db     *pgxpool.Pool
	engine string
}

func OpenPostgresDemo(ctx context.Context, databaseURL, engine string) (*PostgresDemoRepository, error) {
	db, err := database.OpenPostgres(ctx, databaseURL)
	if err != nil {
		return nil, err
	}
	repo := &PostgresDemoRepository{db: db, engine: engine}
	var ready bool
	err = db.QueryRow(ctx, "SELECT to_regclass('promptlearn.assignment_work_reviews') IS NOT NULL").Scan(&ready)
	if err != nil || !ready {
		db.Close()
		return nil, errors.New("apply db_migration/assignment_review.sql before enabling PostgreSQL review history")
	}
	if _, err := repo.FindQuestion(ctx, DemoAssignmentID, DemoItemID); err != nil {
		db.Close()
		return nil, errors.New("review demo item is unavailable; apply demo_seed.sql and assignment_review_demo_seed.sql")
	}
	if _, err := repo.FindQuestion(ctx, HomeworkAssignmentID, homeworkItemIDs[3]); err != nil {
		db.Close()
		return nil, errors.New("four-question homework is unavailable; apply assignment_review_demo_seed.sql")
	}
	return repo, nil
}

func (r *PostgresDemoRepository) Close() { r.db.Close() }

// The same membership and assignment checks run at lookup and again before persisting feedback.
const demoReviewTarget = `
	FROM promptlearn.assignments a
	JOIN promptlearn.assessment_items i ON i.assessment_version_id = a.assessment_version_id
	JOIN promptlearn.offering_memberships m
	  ON m.offering_id = a.offering_id AND m.user_id = $3::uuid AND m.role = 'student'
	LEFT JOIN promptlearn.assignment_recipients recipient
	  ON recipient.assignment_id = a.id AND recipient.student_id = m.user_id
	WHERE a.id = $1::uuid AND i.position = $2::integer AND i.kind = 'show_work'
	  AND a.allow_ai_hints AND a.published_at <= now()
	  AND (a.audience = 'class' OR recipient.student_id IS NOT NULL)
	  AND (a.opens_at IS NULL OR a.opens_at <= now())
	  AND (COALESCE(recipient.due_at_override, a.due_at) IS NULL
	    OR COALESCE(recipient.due_at_override, a.due_at) >= now())
`

func (r *PostgresDemoRepository) FindQuestion(ctx context.Context, assignmentID, itemID string) (Question, error) {
	position := demoPosition(assignmentID, itemID)
	if position == 0 {
		return Question{}, ErrNotFound
	}
	var question Question
	err := r.db.QueryRow(ctx, `
		SELECT i.prompt, COALESCE(i.answer_key::text, ''), COALESCE((
			SELECT string_agg(c.name || COALESCE((
				SELECT ': ' || string_agg(l.name || ' — ' || l.description, ' | ' ORDER BY l.awarded_points DESC, l.name)
				FROM promptlearn.rubric_levels l WHERE l.criterion_id = c.id
			), ''), E'\n' ORDER BY c.position)
			FROM promptlearn.rubric_criteria c WHERE c.item_id = i.id
		), '')
	`+demoReviewTarget, demoAssignmentKey(assignmentID), position, DemoStudentID).
		Scan(&question.Prompt, &question.AnswerKey, &question.Rubric)
	if errors.Is(err, pgx.ErrNoRows) {
		return Question{}, ErrNotFound
	}
	return question, err
}

type reviewTarget struct {
	assignmentID string
	itemID       string
	courseID     string
	offering     string
	version      string
	position     int
	outcomeID    string
}

func (r *PostgresDemoRepository) SaveReview(ctx context.Context, work Submission, result Result) (string, error) {
	position := demoPosition(result.AssignmentID, result.ItemID)
	if position == 0 {
		return "", ErrNotFound
	}
	payload, err := json.Marshal(evidenceFrom(work))
	if err != nil {
		return "", err
	}
	var reviewID string
	err = pgx.BeginFunc(ctx, r.db, func(tx pgx.Tx) error {
		var target reviewTarget
		err := tx.QueryRow(ctx, `
			SELECT a.id::text, i.id::text, a.course_id::text, a.offering_id::text, a.assessment_version_id::text, i.position,
			       COALESCE((SELECT CASE WHEN COUNT(*) = 1 THEN MIN(outcome_id::text) END
			                 FROM promptlearn.assessment_item_outcomes WHERE item_id = i.id), '')
		`+demoReviewTarget, demoAssignmentKey(result.AssignmentID), position, DemoStudentID).
			Scan(&target.assignmentID, &target.itemID, &target.courseID, &target.offering, &target.version, &target.position, &target.outcomeID)
		if errors.Is(err, pgx.ErrNoRows) {
			return ErrNotFound
		}
		if err != nil {
			return err
		}

		revisionID, err := insertDemoRevision(ctx, tx, target, payload)
		if err != nil {
			return err
		}
		err = tx.QueryRow(ctx, `
			INSERT INTO promptlearn.assignment_work_reviews (revision_id, status, engine, language, message)
			VALUES ($1, $2, $3, $4, $5)
			RETURNING id::text
		`, revisionID, result.Status, r.engine, reviewLanguage(work), result.Message).Scan(&reviewID)
		if err != nil {
			return err
		}
		return insertFeedback(ctx, tx, revisionID, target, result)
	})
	if err != nil {
		return "", err
	}
	return reviewID, nil
}

func insertDemoRevision(ctx context.Context, tx pgx.Tx, target reviewTarget, payload []byte) (string, error) {
	// The demo uses attempt 1. Locking the attempt serializes revision numbers across concurrent checks.
	_, err := tx.Exec(ctx, `
		INSERT INTO promptlearn.submissions (assignment_id, offering_id, assessment_version_id, student_id, attempt_number)
		VALUES ($1, $2, $3, $4, 1)
		ON CONFLICT (assignment_id, student_id, attempt_number) DO NOTHING
	`, target.assignmentID, target.offering, target.version, DemoStudentID)
	if err != nil {
		return "", err
	}
	var submissionID string
	err = tx.QueryRow(ctx, `
		SELECT id::text
		FROM promptlearn.submissions
		WHERE assignment_id = $1 AND student_id = $2 AND attempt_number = 1 AND submitted_at IS NULL
		FOR UPDATE
	`, target.assignmentID, DemoStudentID).Scan(&submissionID)
	if errors.Is(err, pgx.ErrNoRows) {
		return "", ErrAttemptClosed
	}
	if err != nil {
		return "", err
	}
	var responseID string
	err = tx.QueryRow(ctx, `
		INSERT INTO promptlearn.item_responses (submission_id, assessment_version_id, item_id, presented_position)
		VALUES ($1, $2, $3, $4)
		ON CONFLICT (submission_id, item_id) DO UPDATE SET skipped = false
		RETURNING id::text
	`, submissionID, target.version, target.itemID, target.position).Scan(&responseID)
	if err != nil {
		return "", err
	}
	var revisionID string
	err = tx.QueryRow(ctx, `
		INSERT INTO promptlearn.response_revisions (response_id, item_id, revision_number, answer)
		SELECT $1::uuid, $2::uuid, COALESCE(MAX(revision_number), 0) + 1, $3::jsonb
		FROM promptlearn.response_revisions
		WHERE response_id = $1
		RETURNING id::text
	`, responseID, target.itemID, payload).Scan(&revisionID)
	return revisionID, err
}

func insertFeedback(ctx context.Context, tx pgx.Tx, revisionID string, target reviewTarget, result Result) error {
	const addFeedback = `
		INSERT INTO promptlearn.learning_feedback (revision_id, annotation_id, misconception_id, outcome_id, source, body, visible_at)
		VALUES ($1, NULLIF($2, '')::uuid, NULLIF($3, '')::uuid, NULLIF($4, '')::uuid, 'ai', $5, now())
	`
	if len(result.Issues) == 0 {
		_, err := tx.Exec(ctx, addFeedback, revisionID, "", "", target.outcomeID, result.Message)
		return err
	}
	for _, issue := range result.Issues {
		annotation, err := json.Marshal(struct {
			BlockID string   `json:"block_id"`
			Box     Box      `json:"box"`
			Kind    HintKind `json:"kind"`
		}{BlockID: issue.BlockID, Box: issue.Box, Kind: issue.Kind})
		if err != nil {
			return err
		}
		var annotationID string
		err = tx.QueryRow(ctx, `
			INSERT INTO promptlearn.response_annotations (revision_id, page_number, selection)
			VALUES ($1, 1, $2::jsonb)
			RETURNING id::text
		`, revisionID, annotation).Scan(&annotationID)
		if err != nil {
			return err
		}

		var misconceptionID string
		// Incomplete evidence is not a confirmed misconception.
		if issue.Kind != MissingStep && issue.Kind != Incomplete {
			err := tx.QueryRow(ctx, `
				INSERT INTO promptlearn.misconceptions (course_id, code, description)
				VALUES ($1, $2, $3)
				ON CONFLICT (course_id, code) DO UPDATE SET code = EXCLUDED.code
				RETURNING id::text
			`, target.courseID, issue.Kind, prompts[issue.Kind].Observation.English).Scan(&misconceptionID)
			if err != nil {
				return fmt.Errorf("resolve misconception: %w", err)
			}
		}
		body := issue.Observation + "\n" + issue.Hint
		if _, err := tx.Exec(ctx, addFeedback, revisionID, annotationID, misconceptionID, target.outcomeID, body); err != nil {
			return err
		}
	}
	return nil
}
