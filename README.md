# ifs24005-pabwe2026-sk-p9-be-golang-gin

Backend **Delcom Blog**: platform publikasi artikel multi-tier (Studi Kasus C, PABWE 2026 P9).
REST API murni (Golang Gin, Clean Architecture & Feature-First) dengan PostgreSQL 17, GORM,
JWT, Swagger UI, dan **AI Blog Generator terintegrasi Search Engine**.
Backend dan frontend dideploy terpisah: CORS aktif, tidak ada berkas statis frontend di sini.

## Fitur

- Autentikasi JWT (HS256, berlaku 24 jam): registrasi, login (username **atau** email), logout, profil.
- Tiga tingkat akses: **publik** (guest), **penulis** (member), **admin**.
- Artikel Markdown: slug unik otomatis (`-2`, `-3`, ...), estimasi waktu baca (`ceil(kata/200)`, minimal 1 menit),
  toggle Draf ↔ Terbit beserta `published_at`, statistik 3 kartu.
- Pencarian publik `?q=` (judul/ringkasan/konten, tidak peka huruf besar-kecil) dan filter `?category=`.
- Kepemilikan artikel ditegakkan: mengakses artikel orang lain → **404** (keberadaan tidak dibocorkan).
- **AI Blog Generator**: `POST /api/posts/ai-generate` memanggil Search Engine (opsional) lalu OpenAI
  Chat Completions; hasil berupa judul, kategori, ringkasan, konten Markdown, dan `search_sources`.
  Kegagalan Search Engine tidak menggagalkan request; hasil **tidak** otomatis disimpan.
- Swagger UI + `/api.json` dinamis (host/scheme mengikuti request, menghormati `X-Forwarded-*`).
- Format respons standar `{status, message, data?}`; 404 rute tidak dikenal juga JSON.

## Struktur

```
cmd/server/main.go            entry point
docs/                         api.json, swagger.json, swagger.yaml, docs.go
internal/config               pembaca environment
internal/database             koneksi, migrasi, seeder idempoten
internal/middleware           CORS, Auth JWT, RequireRole, RateLimiter
internal/response             helper respons standar
internal/features/auth        dto, repository, service, handler
internal/features/post        artikel + endpoint admin (slug, reading time, stats)
internal/features/ai          search.go, client.go, service, handler
internal/server               router + Swagger UI
```

## Konfigurasi

```bash
cp .env.example .env
```

| Variabel | Bawaan | Keterangan |
|---|---|---|
| `APP_ENV` | `development` | `production` → Gin release mode |
| `APP_PORT` | `8081` | port HTTP |
| `APP_KEY` | (lihat `.env.example`) | kunci penandatangan JWT — **ganti di produksi** |
| `ADMIN_USERNAME` / `ADMIN_PASSWORD` | `admin` / `admin` | kredensial admin seeder |
| `DB_CONNECTION` | `pgsql` | `pgsql` atau `sqlite` (untuk uji lokal, `DB_DATABASE=file.db` atau `:memory:`) |
| `DB_HOST` `DB_PORT` `DB_DATABASE` `DB_USERNAME` `DB_PASSWORD` `DB_SSLMODE` | `127.0.0.1` `5432` `pabwe_p9_blog` `postgres` `postgres` `disable` | koneksi PostgreSQL |
| `SEARCH_ENGINE_ENDPOINT` | `https://delcom.org/api/v1/search` | dipanggil sebagai `?q=<topik>` (timeout 10 dtk) |
| `OPENAI_ENDPOINT` / `OPENAI_KEY` / `OPENAI_MODEL` | `https://delcom.org/api/v1` / `key` / `nama-model` | API OpenAI-compatible |

Nilai bawaan di `internal/config/config.go` sama dengan `.env.example`, sehingga aplikasi tetap berjalan tanpa `.env`.

## Menjalankan

```bash
psql -U postgres -c "CREATE DATABASE pabwe_p9_blog;"
go run cmd/server/main.go
# Delcom Blog berjalan pada port 8081
```

Swagger UI: <http://localhost:8081/swagger/index.html> — spesifikasi: <http://localhost:8081/api.json>.

### Seeder (idempoten)

Dijalankan otomatis saat start; menjalankannya berulang kali tidak menggandakan data.

| Akun | Password | Role |
|---|---|---|
| `admin` | `admin` | admin |
| `member` | `member` | member |

Ditambah 10 artikel contoh (campuran terbit/draf, mencakup 6 kategori, milik admin dan member).

## Endpoint

| Method | Endpoint | Akses |
|---|---|---|
| GET | `/swagger/*any` (`/swagger` → `/swagger/index.html`) | Publik |
| GET | `/api.json` | Publik |
| GET | `/api/public/categories` | Publik |
| GET | `/api/public/posts` (`?q=`, `?category=`) | Publik |
| GET | `/api/public/posts/:slug` | Publik |
| POST | `/api/auth/register` | Publik |
| POST | `/api/auth/login` | Publik |
| POST | `/api/auth/logout` | Authenticated |
| GET, PUT | `/api/auth/profile` | Authenticated |
| GET, POST | `/api/posts` | Penulis |
| GET | `/api/posts/stats` | Penulis (`total`, `total_terbit`, `total_draf`, alias `total_selesai`, `belum_selesai`) |
| GET, PUT, DELETE | `/api/posts/:id` | Penulis (milik sendiri) |
| PATCH | `/api/posts/:id/toggle-publish` | Penulis |
| POST | `/api/posts/ai-generate` | Penulis |
| GET | `/api/admin/users` | Admin (+ `total_posts`, `total_published`) |
| GET | `/api/admin/posts` | Admin |
| GET | `/api/admin/users/:id/posts` | Admin (404 bila pengguna tidak ada) |

Kode status: 2xx `success`, 4xx `fail`, 5xx `error`. Token: `Authorization: Bearer <jwt>`.
Test otomatis `internal/server` memastikan rute yang terdaftar identik dengan yang tercantum di `docs/api.json`.

## Pengujian

```bash
go test -v -cover ./internal/...   # seluruh paket: coverage 100.0% of statements
go test ./docs/...
gofmt -l . && go vet ./...
```

Test memakai SQLite in-memory (`glebarez/sqlite`, foreign key aktif agar cascade teruji), `testify`,
dan `httptest.Server` sebagai tiruan OpenAI dan Search Engine.

## Build biner

```bash
go build -o server.exe cmd/server/main.go     # Windows
CGO_ENABLED=0 go build -o server ./cmd/server # Linux/macOS
./server
```

Biner membaca `.env` dari **direktori aktif** saat dijalankan — letakkan `.env` di samping biner.

## CI/CD (Jenkins)

`Jenkinsfile`: Checkout → Install Dependencies → Test (`go test -v -coverprofile=coverage.out -covermode=atomic ./internal/...`)
→ Build (`CGO_ENABLED=0 GOOS=linux go build -ldflags="-s -w" -o server ./cmd/server`) → Trivy Scan → Package
(tanpa `.env*`, biner, dan artefak coverage) → Publish → Deploy.
Aturan biner di `.gitignore` diawali slash (`/server`, `/main`, `/app`) agar folder `internal/server/` tidak ikut terabaikan.
