package main

import (
	"context"
	"errors"
	"log"
	"net"
	"net/http"
	"os"
	"os/exec"
	"path/filepath"
	"strconv"
	"strings"
	"time"

	"github.com/opsst/PromptLearn/backend/internal/assessmentrubric"
	"github.com/opsst/PromptLearn/backend/internal/assignmentreview"
	"github.com/opsst/PromptLearn/backend/internal/assistant"
	"github.com/opsst/PromptLearn/backend/internal/course"
	"github.com/opsst/PromptLearn/backend/internal/httpapi"
	"github.com/opsst/PromptLearn/backend/internal/openai"
	"github.com/opsst/PromptLearn/backend/internal/replay"
	"github.com/opsst/PromptLearn/backend/internal/syllabus"
)

const modelTimeout = 60 * time.Second

func main() {
	addr := os.Getenv("HTTP_ADDR")
	if addr == "" {
		addr = "127.0.0.1:8080"
	}

	var planner syllabus.Planner = syllabus.CurriculumPlanner{}
	mode := strings.TrimSpace(os.Getenv("SYLLABUS_PLANNER"))
	key := strings.TrimSpace(os.Getenv("OPENAI_API_KEY"))
	model := strings.TrimSpace(os.Getenv("OPENAI_MODEL"))
	if model == "" {
		model = "gpt-4.1-mini"
	}
	client := openai.NewClient(key, model, &http.Client{Timeout: modelTimeout})
	switch mode {
	case "", "auto", "mock", "openai":
	default:
		log.Fatal("SYLLABUS_PLANNER must be auto, mock or openai")
	}
	if mode == "openai" && key == "" {
		log.Fatal("OPENAI_API_KEY is required when SYLLABUS_PLANNER=openai")
	}
	if mode != "mock" && key != "" {
		planner = syllabus.OpenAIPlanner{Client: client}
	}
	var reviewer assignmentreview.Reviewer = assignmentreview.DemoReviewer{}
	var paperOCR assignmentreview.PaperOCR
	reviewMode := strings.TrimSpace(os.Getenv("ASSIGNMENT_REVIEW_MODE"))
	switch reviewMode {
	case "":
		reviewMode = "mock"
	case "mock":
	case "openai":
		if key == "" {
			log.Fatal("OPENAI_API_KEY is required when ASSIGNMENT_REVIEW_MODE=openai")
		}
		openAIReviewer := assignmentreview.OpenAIReviewer{Client: client}
		reviewer, paperOCR = openAIReviewer, openAIReviewer
	default:
		log.Fatal("ASSIGNMENT_REVIEW_MODE must be mock or openai")
	}
	dataDir := os.Getenv("PROMPTLEARN_DATA_DIR")
	if dataDir == "" {
		dataDir = ".promptlearn-data"
	}
	reviewDatabaseURL := os.Getenv("ASSIGNMENT_REVIEW_DATABASE_URL")
	localReview := reviewMode == "openai" || reviewDatabaseURL != ""
	if localReview {
		host, _, err := net.SplitHostPort(addr)
		if err != nil || !httpapi.IsLoopbackHost(host) {
			log.Fatal("live or PostgreSQL assignment review requires a loopback HTTP_ADDR")
		}
	}
	var reviewRepo assignmentreview.Repository
	reviewHistoryDir := filepath.Join(dataDir, "assignment-reviews")
	if reviewDatabaseURL != "" {
		ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
		repo, err := assignmentreview.OpenPostgresDemo(ctx, reviewDatabaseURL, reviewMode)
		cancel()
		if err != nil {
			log.Fatal(err)
		}
		defer repo.Close()
		reviewRepo = repo
	} else {
		repo, err := assignmentreview.OpenDemoRepository(reviewHistoryDir, reviewMode)
		if err != nil {
			log.Fatal(err)
		}
		reviewRepo = repo
	}
	reviews := assignmentreview.NewService(reviewRepo, reviewer, paperOCR)
	reviewRoute := httpapi.WithAssignmentReview(reviews)
	var rubricGenerator assessmentrubric.Generator
	if key != "" {
		rubricGenerator = assessmentrubric.OpenAIGenerator{Client: client}
	}
	rubricRoute := httpapi.WithAssessmentRubrics(rubricGenerator)
	var assistantResponder assistant.Responder
	if key != "" {
		assistantResponder = assistant.OpenAIResponder{Client: client}
	}
	assistantRoute := httpapi.WithAssistant(assistantResponder)

	var store course.Repository
	if databaseURL := strings.TrimSpace(os.Getenv("COURSE_SYLLABUS_DATABASE_URL")); databaseURL != "" {
		host, _, err := net.SplitHostPort(addr)
		if err != nil || !httpapi.IsLoopbackHost(host) {
			log.Fatal("PostgreSQL syllabus demo requires a loopback HTTP_ADDR")
		}
		ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
		postgresStore, err := course.OpenPostgresDemo(ctx, databaseURL)
		cancel()
		if err != nil {
			log.Fatal(err)
		}
		defer postgresStore.Close()
		store = postgresStore
	} else {
		fileStore, err := course.OpenStore(dataDir)
		if err != nil {
			log.Fatal(err)
		}
		store = fileStore
	}

	syllabi := syllabus.NewService(planner)
	handler := httpapi.NewHandler(syllabi, store, reviewRoute, rubricRoute, assistantRoute)
	readTimeout := 10 * time.Second
	writeTimeout := modelTimeout + 15*time.Second
	if databaseURL := os.Getenv("REPLAY_DEMO_DATABASE_URL"); databaseURL != "" {
		host, _, err := net.SplitHostPort(addr)
		if err != nil || !httpapi.IsLoopbackHost(host) {
			log.Fatal("the replay demo requires a loopback HTTP_ADDR")
		}
		if _, err := exec.LookPath("ffprobe"); err != nil {
			log.Fatal("the replay demo requires ffprobe on PATH")
		}
		mediaDir := filepath.Join(dataDir, "replay")
		if err := os.MkdirAll(mediaDir, 0700); err != nil {
			log.Fatal(err)
		}
		webDir := os.Getenv("REPLAY_DEMO_WEB_DIR")
		if webDir != "" {
			if _, err := os.Stat(filepath.Join(webDir, "index.html")); err != nil {
				log.Fatal("REPLAY_DEMO_WEB_DIR must point to a built Flutter web app")
			}
			if err := checkPrivateWebDirectories(mediaDir, webDir); err != nil {
				log.Fatal(err)
			}
			if _, err := os.Stat(reviewHistoryDir); !errors.Is(err, os.ErrNotExist) {
				if err := checkPrivateWebDirectories(reviewHistoryDir, webDir); err != nil {
					log.Fatal(err)
				}
			}
		}
		ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
		replays, err := replay.Open(ctx, databaseURL)
		cancel()
		if err != nil {
			log.Fatalf("open replay database: %v", err)
		}
		defer replays.Close()
		transcriber, err := configureReplayTranscriber(key)
		if err != nil {
			log.Fatalf("configure replay transcription: %v", err)
		}
		handler = httpapi.NewDemoHandler(syllabi, store, replays, transcriber, mediaDir, webDir, reviewRoute, rubricRoute, assistantRoute)
		if transcriber != nil {
			writeTimeout = 4 * time.Minute
		}
		readTimeout = 90 * time.Second
	}

	server := &http.Server{
		Addr:              addr,
		Handler:           handler,
		ReadHeaderTimeout: 5 * time.Second,
		ReadTimeout:       readTimeout,
		WriteTimeout:      writeTimeout,
		IdleTimeout:       60 * time.Second,
	}

	log.Printf("PromptLearn listening on %s", addr)
	log.Fatal(server.ListenAndServe())
}

func configureReplayTranscriber(key string) (replay.Transcriber, error) {
	model := strings.TrimSpace(os.Getenv("REPLAY_WHISPER_MODEL"))
	mode := strings.TrimSpace(os.Getenv("REPLAY_TRANSCRIBER"))
	if mode == "" {
		switch {
		case key != "":
			mode = "openai"
		case model != "":
			mode = "local"
		default:
			return nil, nil
		}
	}
	switch mode {
	case "openai":
		if key == "" {
			return nil, errors.New("OPENAI_API_KEY is required when REPLAY_TRANSCRIBER=openai")
		}
		client := openai.NewTranscriptionClient(key, &http.Client{
			Timeout: 40 * time.Second,
			CheckRedirect: func(*http.Request, []*http.Request) error {
				return http.ErrUseLastResponse
			},
		})
		return replay.NewOpenAITranscriber(client)
	case "local":
		if model == "" {
			return nil, errors.New("REPLAY_WHISPER_MODEL is required when REPLAY_TRANSCRIBER=local")
		}
	default:
		return nil, errors.New("REPLAY_TRANSCRIBER must be openai or local")
	}

	useGPU := false
	if value := os.Getenv("REPLAY_WHISPER_USE_GPU"); value != "" {
		var err error
		useGPU, err = strconv.ParseBool(value)
		if err != nil {
			return nil, errors.New("REPLAY_WHISPER_USE_GPU must be true or false")
		}
	}
	return replay.NewWhisper(os.Getenv("REPLAY_WHISPER_PYTHON"), model, useGPU)
}

func checkPrivateWebDirectories(privateDir, webDir string) error {
	var paths []string
	for _, directory := range []string{privateDir, webDir} {
		resolved, err := filepath.EvalSymlinks(directory)
		if err != nil {
			return err
		}
		absolute, err := filepath.Abs(resolved)
		if err != nil {
			return err
		}
		paths = append(paths, absolute)
	}
	separator := string(os.PathSeparator)
	privatePath, webPath := paths[0], paths[1]
	if privatePath == webPath || privatePath == separator || webPath == separator ||
		strings.HasPrefix(privatePath, webPath+separator) || strings.HasPrefix(webPath, privatePath+separator) {
		return errors.New("private backend data and the Flutter web directory must not overlap")
	}
	return nil
}
