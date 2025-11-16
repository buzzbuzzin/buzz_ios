-- Add Ground School Test Questions
-- Add all your questions here in this format
-- Run this AFTER you've run create_course_tests_system.sql

UPDATE course_tests
SET questions = '{
    "questions": [
        {
            "id": 1,
            "question": "A small UA causes an accident and your crew member loses consciousness. When do you report the accident?",
            "options": [
                "No accidents need to be reported.",
                "When requested by the UA owner.",
                "Within 10 days of the accident."
            ],
            "correctAnswer": 2
        },
        {
            "id": 2,
            "question": "YOUR QUESTION 2 HERE",
            "options": [
                "Option A",
                "Option B",
                "Option C",
                "Option D"
            ],
            "correctAnswer": 0
        },
        {
            "id": 3,
            "question": "YOUR QUESTION 3 HERE",
            "options": [
                "Option A",
                "Option B",
                "Option C"
            ],
            "correctAnswer": 1
        }
    ]
}'::jsonb,
updated_at = NOW()
WHERE id = 'a1b2c3d4-e5f6-7890-abcd-000000000001';

-- Verify questions were added
SELECT 
    test_name,
    jsonb_array_length(questions->'questions') as question_count,
    questions->'questions'->0->>'question' as first_question
FROM course_tests
WHERE id = 'a1b2c3d4-e5f6-7890-abcd-000000000001';

-- Instructions:
-- 1. Replace "YOUR QUESTION X HERE" with your actual questions
-- 2. Replace options with your actual options (you can have 2-4 options per question)
-- 3. Set correctAnswer to the index of the correct option (0 = first option, 1 = second, etc.)
-- 4. Add more questions by copying the question template:
--    {
--        "id": X,
--        "question": "Question text?",
--        "options": ["A", "B", "C"],
--        "correctAnswer": 0
--    },
-- 5. Run this SQL in Supabase SQL Editor after the main migration

