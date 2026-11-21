package assignmentreview

import (
	"context"
	"encoding/json"
)

func (r *PostgresDemoRepository) LoadSubmissionReviews(ctx context.Context, assignmentID string, ids []string) ([]submissionReview, error) {
	rows, err := r.db.Query(ctx, `
		SELECT w.id::text, i.position, i.prompt, i.max_points::float8, w.status, w.message, w.language,
		       COALESCE(rr.answer, '{}'::jsonb),
		       COALESCE((
		           SELECT jsonb_agg(a.selection)
		           FROM promptlearn.response_annotations a
		           WHERE a.revision_id = rr.id AND EXISTS (
		               SELECT 1 FROM promptlearn.learning_feedback f
		               WHERE f.annotation_id = a.id AND f.source = 'ai'
		           )
		       ), '[]'::jsonb)
		FROM promptlearn.assignment_work_reviews w
		JOIN promptlearn.response_revisions rr ON rr.id = w.revision_id
		JOIN promptlearn.item_responses ir ON ir.id = rr.response_id
		JOIN promptlearn.submissions s ON s.id = ir.submission_id
		JOIN promptlearn.assessment_items i ON i.id = ir.item_id
		WHERE w.id::text = ANY($1::text[]) AND s.assignment_id = $2 AND s.student_id = $3
	`, ids, demoAssignmentKey(assignmentID), DemoStudentID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	reviews := make([]submissionReview, 0, len(ids))
	for rows.Next() {
		var review submissionReview
		var id, message, language string
		var position int
		var decision Decision
		var serializedWork, serializedFindings []byte
		if err := rows.Scan(&id, &position, &review.prompt, &review.maxPoints, &decision.Status,
			&message, &language, &serializedWork, &serializedFindings); err != nil {
			return nil, err
		}
		if err := json.Unmarshal(serializedWork, &review.evidence); err != nil {
			return nil, err
		}
		if err := json.Unmarshal(serializedFindings, &decision.Findings); err != nil {
			return nil, err
		}
		if position < 1 || position > len(homeworkItemIDs) {
			return nil, ErrInvalidInput
		}
		result, err := buildResult(assignmentID, homeworkItemIDs[position-1], Submission{
			Blocks: review.evidence.Blocks, Language: language,
		}, decision)
		if err != nil {
			return nil, err
		}
		result.ReviewID, result.Message = id, message
		review.result = result
		reviews = append(reviews, review)
	}
	if err := rows.Err(); err != nil {
		return nil, err
	}
	if len(reviews) != len(ids) {
		return nil, ErrNotFound
	}
	return reviews, nil
}

func (r *PostgresDemoRepository) SaveSubmissionReport(ctx context.Context, report SubmissionReport) (SubmissionReport, error) {
	payload, err := json.Marshal(report)
	if err != nil {
		return SubmissionReport{}, err
	}
	assignmentID := demoAssignmentKey(report.AssignmentID)
	if _, err := r.db.Exec(ctx, `
		INSERT INTO promptlearn.assignment_submission_reports (id, assignment_id, student_id, report)
		VALUES ($1, $2, $3, $4)
		ON CONFLICT (id) DO NOTHING
	`, report.ID, assignmentID, DemoStudentID, payload); err != nil {
		return SubmissionReport{}, err
	}
	err = r.db.QueryRow(ctx, `
		SELECT report FROM promptlearn.assignment_submission_reports
		WHERE id = $1 AND assignment_id = $2 AND student_id = $3
	`, report.ID, assignmentID, DemoStudentID).Scan(&payload)
	if err != nil {
		return SubmissionReport{}, err
	}
	err = json.Unmarshal(payload, &report)
	return report, err
}
