BEGIN;
SET LOCAL search_path TO promptlearn, public;

-- Uses the synthetic course, offering, and student from demo_seed.sql.
INSERT INTO assessments (id, course_id)
VALUES ('a1000000-0000-4000-8000-000000000013', 'a1000000-0000-4000-8000-000000000006')
ON CONFLICT (id) DO NOTHING;

INSERT INTO assessment_versions (id, assessment_id, version_number, title, kind, purpose, published_at)
VALUES ('a1000000-0000-4000-8000-000000000014', 'a1000000-0000-4000-8000-000000000013',
        1, 'HW 3.2', 'homework', 'formative', now())
ON CONFLICT (id) DO NOTHING;

INSERT INTO assessment_items (id, assessment_version_id, position, kind, prompt, max_points, answer_key)
VALUES ('a1000000-0000-4000-8000-000000000015', 'a1000000-0000-4000-8000-000000000014', 4,
        'show_work', 'Simplify (x^2)(x^5). Show how you combine the powers.', 1,
        '{"answer":"x^7","valid_reasoning":"Expand both factors or show x^(2+5) before simplifying."}')
ON CONFLICT (id) DO NOTHING;

INSERT INTO assignments (id, offering_id, course_id, assessment_id, assessment_version_id, published_at,
                         audience, allow_ai_hints, require_work, accept_paper_photos)
VALUES ('a1000000-0000-4000-8000-000000000016', 'a1000000-0000-4000-8000-000000000008',
        'a1000000-0000-4000-8000-000000000006', 'a1000000-0000-4000-8000-000000000013',
        'a1000000-0000-4000-8000-000000000014', now(), 'selected_students', true, true, true)
ON CONFLICT (id) DO NOTHING;

INSERT INTO assignment_recipients (assignment_id, offering_id, student_id)
VALUES ('a1000000-0000-4000-8000-000000000016', 'a1000000-0000-4000-8000-000000000008',
        'a1000000-0000-4000-8000-000000000003')
ON CONFLICT DO NOTHING;

INSERT INTO learning_outcomes (id, syllabus_version_id, description)
VALUES ('a1000000-0000-4000-8000-000000000017', 'a1000000-0000-4000-8000-000000000007',
        'Apply properties of powers with positive integer exponents.')
ON CONFLICT (id) DO NOTHING;

INSERT INTO assessment_item_outcomes (item_id, outcome_id)
VALUES ('a1000000-0000-4000-8000-000000000015', 'a1000000-0000-4000-8000-000000000017')
ON CONFLICT DO NOTHING;

INSERT INTO rubric_criteria (id, item_id, position, name, max_points)
VALUES ('a1000000-0000-4000-8000-000000000018', 'a1000000-0000-4000-8000-000000000015',
        1, 'Show valid reasoning before giving the simplified power.', 1)
ON CONFLICT (id) DO NOTHING;

INSERT INTO rubric_levels (criterion_id, name, awarded_points, description)
VALUES ('a1000000-0000-4000-8000-000000000018', 'Full', 1, 'Shows valid reasoning and the correct result.'),
       ('a1000000-0000-4000-8000-000000000018', 'Partial', 0.5, 'Shows valid reasoning but makes a computation error.'),
       ('a1000000-0000-4000-8000-000000000018', 'None', 0, 'The reasoning is invalid or absent.')
ON CONFLICT (criterion_id, name) DO NOTHING;

-- HW 3.1 version 3 has four questions. Its own assignment preserves earlier attempts.
INSERT INTO assessments (id, course_id)
VALUES ('a1000000-0000-4000-8000-000000000021', 'a1000000-0000-4000-8000-000000000006')
ON CONFLICT (id) DO NOTHING;

INSERT INTO assessment_versions (id, assessment_id, version_number, title, kind, purpose, published_at)
VALUES ('a1000000-0000-4000-8000-000000000027', 'a1000000-0000-4000-8000-000000000021',
        3, 'HW 3.1', 'homework', 'formative', now())
ON CONFLICT (id) DO NOTHING;

INSERT INTO assessment_items (assessment_version_id, position, kind, prompt, max_points, answer_key)
SELECT 'a1000000-0000-4000-8000-000000000027', position, 'show_work', prompt, 1,
       jsonb_build_object('answer', answer, 'valid_reasoning', reasoning)
FROM (VALUES
    (1, 'Simplify x² · x³.', 'x^5', 'Expand both factors or show x^(2+3).'),
    (2, 'Simplify (a³)².', 'a^6', 'Expand as a^3*a^3 or show a^(3*2).'),
    (3, 'Simplify y⁶ ÷ y², where y ≠ 0.', 'y^4', 'Cancel two factors or show y^(6-2).'),
    (4, 'Solve for x: x + 7 = 22.', 'x = 15', 'Subtract 7 from both sides and simplify, or verify that 15 + 7 = 22.')
) AS homework(position, prompt, answer, reasoning)
ON CONFLICT (assessment_version_id, position) DO NOTHING;

INSERT INTO learning_outcomes (id, syllabus_version_id, description)
VALUES ('a1000000-0000-4000-8000-000000000026', 'a1000000-0000-4000-8000-000000000007',
        'Solve a one-step linear equation by preserving equality.')
ON CONFLICT (id) DO NOTHING;

INSERT INTO assessment_item_outcomes (item_id, outcome_id)
SELECT id,
       CASE WHEN position = 4 THEN 'a1000000-0000-4000-8000-000000000026'::uuid
            ELSE 'a1000000-0000-4000-8000-000000000017'::uuid END
FROM assessment_items WHERE assessment_version_id = 'a1000000-0000-4000-8000-000000000027'
ON CONFLICT DO NOTHING;

INSERT INTO rubric_criteria (item_id, position, name, max_points)
SELECT id, 1,
       CASE WHEN position = 4 THEN 'Show how x was isolated by keeping both sides of the equation equal, or justify the value by substitution.'
            ELSE 'Show valid intermediate reasoning using properties of exponents, then give the simplified expression.' END,
       1
FROM assessment_items WHERE assessment_version_id = 'a1000000-0000-4000-8000-000000000027'
ON CONFLICT (item_id, position) DO NOTHING;

INSERT INTO rubric_levels (criterion_id, name, awarded_points, description)
SELECT c.id, l.name, l.points, l.description
FROM rubric_criteria c JOIN assessment_items i ON i.id = c.item_id
CROSS JOIN (VALUES
    ('Full', 1, 'Shows valid reasoning and gives the correct result.'),
    ('Partial', 0.5, 'Shows valid reasoning with a computation error.'),
    ('None', 0, 'The reasoning is invalid or absent.')
) AS l(name, points, description)
WHERE i.assessment_version_id = 'a1000000-0000-4000-8000-000000000027' AND c.position = 1
ON CONFLICT (criterion_id, name) DO NOTHING;

INSERT INTO assignments (id, offering_id, course_id, assessment_id, assessment_version_id, published_at,
                         audience, allow_ai_hints, require_work, accept_paper_photos)
VALUES ('a1000000-0000-4000-8000-000000000028', 'a1000000-0000-4000-8000-000000000008',
        'a1000000-0000-4000-8000-000000000006', 'a1000000-0000-4000-8000-000000000021',
        'a1000000-0000-4000-8000-000000000027', now(), 'selected_students', true, true, true)
ON CONFLICT (id) DO NOTHING;

INSERT INTO assignment_recipients (assignment_id, offering_id, student_id)
VALUES ('a1000000-0000-4000-8000-000000000028', 'a1000000-0000-4000-8000-000000000008',
        'a1000000-0000-4000-8000-000000000003')
ON CONFLICT DO NOTHING;

COMMIT;
