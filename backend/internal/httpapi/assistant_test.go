package httpapi

import (
	"context"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"

	"github.com/opsst/PromptLearn/backend/internal/assistant"
	"github.com/opsst/PromptLearn/backend/internal/openai"
)

type assistantGeneratorFunc func(context.Context, openai.JSONRequest) (json.RawMessage, error)

func (f assistantGeneratorFunc) GenerateJSON(ctx context.Context, request openai.JSONRequest) (json.RawMessage, error) {
	return f(ctx, request)
}

func TestAssistantChatUsesRoleAndConversation(t *testing.T) {
	const question = "ขอคำใบ้เรื่องเลขยกกำลัง"
	const body = `{"role":"student","messages":[{"role":"user","text":"I am studying exponents."},{"role":"assistant","text":"What would you like to practice?"},{"role":"user","text":"` + question + `"}]}`
	generator := assistantGeneratorFunc(func(ctx context.Context, request openai.JSONRequest) (json.RawMessage, error) {
		var messages []assistant.Message
		if err := json.Unmarshal([]byte(request.Input), &messages); err != nil {
			t.Fatal(err)
		}
		if len(messages) != 3 || messages[1].Role != "assistant" || messages[2].Text != question {
			t.Fatalf("unexpected model transcript: %+v", messages)
		}
		if !strings.Contains(request.Instructions, "give a focused hint") {
			t.Fatalf("student guidance missing: %q", request.Instructions)
		}
		return json.RawMessage(`{"reply":"ลองเขียนให้อยู่ในรูปการคูณ"}`), nil
	})
	app := NewHandler(nil, nil, WithAssistant(assistant.OpenAIResponder{Client: generator}))
	request := httptest.NewRequest(http.MethodPost, "http://10.0.2.2:8080/v1/assistant/chat", strings.NewReader(body))
	request.RemoteAddr = "127.0.0.1:49152"
	request.Header.Set("Content-Type", "application/json")
	response := httptest.NewRecorder()
	app.ServeHTTP(response, request)
	if response.Code != http.StatusOK {
		t.Fatalf("status %d: %s", response.Code, response.Body)
	}
	var reply assistant.Reply
	if err := json.Unmarshal(response.Body.Bytes(), &reply); err != nil || reply.Text != "ลองเขียนให้อยู่ในรูปการคูณ" {
		t.Fatalf("unexpected response: %s", response.Body)
	}
}

func TestAssistantChatRejectsUnavailableOrInvalidRequests(t *testing.T) {
	const valid = `{"role":"teacher","messages":[{"role":"user","text":"Plan an exponent lesson."}]}`
	for _, test := range []struct {
		name   string
		peer   string
		body   string
		status int
	}{
		{"backend has no API key", "127.0.0.1:49152", valid, http.StatusServiceUnavailable},
		{"non-local peer", "192.0.2.4:49152", valid, http.StatusForbidden},
		{"assistant cannot lead a turn", "127.0.0.1:49152", `{"role":"teacher","messages":[{"role":"assistant","text":"hello"}]}`, http.StatusBadRequest},
	} {
		t.Run(test.name, func(t *testing.T) {
			app := NewHandler(nil, nil, WithAssistant(nil))
			request := httptest.NewRequest(http.MethodPost, "http://localhost:8080/v1/assistant/chat", strings.NewReader(test.body))
			request.RemoteAddr = test.peer
			request.Header.Set("Content-Type", "application/json")
			response := httptest.NewRecorder()
			app.ServeHTTP(response, request)
			if response.Code != test.status {
				t.Fatalf("status %d, want %d: %s", response.Code, test.status, response.Body)
			}
		})
	}
}
