package main

import (
	"context"
	"encoding/json"
	"fmt"
	"log"
	"net/http"
	"os"
	"os/exec"
	"time"
)

const (
	RCloneScriptEnv = "RCLONE_SCRIPT"
)

func dump(v interface{}) {
	enc := json.NewEncoder(os.Stdout)
	enc.SetIndent("", "  ")
	enc.Encode(v)
}

type Event struct {
	ID              string
	Topic           string
	Subject         string
	EventType       string
	EventTime       time.Time
	DataVersion     string
	MetadataVersion string
	Data            map[string]json.RawMessage
}

type InvokeRequest struct {
	Data     map[string]json.RawMessage
	Metadata map[string]interface{}
}

type InvokeResponse struct {
	Outputs     map[string]interface{}
	Logs        []string
	ReturnValue interface{}
}

type ErrorResponse struct {
	Error string `json:"error"`
}

type CustomHandler func(res *InvokeRequest, req *InvokeResponse) error

func MakeHandlerFunc(fn CustomHandler) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		req := &InvokeRequest{}
		res := &InvokeResponse{}
		dec := json.NewDecoder(r.Body)
		err := dec.Decode(req)
		if err != nil {
			w.WriteHeader(http.StatusBadRequest)
			return
		}
		var resStatus int
		var resBody interface{}
		err = fn(req, res)
		if err == nil {
			resStatus = http.StatusOK
			resBody = res
		} else {
			resStatus = http.StatusBadRequest
			resBody = ErrorResponse{Error: err.Error()}
		}
		resBytes, err := json.Marshal(resBody)
		if err != nil {
			resStatus = http.StatusInternalServerError
			resBytes, _ = json.Marshal(ErrorResponse{Error: err.Error()})
		}
		log.Println("RESPONSE:", string(resBytes))
		w.Header().Set("Content-Type", "application/json")
		w.WriteHeader(resStatus)
		w.Write(resBytes)
	}
}

type App struct {
	Queue chan struct{}
}

func (app *App) QueueCustomHandler(req *InvokeRequest, res *InvokeResponse) error {
	var s1 string
	err := json.Unmarshal(req.Data["item"], &s1)
	if err != nil {
		return fmt.Errorf("s1 unmarshal failed: %w", err)
	}
	var s2 string
	err = json.Unmarshal([]byte(s1), &s2)
	if err != nil {
		return fmt.Errorf("s2 unmarshal failed: %w", err)
	}
	var event Event
	err = json.Unmarshal([]byte(s2), &event)
	if err != nil {
		return fmt.Errorf("event unmarshal failed: %w", err)
	}
	log.Println("QUEUE:", event.EventTime.Format(time.RFC3339), event.EventType, event.Subject)
	app.Queue <- struct{}{}
	return nil
}

func (app *App) TimerCustomHandler(req *InvokeRequest, res *InvokeResponse) error {
	b, _ := json.Marshal(req.Data["item"])
	log.Println("TIMER:", string(b))
	app.Queue <- struct{}{}
	return nil
}

func (app *App) RCloneGoroutine(ctx context.Context) {
	log.Println("RCLONE: START")
loop1:
	for {
		log.Println("RCLONE: WAIT")
		c := 0
		var timeout <-chan time.Time
	loop2:
		for {
			select {
			case <-app.Queue:
				c++
				if timeout == nil {
					timeout = time.After(2 * time.Second)
				}
			case <-timeout:
				break loop2
			case <-ctx.Done():
				break loop1
			}
		}
		script, ok := os.LookupEnv(RCloneScriptEnv)
		if !ok {
			log.Println("RCLONE: " + RCloneScriptEnv + " is not set!")
			continue
		}
		log.Printf("RCLONE: EXEC\n%s", script)
		cmd := exec.Command("sh", "-c", script)
		cmd.Stdout = os.Stdout
		cmd.Stderr = os.Stderr
		err := cmd.Run()
		if err != nil {
			log.Println("RCLONE: FAILED:", err)
			continue
		}
		log.Println("RCLONE: DONE")
	}
	log.Printf("RCLONE: TERMINATE: %s", ctx.Err())
}

func (app *App) Main() error {
	log.Println("SERVER: START")

	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()
	go app.RCloneGoroutine(ctx)

	listenAddr := ":8080"
	if val, ok := os.LookupEnv("FUNCTIONS_CUSTOMHANDLER_PORT"); ok {
		listenAddr = ":" + val
	}
	http.HandleFunc("/QueueTrigger1", MakeHandlerFunc(app.QueueCustomHandler))
	http.HandleFunc("/TimerTrigger1", MakeHandlerFunc(app.TimerCustomHandler))

	log.Printf("SERVER: LISTEN ON %s", listenAddr)
	return http.ListenAndServe(listenAddr, nil)
}

func NewApp() *App {
	return &App{
		Queue: make(chan struct{}, 100),
	}
}

func main() {
	app := NewApp()
	err := app.Main()
	if err != nil {
		log.Fatal(err)
	}
}
