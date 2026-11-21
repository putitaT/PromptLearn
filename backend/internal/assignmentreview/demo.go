package assignmentreview

import (
	"context"
	"strings"
)

const (
	DemoAssignmentID     = "hw-3-2"
	DemoItemID           = "q4"
	DemoStudentID        = "a1000000-0000-4000-8000-000000000003"
	HomeworkAssignmentID = "hw-3-1"
)

const exponentRubric = "Show valid intermediate reasoning using properties of exponents, then give the simplified expression."
const equationPrompt = "Solve for x: x + 7 = 22."

var originalDemoQuestion = Question{
	Prompt: "Simplify (x^2)(x^5). Show how you combine the powers.",
	Rubric: exponentRubric, AnswerKey: "x^7; expand both factors or show x^(2+5).",
}

// Item IDs stay tied to their original prompts even when their order changes.
var homeworkItemIDs = [...]string{"q1", "q2", "q3", "q5"}

var homeworkQuestions = [len(homeworkItemIDs)]Question{
	{Prompt: "Simplify x² · x³.", Rubric: exponentRubric, AnswerKey: "x^5; expand both factors or show x^(2+3)."},
	{Prompt: "Simplify (a³)².", Rubric: exponentRubric, AnswerKey: "a^6; expand as a^3*a^3 or show a^(3*2)."},
	{Prompt: "Simplify y⁶ ÷ y², where y ≠ 0.", Rubric: exponentRubric, AnswerKey: "y^4; cancel two factors, or show y^(6-2)."},
	{
		Prompt:    equationPrompt,
		Rubric:    "Show how x was isolated by keeping both sides of the equation equal, or justify the value by substitution.",
		AnswerKey: "x = 15; subtract 7 from both sides and simplify, or verify that 15 + 7 = 22.",
	},
}

func demoPosition(assignmentID, itemID string) int {
	if assignmentID == DemoAssignmentID && itemID == DemoItemID {
		return 4
	}
	if assignmentID == HomeworkAssignmentID {
		for index, id := range homeworkItemIDs {
			if id == itemID {
				return index + 1
			}
		}
	}
	return 0
}

func (*DemoRepository) FindQuestion(_ context.Context, assignmentID, itemID string) (Question, error) {
	if assignmentID == DemoAssignmentID && itemID == DemoItemID {
		return originalDemoQuestion, nil
	}
	position := demoPosition(assignmentID, itemID)
	if position == 0 {
		return Question{}, ErrNotFound
	}
	return homeworkQuestions[position-1], nil
}

// DemoReviewer recognizes synthetic transcripts for the supported examples.
type DemoReviewer struct{}

func (DemoReviewer) Review(_ context.Context, question Question, work Submission) (Decision, error) {
	var second, product, sum string
	switch question.Prompt {
	case homeworkQuestions[0].Prompt:
		second, product, sum = "3", "6", "5"
	case originalDemoQuestion.Prompt:
		second, product, sum = "5", "10", "7"
	case equationPrompt:
		return reviewDemoEquation(work), nil
	default:
		return Decision{Status: Unreadable}, nil
	}
	expansion := strings.TrimSuffix(strings.Repeat("x*", int(sum[0]-'0')), "*")
	var methodSeen bool
	for i, block := range work.Blocks {
		step, result, _ := strings.Cut(plainMath(block.Text), "=")
		switch step {
		case "(x^2)(x^" + second + ")", "x^2*x^" + second:
			// Original expression.
		case "x^(2*" + second + ")", "x^2*" + second, "x^2x" + second:
			return Decision{Status: NeedsRevision, Findings: []Finding{{BlockID: block.ID, Kind: SameBasePowers}}}, nil
		case "x^" + product:
			return Decision{Status: NeedsRevision, Findings: []Finding{{BlockID: block.ID, Kind: SameBasePowers}}}, nil
		case "x^(2+" + second + ")", expansion:
			methodSeen = true
			if result == "x^"+sum && i == len(work.Blocks)-1 {
				return Decision{Status: Correct}, nil
			}
		case "x^" + sum:
			if methodSeen && i == len(work.Blocks)-1 {
				return Decision{Status: Correct}, nil
			}
			if !methodSeen && i == len(work.Blocks)-1 {
				return Decision{Status: NeedsRevision, Findings: []Finding{{BlockID: block.ID, Kind: MissingStep}}}, nil
			}
		default:
			return Decision{Status: Unreadable}, nil
		}
	}
	return Decision{Status: Unreadable}, nil
}

func reviewDemoEquation(work Submission) Decision {
	var isolated bool
	for index, block := range work.Blocks {
		step := strings.ReplaceAll(plainMath(block.Text), "−", "-")
		last := index == len(work.Blocks)-1
		switch step {
		case "x+7=22", "x+7=22=?":
			continue
		case "x+7-7=22-7", "x=22-7":
			isolated = true
		case "x=22-7=15", "15+7=22":
			if last {
				return Decision{Status: Correct}
			}
			isolated = true
		case "x=15":
			if last && isolated {
				return Decision{Status: Correct}
			}
			if last {
				return Decision{Status: NeedsRevision, Findings: []Finding{{BlockID: block.ID, Kind: MissingStep}}}
			}
		case "x=22+7", "x=22+7=29", "x=29":
			return Decision{Status: NeedsRevision, Findings: []Finding{{BlockID: block.ID, Kind: Equivalence}}}
		default:
			return Decision{Status: Unreadable}
		}
	}
	return Decision{Status: Unreadable}
}

func plainMath(text string) string {
	text = strings.Join(strings.Fields(strings.ToLower(text)), "")
	return strings.NewReplacer("×", "*", "·", "*", "¹⁰", "^10", "²", "^2", "³", "^3", "⁵", "^5", "⁶", "^6", "⁷", "^7").Replace(strings.TrimPrefix(text, "="))
}
