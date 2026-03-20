package main

import (
	"context"
	"database/sql"
	"fmt"
	"log"
	"net/http"
	"os"
	"os/signal"
	"syscall"
	"time"

	_ "github.com/go-sql-driver/mysql"
	"github.com/prometheus/client_golang/prometheus"
	"github.com/prometheus/client_golang/prometheus/promhttp"
)

// ─── Metrics ─────────────────────────────────────────────────
var (
	httpRequestsTotal = prometheus.NewCounterVec(
		prometheus.CounterOpts{
			Name: "http_requests_total",
			Help: "Total number of HTTP requests",
		},
		[]string{"method", "path", "status"},
	)
	httpRequestDuration = prometheus.NewHistogramVec(
		prometheus.HistogramOpts{
			Name:    "http_request_duration_seconds",
			Help:    "HTTP request duration in seconds",
			Buckets: prometheus.DefBuckets,
		},
		[]string{"method", "path"},
	)
	dbConnections = prometheus.NewGauge(
		prometheus.GaugeOpts{
			Name: "db_connections_open",
			Help: "Number of open DB connections",
		},
	)
)

func init() {
	prometheus.MustRegister(httpRequestsTotal, httpRequestDuration, dbConnections)
}

// ─── App ──────────────────────────────────────────────────────
type App struct {
	db *sql.DB
}

func NewApp() (*App, error) {
	dsn := fmt.Sprintf("%s:%s@tcp(%s)/%s?parseTime=true&timeout=10s",
		getEnv("DB_USER", "admin"),
		getEnv("DB_PASSWORD", ""),
		getEnv("DB_HOST", "localhost:3306"),
		getEnv("DB_NAME", "appdb"),
	)

	db, err := sql.Open("mysql", dsn)
	if err != nil {
		return nil, fmt.Errorf("open db: %w", err)
	}

	db.SetMaxOpenConns(25)
	db.SetMaxIdleConns(10)
	db.SetConnMaxLifetime(5 * time.Minute)

	return &App{db: db}, nil
}

// ─── Handlers ─────────────────────────────────────────────────
func (a *App) handleHealth(w http.ResponseWriter, r *http.Request) {
	w.WriteHeader(http.StatusOK)
	fmt.Fprintln(w, "ok")
}

func (a *App) handleReady(w http.ResponseWriter, r *http.Request) {
	ctx, cancel := context.WithTimeout(r.Context(), 2*time.Second)
	defer cancel()

	if err := a.db.PingContext(ctx); err != nil {
		http.Error(w, "db not ready: "+err.Error(), http.StatusServiceUnavailable)
		return
	}
	w.WriteHeader(http.StatusOK)
	fmt.Fprintln(w, "ready")
}

func (a *App) handleHello(w http.ResponseWriter, r *http.Request) {
	env := getEnv("APP_ENV", "unknown")
	fmt.Fprintf(w, "Hello from Go app! ENV=%s\n", env)
}

// ─── Middleware ───────────────────────────────────────────────
func metricsMiddleware(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		start := time.Now()
		rw := &responseWriter{ResponseWriter: w, status: 200}
		next.ServeHTTP(rw, r)

		duration := time.Since(start).Seconds()
		status := fmt.Sprintf("%d", rw.status)

		httpRequestsTotal.WithLabelValues(r.Method, r.URL.Path, status).Inc()
		httpRequestDuration.WithLabelValues(r.Method, r.URL.Path).Observe(duration)
	})
}

type responseWriter struct {
	http.ResponseWriter
	status int
}

func (rw *responseWriter) WriteHeader(status int) {
	rw.status = status
	rw.ResponseWriter.WriteHeader(status)
}

// ─── Main ─────────────────────────────────────────────────────
func main() {
	app, err := NewApp()
	if err != nil {
		log.Printf("Warning: could not connect to DB: %v", err)
		app = &App{}
	}

	// App server — порт 8080
	appMux := http.NewServeMux()
	appMux.HandleFunc("/health", app.handleHealth)
	appMux.HandleFunc("/ready", app.handleReady)
	appMux.HandleFunc("/", app.handleHello)

	appServer := &http.Server{
		Addr:         ":" + getEnv("APP_PORT", "8080"),
		Handler:      metricsMiddleware(appMux),
		ReadTimeout:  15 * time.Second,
		WriteTimeout: 15 * time.Second,
		IdleTimeout:  60 * time.Second,
	}

	// Metrics server — порт 8081
	metricsMux := http.NewServeMux()
	metricsMux.Handle("/metrics", promhttp.Handler())

	metricsServer := &http.Server{
		Addr:    ":" + getEnv("METRICS_PORT", "8081"),
		Handler: metricsMux,
	}

	// Start both servers
	go func() {
		log.Printf("App server starting on %s", appServer.Addr)
		if err := appServer.ListenAndServe(); err != nil && err != http.ErrServerClosed {
			log.Fatalf("App server error: %v", err)
		}
	}()

	go func() {
		log.Printf("Metrics server starting on %s", metricsServer.Addr)
		if err := metricsServer.ListenAndServe(); err != nil && err != http.ErrServerClosed {
			log.Fatalf("Metrics server error: %v", err)
		}
	}()

	// Update DB metrics
	if app.db != nil {
		go func() {
			for range time.Tick(15 * time.Second) {
				stats := app.db.Stats()
				dbConnections.Set(float64(stats.OpenConnections))
			}
		}()
	}

	// Graceful shutdown
	quit := make(chan os.Signal, 1)
	signal.Notify(quit, syscall.SIGINT, syscall.SIGTERM)
	<-quit

	log.Println("Shutting down gracefully...")
	ctx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
	defer cancel()

	appServer.Shutdown(ctx)
	metricsServer.Shutdown(ctx)

	if app.db != nil {
		app.db.Close()
	}

	log.Println("Server stopped")
}

func getEnv(key, fallback string) string {
	if v := os.Getenv(key); v != "" {
		return v
	}
	return fallback
}
