package main

import (
	"log"

	"app/internal/config"
	"app/internal/database"
	"app/internal/server"
)

func main() {
	cfg := config.LoadConfig()

	db, err := database.Connect(cfg)
	if err != nil {
		log.Fatalf("Gagal terhubung ke basis data: %v", err)
	}
	if err := database.Migrate(db); err != nil {
		log.Fatalf("Gagal migrasi basis data: %v", err)
	}
	if err := database.Seed(db, cfg); err != nil {
		log.Printf("Peringatan: seeder gagal dijalankan: %v", err)
	}

	r := server.SetupRouter(cfg, db)
	log.Printf("Delcom Blog berjalan pada port %s", cfg.AppPort)
	if err := r.Run(":" + cfg.AppPort); err != nil {
		log.Fatalf("Server berhenti: %v", err)
	}
}
