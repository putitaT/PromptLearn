package replay

import (
	"context"
	"errors"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"

	"github.com/opsst/PromptLearn/backend/internal/database"
)

// SessionID identifies the completed lesson in db_migration/demo_seed.sql.
const SessionID = "a1000000-0000-4000-8000-000000000012"

var ErrNotFound = errors.New("recording not found")
var ErrNoSession = errors.New("demo lesson missing; apply db_migration/demo_seed.sql")

type Segment struct {
	StartMS int    `json:"startMs"`
	EndMS   int    `json:"endMs"`
	Text    string `json:"text"`
}

type Recording struct {
	ID         string    `json:"recordingId"`
	DurationMS int       `json:"durationMs"`
	Transcript []Segment `json:"transcript"`
}

type Store struct {
	db *pgxpool.Pool
}

func Open(ctx context.Context, databaseURL string) (*Store, error) {
	db, err := database.OpenPostgres(ctx, databaseURL)
	if err != nil {
		return nil, err
	}
	var exists bool
	err = db.QueryRow(ctx, `SELECT EXISTS (
		SELECT 1 FROM promptlearn.lesson_sessions WHERE id = $1
	)`, SessionID).Scan(&exists)
	if err != nil || !exists {
		db.Close()
		if err != nil {
			return nil, err
		}
		return nil, ErrNoSession
	}
	return &Store{db: db}, nil
}

func (s *Store) Close() {
	s.db.Close()
}

func (s *Store) Save(ctx context.Context, key string, size int64, duration int, segments []Segment) (string, error) {
	tx, err := s.db.Begin(ctx)
	if err != nil {
		return "", err
	}
	defer tx.Rollback(ctx)
	var recordingID, transcriptID string
	err = tx.QueryRow(ctx, `
		WITH asset AS (
			INSERT INTO promptlearn.assets (organization_id, object_key, content_type, byte_size, status)
			SELECT o.organization_id, $2, 'video/mp4', $3, 'ready'
			FROM promptlearn.lesson_sessions l JOIN promptlearn.course_offerings o ON o.id = l.offering_id
			WHERE l.id = $1
			RETURNING id
		), recording AS (
			INSERT INTO promptlearn.recordings (session_id, asset_id, duration_ms)
			SELECT $1, id, $4 FROM asset RETURNING id
		)
		INSERT INTO promptlearn.transcript_versions (recording_id, version_number)
		SELECT id, 1 FROM recording RETURNING recording_id::text, id::text
	`, SessionID, key, size, duration).Scan(&recordingID, &transcriptID)
	if err != nil {
		return "", err
	}

	starts := make([]int32, 0, len(segments))
	ends := make([]int32, 0, len(segments))
	text := make([]string, 0, len(segments))
	for _, segment := range segments {
		starts = append(starts, int32(segment.StartMS))
		ends = append(ends, int32(segment.EndMS))
		text = append(text, segment.Text)
	}
	_, err = tx.Exec(ctx, `
		INSERT INTO promptlearn.transcript_segments (transcript_version_id, start_ms, end_ms, body)
		SELECT $1, start_ms, end_ms, body FROM unnest($2::int[], $3::int[], $4::text[]) AS part(start_ms, end_ms, body)
	`, transcriptID, starts, ends, text)
	if err != nil {
		return "", err
	}
	if err := tx.Commit(ctx); err != nil {
		return "", err
	}
	return recordingID, nil
}

func (s *Store) Publish(ctx context.Context, id string) error {
	var publishedID string
	err := s.db.QueryRow(ctx, `
		INSERT INTO promptlearn.lesson_publications AS p (session_id, offering_id, recording_id, transcript_version_id)
		SELECT l.id, l.offering_id, r.id, t.id
		FROM promptlearn.lesson_sessions l
		JOIN promptlearn.recordings r ON r.session_id = l.id
		JOIN promptlearn.assets a ON a.id = r.asset_id AND a.status = 'ready'
		JOIN promptlearn.transcript_versions t ON t.recording_id = r.id AND t.version_number = 1
		WHERE l.id = $1 AND r.id::text = $2
		ON CONFLICT (session_id) DO UPDATE
		SET recording_id = EXCLUDED.recording_id, transcript_version_id = EXCLUDED.transcript_version_id,
			published_at = CASE WHEN p.recording_id = EXCLUDED.recording_id
								THEN p.published_at ELSE EXCLUDED.published_at END
		RETURNING recording_id::text
	`, SessionID, id).Scan(&publishedID)
	if errors.Is(err, pgx.ErrNoRows) {
		return ErrNotFound
	}
	return err
}

func (s *Store) Published(ctx context.Context) (*Recording, error) {
	rows, err := s.db.Query(ctx, `
		SELECT r.id::text, r.duration_ms, segment.start_ms, segment.end_ms, segment.body
		FROM promptlearn.lesson_publications p
		JOIN promptlearn.recordings r ON r.id = p.recording_id
		JOIN promptlearn.assets a ON a.id = r.asset_id AND a.status = 'ready'
		JOIN promptlearn.transcript_segments segment ON segment.transcript_version_id = p.transcript_version_id
		WHERE p.session_id = $1
		ORDER BY segment.start_ms, segment.id
	`, SessionID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	var recording *Recording
	for rows.Next() {
		if recording == nil {
			recording = &Recording{}
		}
		var segment Segment
		if err := rows.Scan(&recording.ID, &recording.DurationMS, &segment.StartMS, &segment.EndMS, &segment.Text); err != nil {
			return nil, err
		}
		recording.Transcript = append(recording.Transcript, segment)
	}
	return recording, rows.Err()
}

func (s *Store) PublishedKey(ctx context.Context, id string) (string, error) {
	return s.recordingKey(ctx, id, true)
}

func (s *Store) PreviewKey(ctx context.Context, id string) (string, error) {
	return s.recordingKey(ctx, id, false)
}

func (s *Store) recordingKey(ctx context.Context, id string, publishedOnly bool) (string, error) {
	var key string
	err := s.db.QueryRow(ctx, `
		SELECT a.object_key
		FROM promptlearn.recordings r
		JOIN promptlearn.assets a ON a.id = r.asset_id AND a.status = 'ready'
		WHERE r.session_id = $1 AND r.id::text = $2
		  AND (NOT $3::boolean OR EXISTS (
			SELECT 1 FROM promptlearn.lesson_publications p
			WHERE p.session_id = r.session_id AND p.recording_id = r.id
		  ))
	`, SessionID, id, publishedOnly).Scan(&key)
	if errors.Is(err, pgx.ErrNoRows) {
		return "", ErrNotFound
	}
	return key, err
}
