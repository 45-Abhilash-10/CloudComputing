package main

import (
	"encoding/json"
	"io"
	"log"
	"net/http"
	"os"
	"runtime"
	"strconv"
	"time"
)

var (
	engine    *InferenceEngine
	startTime time.Time
)

type HealthResponse struct {
	Status        string  `json:"status"`
	Runtime       string  `json:"runtime"`
	Architecture  string  `json:"architecture"`
	UptimeSeconds float64 `json:"uptime_seconds"`
	MemoryAllocMB float64 `json:"memory_alloc_mb"`
	MemorySysMB   float64 `json:"memory_sys_mb"`
	NumGoroutine  int     `json:"num_goroutine"`
	NumCPU        int     `json:"num_cpu"`
}

type ClassifyResponse struct {
	Status       string                 `json:"status"`
	Runtime      string                 `json:"runtime"`
	Architecture string                 `json:"architecture"`
	Predictions  []Prediction           `json:"predictions"`
	Telemetry    map[string]interface{} `json:"telemetry"`
}

func healthHandler(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodGet {
		http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
		return
	}

	var m runtime.MemStats
	runtime.ReadMemStats(&m)

	res := HealthResponse{
		Status:        "healthy",
		Runtime:       "Docker-Go (OCI Container)",
		Architecture:  runtime.GOARCH,
		UptimeSeconds: time.Since(startTime).Seconds(),
		MemoryAllocMB: float64(m.Alloc) / (1024 * 1024),
		MemorySysMB:   float64(m.Sys) / (1024 * 1024),
		NumGoroutine:  runtime.NumGoroutine(),
		NumCPU:        runtime.NumCPU(),
	}

	w.Header().Set("Content-Type", "application/json")
	w.Header().Set("Access-Control-Allow-Origin", "*")
	json.NewEncoder(w).Encode(res)
}

func classifyHandler(w http.ResponseWriter, r *http.Request) {
	if r.Method == http.MethodOptions {
		w.Header().Set("Access-Control-Allow-Origin", "*")
		w.Header().Set("Access-Control-Allow-Methods", "POST, OPTIONS")
		w.Header().Set("Access-Control-Allow-Headers", "Content-Type")
		w.WriteHeader(http.StatusOK)
		return
	}

	if r.Method != http.MethodPost {
		http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
		return
	}

	startTotal := time.Now()

	// Parse multipart or raw body
	var imgBytes []byte
	var err error

	err = r.ParseMultipartForm(32 << 20) // 32MB max
	if err == nil && r.MultipartForm != nil {
		files := r.MultipartForm.File["file"]
		if len(files) > 0 {
			f, err := files[0].Open()
			if err == nil {
				defer f.Close()
				imgBytes, _ = io.ReadAll(f)
			}
		}
	}

	if len(imgBytes) == 0 {
		imgBytes, err = io.ReadAll(r.Body)
		if err != nil || len(imgBytes) == 0 {
			http.Error(w, "Invalid or empty image payload", http.StatusBadRequest)
			return
		}
	}

	// Parse top_k parameter
	topK := 5
	if topKStr := r.URL.Query().Get("top_k"); topKStr != "" {
		if k, err := strconv.Atoi(topKStr); err == nil && k > 0 && k <= 20 {
			topK = k
		}
	}

	// Preprocessing
	startPre := time.Now()
	tensor, err := PreprocessImage(imgBytes)
	preDuration := time.Since(startPre)
	if err != nil {
		http.Error(w, err.Error(), http.StatusBadRequest)
		return
	}

	// Inference
	preds, inferDuration, err := engine.Predict(tensor, topK)
	if err != nil {
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}

	totalDuration := time.Since(startTotal)

	var m runtime.MemStats
	runtime.ReadMemStats(&m)

	res := ClassifyResponse{
		Status:       "success",
		Runtime:      "Docker-Go",
		Architecture: runtime.GOARCH,
		Predictions:  preds,
		Telemetry: map[string]interface{}{
			"total_time_ms":      float64(totalDuration.Microseconds()) / 1000.0,
			"preprocess_time_ms": float64(preDuration.Microseconds()) / 1000.0,
			"inference_time_ms":  float64(inferDuration.Microseconds()) / 1000.0,
			"memory_alloc_mb":    float64(m.Alloc) / (1024 * 1024),
			"payload_bytes":      len(imgBytes),
		},
	}

	w.Header().Set("Content-Type", "application/json")
	w.Header().Set("Access-Control-Allow-Origin", "*")
	json.NewEncoder(w).Encode(res)
}

func main() {
	startTime = time.Now()
	labelsPath := os.Getenv("LABELS_PATH")
	if labelsPath == "" {
		labelsPath = "../../models/imagenet_classes.json"
	}

	var err error
	engine, err = NewInferenceEngine(labelsPath)
	if err != nil {
		log.Printf("[WARN] Failed to load labels: %v, using defaults", err)
	}

	port := os.Getenv("PORT")
	if port == "" {
		port = "8081"
	}

	http.HandleFunc("/health", healthHandler)
	http.HandleFunc("/classify", classifyHandler)

	log.Printf("Starting Go MobileNetV2 microservice on :%s (GOARCH: %s, CPUs: %d)...", port, runtime.GOARCH, runtime.NumCPU())
	if err := http.ListenAndServe(":"+port, nil); err != nil {
		log.Fatalf("Server failed: %v", err)
	}
}
