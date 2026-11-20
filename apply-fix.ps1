# apply-fix.ps1 - menyelaraskan backend p9 dengan kontrak tes API Delcom.
# Jalankan dari folder repo (yang berisi go.mod):  powershell -ExecutionPolicy Bypass -File .\apply-fix.ps1
$ErrorActionPreference = 'Stop'
if (-not (Test-Path 'go.mod')) { throw 'Jalankan skrip ini dari folder repo (yang berisi go.mod).' }
$utf8 = New-Object System.Text.UTF8Encoding($false)
function Write-Repo([string]$Path, [string]$Content) {
  $full = Join-Path (Get-Location) $Path
  $dir = Split-Path $full -Parent
  if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir | Out-Null }
  [System.IO.File]::WriteAllText($full, $Content, $utf8)
  Write-Host "ditulis: $Path"
}

Write-Repo 'docs/api.json' @'
{
  "swagger": "2.0",
  "info": {
    "title": "Delcom Blog REST API",
    "description": "Dokumentasi RESTful API Delcom Blog (Golang Gin, Clean Architecture & Feature-First) dengan AI Blog Generator terintegrasi Search Engine. Seluruh respons berformat {status, message, data?}.",
    "version": "1.0.0",
    "contact": {
      "name": "Delcom - Labs"
    }
  },
  "host": "localhost:8081",
  "basePath": "/",
  "schemes": [
    "http"
  ],
  "consumes": [
    "application/json"
  ],
  "produces": [
    "application/json"
  ],
  "tags": [
    {
      "name": "Dokumentasi"
    },
    {
      "name": "Publik"
    },
    {
      "name": "Autentikasi"
    },
    {
      "name": "Penulis"
    },
    {
      "name": "Admin"
    }
  ],
  "securityDefinitions": {
    "BearerAuth": {
      "type": "apiKey",
      "name": "Authorization",
      "in": "header",
      "description": "Masukkan: Bearer <token JWT>"
    }
  },
  "paths": {
    "/swagger/{any}": {
      "get": {
        "tags": [
          "Dokumentasi"
        ],
        "summary": "Swagger UI",
        "description": "Dokumentasi interaktif Swagger UI (http://localhost:8081/swagger/index.html). `/swagger` dialihkan ke `/swagger/index.html`.",
        "produces": [
          "application/json"
        ],
        "responses": {
          "200": {
            "description": "Halaman Swagger UI"
          }
        },
        "parameters": [
          {
            "name": "any",
            "in": "path",
            "required": true,
            "type": "string",
            "description": "Berkas Swagger UI, mis. index.html"
          }
        ]
      }
    },
    "/api.json": {
      "get": {
        "tags": [
          "Dokumentasi"
        ],
        "summary": "Spesifikasi OpenAPI dinamis",
        "description": "Spesifikasi OpenAPI/Swagger JSON; host dan scheme menyesuaikan request (menghormati X-Forwarded-Host dan X-Forwarded-Proto).",
        "produces": [
          "application/json"
        ],
        "responses": {
          "200": {
            "description": "Dokumen OpenAPI 2.0"
          }
        }
      }
    },
    "/api/public/categories": {
      "get": {
        "tags": [
          "Publik"
        ],
        "summary": "Daftar kategori",
        "description": "Enam kategori artikel: Teknologi, Pendidikan, Gaya Hidup, Bisnis, Opini, Umum.",
        "produces": [
          "application/json"
        ],
        "responses": {
          "200": {
            "description": "Daftar kategori",
            "schema": {
              "$ref": "#/definitions/CategoriesEnvelope"
            }
          }
        }
      }
    },
    "/api/public/posts": {
      "get": {
        "tags": [
          "Publik"
        ],
        "summary": "Daftar artikel terbit",
        "description": "Hanya artikel `is_published=true`, terbaru lebih dulu. Pencarian `q` tidak membedakan huruf besar/kecil pada judul, ringkasan, dan konten.",
        "produces": [
          "application/json"
        ],
        "responses": {
          "200": {
            "description": "Daftar artikel terbit",
            "schema": {
              "$ref": "#/definitions/PublicPostListEnvelope"
            }
          },
          "500": {
            "description": "Kesalahan server",
            "schema": {
              "$ref": "#/definitions/ErrorResponse"
            }
          }
        },
        "parameters": [
          {
            "name": "q",
            "in": "query",
            "type": "string",
            "description": "Kata kunci pencarian"
          },
          {
            "name": "category",
            "in": "query",
            "type": "string",
            "enum": [
              "Teknologi",
              "Pendidikan",
              "Gaya Hidup",
              "Bisnis",
              "Opini",
              "Umum"
            ],
            "description": "Filter kategori (kosong/Semua = semua kategori)"
          }
        ]
      }
    },
    "/api/public/posts/{slug}": {
      "get": {
        "tags": [
          "Publik"
        ],
        "summary": "Detail artikel publik",
        "description": "Artikel terbit berdasarkan slug, lengkap dengan penulis dan reading_time. Draf menghasilkan 404.",
        "produces": [
          "application/json"
        ],
        "responses": {
          "200": {
            "description": "Detail artikel",
            "schema": {
              "$ref": "#/definitions/PublicPostEnvelope"
            }
          },
          "404": {
            "description": "Artikel tidak ditemukan",
            "schema": {
              "$ref": "#/definitions/FailResponse"
            }
          },
          "500": {
            "description": "Kesalahan server",
            "schema": {
              "$ref": "#/definitions/ErrorResponse"
            }
          }
        },
        "parameters": [
          {
            "name": "slug",
            "in": "path",
            "required": true,
            "type": "string",
            "description": "Slug artikel"
          }
        ]
      }
    },
    "/api/auth/register": {
      "post": {
        "tags": [
          "Autentikasi"
        ],
        "summary": "Registrasi akun",
        "description": "Membuat akun penulis dan langsung mengembalikan token JWT. Field `role` opsional: hanya `admin` atau `member` yang diterima, nilai lain dipaksa `member`.",
        "produces": [
          "application/json"
        ],
        "responses": {
          "201": {
            "description": "Registrasi berhasil",
            "schema": {
              "$ref": "#/definitions/LoginEnvelope"
            }
          },
          "400": {
            "description": "Input tidak valid, atau username/email sudah dipakai",
            "schema": {
              "$ref": "#/definitions/FailResponse"
            }
          },
          "500": {
            "description": "Kesalahan server",
            "schema": {
              "$ref": "#/definitions/ErrorResponse"
            }
          }
        },
        "parameters": [
          {
            "name": "body",
            "in": "body",
            "required": true,
            "description": "Payload JSON",
            "schema": {
              "$ref": "#/definitions/RegisterRequest"
            }
          }
        ],
        "consumes": [
          "application/json"
        ]
      }
    },
    "/api/auth/login": {
      "post": {
        "tags": [
          "Autentikasi"
        ],
        "summary": "Login",
        "description": "Mengautentikasi username atau email dan menerbitkan JWT. Pesan gagal tidak membedakan 'pengguna tidak ada' dan 'password salah'.",
        "produces": [
          "application/json"
        ],
        "responses": {
          "200": {
            "description": "Login berhasil",
            "schema": {
              "$ref": "#/definitions/LoginEnvelope"
            }
          },
          "400": {
            "description": "Input tidak valid",
            "schema": {
              "$ref": "#/definitions/FailResponse"
            }
          },
          "401": {
            "description": "Kredensial salah",
            "schema": {
              "$ref": "#/definitions/FailResponse"
            }
          },
          "500": {
            "description": "Kesalahan server",
            "schema": {
              "$ref": "#/definitions/ErrorResponse"
            }
          }
        },
        "parameters": [
          {
            "name": "body",
            "in": "body",
            "required": true,
            "description": "Payload JSON",
            "schema": {
              "$ref": "#/definitions/LoginRequest"
            }
          }
        ],
        "consumes": [
          "application/json"
        ]
      }
    },
    "/api/auth/logout": {
      "post": {
        "tags": [
          "Autentikasi"
        ],
        "summary": "Logout",
        "description": "Mengakhiri sesi (JWT stateless: klien menghapus token).",
        "produces": [
          "application/json"
        ],
        "responses": {
          "200": {
            "description": "Logout berhasil",
            "schema": {
              "$ref": "#/definitions/SuccessMessage"
            }
          },
          "401": {
            "description": "Token tidak ada, tidak valid, atau kedaluwarsa",
            "schema": {
              "$ref": "#/definitions/FailResponse"
            }
          }
        },
        "security": [
          {
            "BearerAuth": []
          }
        ]
      }
    },
    "/api/auth/profile": {
      "get": {
        "tags": [
          "Autentikasi"
        ],
        "summary": "Ambil profil",
        "description": "Profil pengguna yang sedang login.",
        "produces": [
          "application/json"
        ],
        "responses": {
          "200": {
            "description": "Profil",
            "schema": {
              "$ref": "#/definitions/UserEnvelope"
            }
          },
          "401": {
            "description": "Token tidak ada, tidak valid, atau kedaluwarsa",
            "schema": {
              "$ref": "#/definitions/FailResponse"
            }
          },
          "500": {
            "description": "Kesalahan server",
            "schema": {
              "$ref": "#/definitions/ErrorResponse"
            }
          }
        },
        "security": [
          {
            "BearerAuth": []
          }
        ]
      },
      "put": {
        "tags": [
          "Autentikasi"
        ],
        "summary": "Perbarui profil",
        "description": "Memperbarui username, email, dan (opsional) password.",
        "produces": [
          "application/json"
        ],
        "responses": {
          "200": {
            "description": "Profil diperbarui",
            "schema": {
              "$ref": "#/definitions/UserEnvelope"
            }
          },
          "400": {
            "description": "Input tidak valid, atau email sudah dipakai",
            "schema": {
              "$ref": "#/definitions/FailResponse"
            }
          },
          "401": {
            "description": "Token tidak ada, tidak valid, atau kedaluwarsa",
            "schema": {
              "$ref": "#/definitions/FailResponse"
            }
          },
          "500": {
            "description": "Kesalahan server",
            "schema": {
              "$ref": "#/definitions/ErrorResponse"
            }
          }
        },
        "parameters": [
          {
            "name": "body",
            "in": "body",
            "required": true,
            "description": "Payload JSON",
            "schema": {
              "$ref": "#/definitions/UpdateProfileRequest"
            }
          }
        ],
        "consumes": [
          "application/json"
        ],
        "security": [
          {
            "BearerAuth": []
          }
        ]
      }
    },
    "/api/posts": {
      "get": {
        "tags": [
          "Penulis"
        ],
        "summary": "Artikel milik saya",
        "description": "Seluruh artikel milik penulis login (terbit dan draf).",
        "produces": [
          "application/json"
        ],
        "responses": {
          "200": {
            "description": "Daftar artikel",
            "schema": {
              "$ref": "#/definitions/PostListEnvelope"
            }
          },
          "401": {
            "description": "Token tidak ada, tidak valid, atau kedaluwarsa",
            "schema": {
              "$ref": "#/definitions/FailResponse"
            }
          },
          "500": {
            "description": "Kesalahan server",
            "schema": {
              "$ref": "#/definitions/ErrorResponse"
            }
          }
        },
        "security": [
          {
            "BearerAuth": []
          }
        ]
      },
      "post": {
        "tags": [
          "Penulis"
        ],
        "summary": "Buat artikel",
        "description": "Membuat artikel; slug unik otomatis, reading_time dihitung dari konten.",
        "produces": [
          "application/json"
        ],
        "responses": {
          "201": {
            "description": "Artikel dibuat",
            "schema": {
              "$ref": "#/definitions/PostEnvelope"
            }
          },
          "400": {
            "description": "Input tidak valid",
            "schema": {
              "$ref": "#/definitions/FailResponse"
            }
          },
          "401": {
            "description": "Token tidak ada, tidak valid, atau kedaluwarsa",
            "schema": {
              "$ref": "#/definitions/FailResponse"
            }
          },
          "500": {
            "description": "Kesalahan server",
            "schema": {
              "$ref": "#/definitions/ErrorResponse"
            }
          }
        },
        "parameters": [
          {
            "name": "body",
            "in": "body",
            "required": true,
            "description": "Payload JSON",
            "schema": {
              "$ref": "#/definitions/PostRequest"
            }
          }
        ],
        "consumes": [
          "application/json"
        ],
        "security": [
          {
            "BearerAuth": []
          }
        ]
      }
    },
    "/api/posts/stats": {
      "get": {
        "tags": [
          "Penulis"
        ],
        "summary": "Statistik penulis",
        "description": "Tiga kartu statistik: total_articles, total_terbit, total_draf; alias total_selesai (= terbit) dan belum_selesai (= draf).",
        "produces": [
          "application/json"
        ],
        "responses": {
          "200": {
            "description": "Statistik",
            "schema": {
              "$ref": "#/definitions/StatsEnvelope"
            }
          },
          "401": {
            "description": "Token tidak ada, tidak valid, atau kedaluwarsa",
            "schema": {
              "$ref": "#/definitions/FailResponse"
            }
          },
          "500": {
            "description": "Kesalahan server",
            "schema": {
              "$ref": "#/definitions/ErrorResponse"
            }
          }
        },
        "security": [
          {
            "BearerAuth": []
          }
        ]
      }
    },
    "/api/posts/ai-generate": {
      "post": {
        "tags": [
          "Penulis"
        ],
        "summary": "AI Blog Generator (+ Search Engine)",
        "description": "Menyusun draf artikel dengan OpenAI. Bila `include_web_search=true`, konteks dari Search Engine disertakan dan sumbernya dikembalikan di `search_sources`. Kegagalan pencarian tidak menggagalkan request. Hasil tidak otomatis disimpan.",
        "produces": [
          "application/json"
        ],
        "responses": {
          "200": {
            "description": "Draf artikel",
            "schema": {
              "$ref": "#/definitions/AIGenerateEnvelope"
            }
          },
          "400": {
            "description": "Input tidak valid",
            "schema": {
              "$ref": "#/definitions/FailResponse"
            }
          },
          "401": {
            "description": "Token tidak ada, tidak valid, atau kedaluwarsa",
            "schema": {
              "$ref": "#/definitions/FailResponse"
            }
          },
          "500": {
            "description": "OpenAI tidak tersedia / gagal, atau kesalahan server",
            "schema": {
              "$ref": "#/definitions/ErrorResponse"
            }
          }
        },
        "parameters": [
          {
            "name": "body",
            "in": "body",
            "required": true,
            "description": "Payload JSON",
            "schema": {
              "$ref": "#/definitions/AIGenerateRequest"
            }
          }
        ],
        "consumes": [
          "application/json"
        ],
        "security": [
          {
            "BearerAuth": []
          }
        ]
      }
    },
    "/api/posts/{id}": {
      "get": {
        "tags": [
          "Penulis"
        ],
        "summary": "Detail artikel saya",
        "description": "Hanya artikel milik sendiri; milik orang lain menghasilkan 404.",
        "produces": [
          "application/json"
        ],
        "responses": {
          "200": {
            "description": "Detail artikel",
            "schema": {
              "$ref": "#/definitions/PostEnvelope"
            }
          },
          "400": {
            "description": "ID tidak valid",
            "schema": {
              "$ref": "#/definitions/FailResponse"
            }
          },
          "401": {
            "description": "Token tidak ada, tidak valid, atau kedaluwarsa",
            "schema": {
              "$ref": "#/definitions/FailResponse"
            }
          },
          "403": {
            "description": "Artikel milik pengguna lain",
            "schema": {
              "$ref": "#/definitions/FailResponse"
            }
          },
          "404": {
            "description": "Artikel tidak ditemukan",
            "schema": {
              "$ref": "#/definitions/FailResponse"
            }
          },
          "500": {
            "description": "Kesalahan server",
            "schema": {
              "$ref": "#/definitions/ErrorResponse"
            }
          }
        },
        "parameters": [
          {
            "name": "id",
            "in": "path",
            "required": true,
            "type": "integer",
            "description": "ID artikel"
          }
        ],
        "security": [
          {
            "BearerAuth": []
          }
        ]
      },
      "put": {
        "tags": [
          "Penulis"
        ],
        "summary": "Perbarui artikel",
        "description": "Memperbarui title, category, excerpt, content, cover_image_path (dan opsional is_published). Slug dibuat ulang bila judul berubah.",
        "produces": [
          "application/json"
        ],
        "responses": {
          "200": {
            "description": "Artikel diperbarui",
            "schema": {
              "$ref": "#/definitions/PostEnvelope"
            }
          },
          "400": {
            "description": "Input tidak valid",
            "schema": {
              "$ref": "#/definitions/FailResponse"
            }
          },
          "401": {
            "description": "Token tidak ada, tidak valid, atau kedaluwarsa",
            "schema": {
              "$ref": "#/definitions/FailResponse"
            }
          },
          "403": {
            "description": "Artikel milik pengguna lain",
            "schema": {
              "$ref": "#/definitions/FailResponse"
            }
          },
          "404": {
            "description": "Artikel tidak ditemukan",
            "schema": {
              "$ref": "#/definitions/FailResponse"
            }
          },
          "500": {
            "description": "Kesalahan server",
            "schema": {
              "$ref": "#/definitions/ErrorResponse"
            }
          }
        },
        "parameters": [
          {
            "name": "id",
            "in": "path",
            "required": true,
            "type": "integer",
            "description": "ID artikel"
          },
          {
            "name": "body",
            "in": "body",
            "required": true,
            "description": "Payload JSON",
            "schema": {
              "$ref": "#/definitions/PostRequest"
            }
          }
        ],
        "consumes": [
          "application/json"
        ],
        "security": [
          {
            "BearerAuth": []
          }
        ]
      },
      "delete": {
        "tags": [
          "Penulis"
        ],
        "summary": "Hapus artikel",
        "description": "Menghapus artikel milik sendiri.",
        "produces": [
          "application/json"
        ],
        "responses": {
          "200": {
            "description": "Artikel dihapus",
            "schema": {
              "$ref": "#/definitions/SuccessMessage"
            }
          },
          "400": {
            "description": "ID tidak valid",
            "schema": {
              "$ref": "#/definitions/FailResponse"
            }
          },
          "401": {
            "description": "Token tidak ada, tidak valid, atau kedaluwarsa",
            "schema": {
              "$ref": "#/definitions/FailResponse"
            }
          },
          "403": {
            "description": "Artikel milik pengguna lain",
            "schema": {
              "$ref": "#/definitions/FailResponse"
            }
          },
          "404": {
            "description": "Artikel tidak ditemukan",
            "schema": {
              "$ref": "#/definitions/FailResponse"
            }
          },
          "500": {
            "description": "Kesalahan server",
            "schema": {
              "$ref": "#/definitions/ErrorResponse"
            }
          }
        },
        "parameters": [
          {
            "name": "id",
            "in": "path",
            "required": true,
            "type": "integer",
            "description": "ID artikel"
          }
        ],
        "security": [
          {
            "BearerAuth": []
          }
        ]
      }
    },
    "/api/posts/{id}/toggle-publish": {
      "patch": {
        "tags": [
          "Penulis"
        ],
        "summary": "Toggle terbit/draf",
        "description": "Draf → Terbit mengisi published_at; Terbit → Draf mengosongkannya.",
        "produces": [
          "application/json"
        ],
        "responses": {
          "200": {
            "description": "Status diubah",
            "schema": {
              "$ref": "#/definitions/PostEnvelope"
            }
          },
          "400": {
            "description": "ID tidak valid",
            "schema": {
              "$ref": "#/definitions/FailResponse"
            }
          },
          "401": {
            "description": "Token tidak ada, tidak valid, atau kedaluwarsa",
            "schema": {
              "$ref": "#/definitions/FailResponse"
            }
          },
          "403": {
            "description": "Artikel milik pengguna lain",
            "schema": {
              "$ref": "#/definitions/FailResponse"
            }
          },
          "404": {
            "description": "Artikel tidak ditemukan",
            "schema": {
              "$ref": "#/definitions/FailResponse"
            }
          },
          "500": {
            "description": "Kesalahan server",
            "schema": {
              "$ref": "#/definitions/ErrorResponse"
            }
          }
        },
        "parameters": [
          {
            "name": "id",
            "in": "path",
            "required": true,
            "type": "integer",
            "description": "ID artikel"
          }
        ],
        "security": [
          {
            "BearerAuth": []
          }
        ]
      }
    },
    "/api/admin/users": {
      "get": {
        "tags": [
          "Admin"
        ],
        "summary": "Direktori pengguna",
        "description": "Seluruh pengguna beserta total_articles dan total_published. Hanya admin.",
        "produces": [
          "application/json"
        ],
        "responses": {
          "200": {
            "description": "Daftar pengguna",
            "schema": {
              "$ref": "#/definitions/AdminUsersEnvelope"
            }
          },
          "401": {
            "description": "Token tidak ada, tidak valid, atau kedaluwarsa",
            "schema": {
              "$ref": "#/definitions/FailResponse"
            }
          },
          "403": {
            "description": "Bukan admin",
            "schema": {
              "$ref": "#/definitions/FailResponse"
            }
          },
          "500": {
            "description": "Kesalahan server",
            "schema": {
              "$ref": "#/definitions/ErrorResponse"
            }
          }
        },
        "security": [
          {
            "BearerAuth": []
          }
        ]
      }
    },
    "/api/admin/posts": {
      "get": {
        "tags": [
          "Admin"
        ],
        "summary": "Arsip seluruh artikel",
        "description": "Artikel semua penulis (termasuk draf) beserta data penulis. Hanya admin.",
        "produces": [
          "application/json"
        ],
        "responses": {
          "200": {
            "description": "Daftar artikel",
            "schema": {
              "$ref": "#/definitions/PostListEnvelope"
            }
          },
          "401": {
            "description": "Token tidak ada, tidak valid, atau kedaluwarsa",
            "schema": {
              "$ref": "#/definitions/FailResponse"
            }
          },
          "403": {
            "description": "Bukan admin",
            "schema": {
              "$ref": "#/definitions/FailResponse"
            }
          },
          "500": {
            "description": "Kesalahan server",
            "schema": {
              "$ref": "#/definitions/ErrorResponse"
            }
          }
        },
        "security": [
          {
            "BearerAuth": []
          }
        ]
      }
    },
    "/api/admin/users/{id}/posts": {
      "get": {
        "tags": [
          "Admin"
        ],
        "summary": "Artikel per pengguna",
        "description": "Seluruh artikel milik pengguna tertentu. 404 bila pengguna tidak ada. Hanya admin.",
        "produces": [
          "application/json"
        ],
        "responses": {
          "200": {
            "description": "Daftar artikel",
            "schema": {
              "$ref": "#/definitions/PostListEnvelope"
            }
          },
          "400": {
            "description": "ID tidak valid",
            "schema": {
              "$ref": "#/definitions/FailResponse"
            }
          },
          "401": {
            "description": "Token tidak ada, tidak valid, atau kedaluwarsa",
            "schema": {
              "$ref": "#/definitions/FailResponse"
            }
          },
          "403": {
            "description": "Bukan admin",
            "schema": {
              "$ref": "#/definitions/FailResponse"
            }
          },
          "500": {
            "description": "Kesalahan server",
            "schema": {
              "$ref": "#/definitions/ErrorResponse"
            }
          }
        },
        "parameters": [
          {
            "name": "id",
            "in": "path",
            "required": true,
            "type": "integer",
            "description": "ID pengguna"
          }
        ],
        "security": [
          {
            "BearerAuth": []
          }
        ]
      }
    }
  },
  "definitions": {
    "FailResponse": {
      "type": "object",
      "properties": {
        "status": {
          "type": "string",
          "example": "fail",
          "enum": [
            "fail"
          ]
        },
        "message": {
          "type": "string",
          "example": "Pesan kesalahan klien (4xx)"
        }
      },
      "description": "Respons kegagalan klien (HTTP 4xx)."
    },
    "ErrorResponse": {
      "type": "object",
      "properties": {
        "status": {
          "type": "string",
          "example": "error",
          "enum": [
            "error"
          ]
        },
        "message": {
          "type": "string",
          "example": "Terjadi kesalahan pada server"
        }
      },
      "description": "Respons kesalahan server (HTTP 5xx)."
    },
    "SuccessMessage": {
      "type": "object",
      "properties": {
        "status": {
          "type": "string",
          "example": "success",
          "enum": [
            "success"
          ]
        },
        "message": {
          "type": "string",
          "example": "Operasi berhasil"
        }
      },
      "description": "Respons sukses tanpa data."
    },
    "User": {
      "type": "object",
      "properties": {
        "id": {
          "type": "integer",
          "example": 2
        },
        "username": {
          "type": "string",
          "example": "member"
        },
        "email": {
          "type": "string",
          "example": "member@delcom.org"
        },
        "role": {
          "type": "string",
          "example": "member",
          "enum": [
            "member",
            "admin"
          ]
        },
        "created_at": {
          "type": "string",
          "example": "2026-11-19T08:00:00Z",
          "format": "date-time"
        }
      }
    },
    "LoginData": {
      "type": "object",
      "properties": {
        "token": {
          "type": "string",
          "description": "JWT Bearer (berlaku 24 jam; berisi user_id, username, role)",
          "example": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..."
        },
        "user": {
          "$ref": "#/definitions/User"
        }
      }
    },
    "Author": {
      "type": "object",
      "properties": {
        "id": {
          "type": "integer",
          "example": 1
        },
        "username": {
          "type": "string",
          "example": "admin"
        }
      }
    },
    "Post": {
      "type": "object",
      "properties": {
        "id": {
          "type": "integer",
          "example": 12
        },
        "user_id": {
          "type": "integer",
          "example": 2
        },
        "title": {
          "type": "string",
          "example": "Mengenal Clean Architecture pada Aplikasi Go"
        },
        "slug": {
          "type": "string",
          "description": "Slug unik; tabrakan diberi sufiks -2, -3, dst.",
          "example": "mengenal-clean-architecture-pada-aplikasi-go"
        },
        "category": {
          "type": "string",
          "example": "Teknologi",
          "enum": [
            "Teknologi",
            "Pendidikan",
            "Gaya Hidup",
            "Bisnis",
            "Opini",
            "Umum"
          ]
        },
        "excerpt": {
          "type": "string",
          "example": "Memisahkan handler, service, dan repository."
        },
        "content": {
          "type": "string",
          "description": "Isi artikel dalam Markdown",
          "example": "# Judul\n\nIsi artikel..."
        },
        "cover_image_path": {
          "type": "string",
          "description": "URL/teks lokasi gambar sampul (tidak ada endpoint upload)",
          "example": "https://contoh.id/cover.jpg"
        },
        "is_published": {
          "type": "boolean",
          "example": true
        },
        "published_at": {
          "type": "string",
          "description": "null bila draf",
          "example": "2026-11-19T08:00:00Z",
          "format": "date-time"
        },
        "reading_time": {
          "type": "integer",
          "description": "Estimasi menit baca = ceil(jumlah kata / 200), minimal 1",
          "example": 3
        },
        "author": {
          "$ref": "#/definitions/Author"
        },
        "created_at": {
          "type": "string",
          "example": "2026-11-19T08:00:00Z",
          "format": "date-time"
        },
        "updated_at": {
          "type": "string",
          "example": "2026-11-19T08:00:00Z",
          "format": "date-time"
        }
      }
    },
    "PostRequest": {
      "type": "object",
      "properties": {
        "title": {
          "type": "string",
          "description": "Wajib, maksimal 255 karakter",
          "example": "Belajar Go untuk Pemula"
        },
        "category": {
          "type": "string",
          "description": "Salah satu dari 6 kategori; kosong = Umum; di luar daftar = 400",
          "example": "Teknologi",
          "enum": [
            "Teknologi",
            "Pendidikan",
            "Gaya Hidup",
            "Bisnis",
            "Opini",
            "Umum"
          ]
        },
        "excerpt": {
          "type": "string",
          "description": "Ringkasan 1-2 kalimat",
          "example": "Panduan singkat memulai Go."
        },
        "content": {
          "type": "string",
          "description": "Wajib, Markdown",
          "example": "# Halo\n\nIsi artikel."
        },
        "cover_image_path": {
          "type": "string",
          "example": "https://contoh.id/cover.jpg"
        },
        "is_published": {
          "type": "boolean",
          "description": "Opsional; menjaga konsistensi published_at",
          "example": false
        }
      },
      "required": [
        "title",
        "content"
      ]
    },
    "Stats": {
      "type": "object",
      "properties": {
        "total_articles": {
          "type": "integer",
          "description": "Total artikel",
          "example": 5
        },
        "total_terbit": {
          "type": "integer",
          "example": 3
        },
        "total_draf": {
          "type": "integer",
          "example": 2
        },
        "total_selesai": {
          "type": "integer",
          "description": "Alias total_terbit (istilah skrip)",
          "example": 3
        },
        "belum_selesai": {
          "type": "integer",
          "description": "Alias total_draf (istilah skrip)",
          "example": 2
        }
      }
    },
    "AdminUser": {
      "type": "object",
      "properties": {
        "id": {
          "type": "integer",
          "example": 2
        },
        "username": {
          "type": "string",
          "example": "member"
        },
        "email": {
          "type": "string",
          "example": "member@delcom.org"
        },
        "role": {
          "type": "string",
          "example": "member"
        },
        "total_articles": {
          "type": "integer",
          "example": 4
        },
        "total_published": {
          "type": "integer",
          "example": 2
        },
        "created_at": {
          "type": "string",
          "example": "2026-11-19T08:00:00Z",
          "format": "date-time"
        }
      }
    },
    "RegisterRequest": {
      "type": "object",
      "properties": {
        "username": {
          "type": "string",
          "description": "3-50 karakter: huruf, angka, titik, garis bawah, strip",
          "example": "budi"
        },
        "email": {
          "type": "string",
          "example": "budi@contoh.id"
        },
        "password": {
          "type": "string",
          "description": "Minimal 6 karakter (maks 72 byte)",
          "example": "rahasia123"
        },
        "role": {
          "type": "string",
          "description": "Opsional: 'admin' atau 'member'; selain itu dipaksa 'member'",
          "enum": [
            "admin",
            "member"
          ],
          "example": "member"
        }
      },
      "required": [
        "username",
        "email",
        "password"
      ],
      "description": "Field role opsional; hanya 'admin' atau 'member' yang diterima."
    },
    "LoginRequest": {
      "type": "object",
      "properties": {
        "username": {
          "type": "string",
          "description": "Username ATAU email",
          "example": "member"
        },
        "password": {
          "type": "string",
          "example": "member"
        }
      },
      "required": [
        "username",
        "password"
      ]
    },
    "UpdateProfileRequest": {
      "type": "object",
      "properties": {
        "email": {
          "type": "string",
          "example": "budi@contoh.id"
        },
        "password": {
          "type": "string",
          "description": "Opsional; kosongkan bila tidak diganti",
          "example": ""
        }
      },
      "required": [
        "email"
      ],
      "description": "Hanya email dan password yang dapat diubah; username tidak berubah."
    },
    "AIGenerateRequest": {
      "type": "object",
      "properties": {
        "topic": {
          "type": "string",
          "description": "Wajib, maksimal 300 karakter",
          "example": "Dampak AI terhadap pendidikan tinggi di Indonesia"
        },
        "category": {
          "type": "string",
          "description": "Opsional; petunjuk kategori",
          "example": "Pendidikan",
          "enum": [
            "Teknologi",
            "Pendidikan",
            "Gaya Hidup",
            "Bisnis",
            "Opini",
            "Umum"
          ]
        },
        "include_web_search": {
          "type": "boolean",
          "description": "true = konteks penelusuran Search Engine disertakan",
          "example": true
        }
      },
      "required": [
        "topic"
      ]
    },
    "SearchSource": {
      "type": "object",
      "properties": {
        "title": {
          "type": "string",
          "example": "Judul sumber"
        },
        "url": {
          "type": "string",
          "example": "https://contoh.id/sumber"
        },
        "snippet": {
          "type": "string",
          "example": "Cuplikan teks sumber"
        }
      }
    },
    "AIGenerateData": {
      "type": "object",
      "properties": {
        "title": {
          "type": "string",
          "example": "Judul dari AI"
        },
        "category": {
          "type": "string",
          "example": "Pendidikan",
          "enum": [
            "Teknologi",
            "Pendidikan",
            "Gaya Hidup",
            "Bisnis",
            "Opini",
            "Umum"
          ]
        },
        "excerpt": {
          "type": "string",
          "example": "Ringkasan."
        },
        "content": {
          "type": "string",
          "description": "Markdown berbahasa Indonesia (disertai '## Referensi' bila ada konteks web)",
          "example": "## Pendahuluan\n..."
        },
        "search_sources": {
          "type": "array",
          "items": {
            "$ref": "#/definitions/SearchSource"
          }
        }
      },
      "description": "Hasil TIDAK otomatis disimpan; klien menampilkan pratinjau lalu menerapkannya ke editor."
    },
    "UserEnvelope": {
      "type": "object",
      "properties": {
        "status": {
          "type": "string",
          "example": "success",
          "enum": [
            "success"
          ]
        },
        "message": {
          "type": "string",
          "example": "Profil berhasil diambil"
        },
        "data": {
          "$ref": "#/definitions/User"
        }
      }
    },
    "LoginEnvelope": {
      "type": "object",
      "properties": {
        "status": {
          "type": "string",
          "example": "success",
          "enum": [
            "success"
          ]
        },
        "message": {
          "type": "string",
          "example": "Login berhasil"
        },
        "data": {
          "$ref": "#/definitions/LoginData"
        }
      }
    },
    "CategoriesEnvelope": {
      "type": "object",
      "properties": {
        "status": {
          "type": "string",
          "example": "success",
          "enum": [
            "success"
          ]
        },
        "message": {
          "type": "string",
          "example": "Kategori berhasil diambil"
        },
        "data": {
          "type": "array",
          "items": {
            "type": "string",
            "example": "Teknologi",
            "enum": [
              "Teknologi",
              "Pendidikan",
              "Gaya Hidup",
              "Bisnis",
              "Opini",
              "Umum"
            ]
          }
        }
      }
    },
    "PostEnvelope": {
      "type": "object",
      "properties": {
        "status": {
          "type": "string",
          "example": "success",
          "enum": [
            "success"
          ]
        },
        "message": {
          "type": "string",
          "example": "Artikel berhasil diambil"
        },
        "data": {
          "$ref": "#/definitions/Post"
        }
      }
    },
    "PostListEnvelope": {
      "type": "object",
      "properties": {
        "status": {
          "type": "string",
          "example": "success",
          "enum": [
            "success"
          ]
        },
        "message": {
          "type": "string",
          "example": "Artikel berhasil diambil"
        },
        "data": {
          "type": "array",
          "items": {
            "$ref": "#/definitions/Post"
          }
        }
      }
    },
    "StatsEnvelope": {
      "type": "object",
      "properties": {
        "status": {
          "type": "string",
          "example": "success",
          "enum": [
            "success"
          ]
        },
        "message": {
          "type": "string",
          "example": "Statistik berhasil diambil"
        },
        "data": {
          "$ref": "#/definitions/Stats"
        }
      }
    },
    "AdminUsersEnvelope": {
      "type": "object",
      "properties": {
        "status": {
          "type": "string",
          "example": "success",
          "enum": [
            "success"
          ]
        },
        "message": {
          "type": "string",
          "example": "Pengguna berhasil diambil"
        },
        "data": {
          "type": "array",
          "items": {
            "$ref": "#/definitions/AdminUser"
          }
        }
      }
    },
    "AIGenerateEnvelope": {
      "type": "object",
      "properties": {
        "status": {
          "type": "string",
          "example": "success",
          "enum": [
            "success"
          ]
        },
        "message": {
          "type": "string",
          "example": "Draf artikel berhasil dibuat"
        },
        "data": {
          "$ref": "#/definitions/AIGenerateData"
        }
      }
    },
    "PublicPost": {
      "type": "object",
      "properties": {
        "id": {
          "type": "integer",
          "example": 12
        },
        "title": {
          "type": "string",
          "example": "Mengenal Clean Architecture pada Aplikasi Go"
        },
        "slug": {
          "type": "string",
          "description": "Slug unik; tabrakan diberi sufiks -2, -3, dst.",
          "example": "mengenal-clean-architecture-pada-aplikasi-go"
        },
        "category": {
          "type": "string",
          "example": "Teknologi",
          "enum": [
            "Teknologi",
            "Pendidikan",
            "Gaya Hidup",
            "Bisnis",
            "Opini",
            "Umum"
          ]
        },
        "excerpt": {
          "type": "string",
          "example": "Memisahkan handler, service, dan repository."
        },
        "content": {
          "type": "string",
          "description": "Isi artikel dalam Markdown",
          "example": "# Judul\n\nIsi artikel..."
        },
        "cover_image_path": {
          "type": "string",
          "description": "URL/teks lokasi gambar sampul (tidak ada endpoint upload)",
          "example": "https://contoh.id/cover.jpg"
        },
        "is_published": {
          "type": "boolean",
          "example": true
        },
        "published_at": {
          "type": "string",
          "description": "null bila draf",
          "example": "2026-11-19T08:00:00Z",
          "format": "date-time"
        },
        "reading_time": {
          "type": "integer",
          "description": "Estimasi menit baca = ceil(jumlah kata / 200), minimal 1",
          "example": 3
        },
        "created_at": {
          "type": "string",
          "example": "2026-11-19T08:00:00Z",
          "format": "date-time"
        },
        "updated_at": {
          "type": "string",
          "example": "2026-11-19T08:00:00Z",
          "format": "date-time"
        },
        "author_name": {
          "type": "string",
          "description": "Nama penulis",
          "example": "member"
        }
      }
    },
    "PublicPostEnvelope": {
      "type": "object",
      "properties": {
        "status": {
          "type": "string",
          "example": "success",
          "enum": [
            "success"
          ]
        },
        "message": {
          "type": "string",
          "example": "Artikel berhasil diambil"
        },
        "data": {
          "$ref": "#/definitions/PublicPost"
        }
      }
    },
    "PublicPostListEnvelope": {
      "type": "object",
      "properties": {
        "status": {
          "type": "string",
          "example": "success",
          "enum": [
            "success"
          ]
        },
        "message": {
          "type": "string",
          "example": "Artikel berhasil diambil"
        },
        "data": {
          "type": "array",
          "items": {
            "$ref": "#/definitions/PublicPost"
          }
        }
      }
    }
  }
}
'@

Write-Repo 'docs/swagger.json' @'
{
  "swagger": "2.0",
  "info": {
    "title": "Delcom Blog REST API",
    "description": "Dokumentasi RESTful API Delcom Blog (Golang Gin, Clean Architecture & Feature-First) dengan AI Blog Generator terintegrasi Search Engine. Seluruh respons berformat {status, message, data?}.",
    "version": "1.0.0",
    "contact": {
      "name": "Delcom - Labs"
    }
  },
  "host": "localhost:8081",
  "basePath": "/",
  "schemes": [
    "http"
  ],
  "consumes": [
    "application/json"
  ],
  "produces": [
    "application/json"
  ],
  "tags": [
    {
      "name": "Dokumentasi"
    },
    {
      "name": "Publik"
    },
    {
      "name": "Autentikasi"
    },
    {
      "name": "Penulis"
    },
    {
      "name": "Admin"
    }
  ],
  "securityDefinitions": {
    "BearerAuth": {
      "type": "apiKey",
      "name": "Authorization",
      "in": "header",
      "description": "Masukkan: Bearer <token JWT>"
    }
  },
  "paths": {
    "/swagger/{any}": {
      "get": {
        "tags": [
          "Dokumentasi"
        ],
        "summary": "Swagger UI",
        "description": "Dokumentasi interaktif Swagger UI (http://localhost:8081/swagger/index.html). `/swagger` dialihkan ke `/swagger/index.html`.",
        "produces": [
          "application/json"
        ],
        "responses": {
          "200": {
            "description": "Halaman Swagger UI"
          }
        },
        "parameters": [
          {
            "name": "any",
            "in": "path",
            "required": true,
            "type": "string",
            "description": "Berkas Swagger UI, mis. index.html"
          }
        ]
      }
    },
    "/api.json": {
      "get": {
        "tags": [
          "Dokumentasi"
        ],
        "summary": "Spesifikasi OpenAPI dinamis",
        "description": "Spesifikasi OpenAPI/Swagger JSON; host dan scheme menyesuaikan request (menghormati X-Forwarded-Host dan X-Forwarded-Proto).",
        "produces": [
          "application/json"
        ],
        "responses": {
          "200": {
            "description": "Dokumen OpenAPI 2.0"
          }
        }
      }
    },
    "/api/public/categories": {
      "get": {
        "tags": [
          "Publik"
        ],
        "summary": "Daftar kategori",
        "description": "Enam kategori artikel: Teknologi, Pendidikan, Gaya Hidup, Bisnis, Opini, Umum.",
        "produces": [
          "application/json"
        ],
        "responses": {
          "200": {
            "description": "Daftar kategori",
            "schema": {
              "$ref": "#/definitions/CategoriesEnvelope"
            }
          }
        }
      }
    },
    "/api/public/posts": {
      "get": {
        "tags": [
          "Publik"
        ],
        "summary": "Daftar artikel terbit",
        "description": "Hanya artikel `is_published=true`, terbaru lebih dulu. Pencarian `q` tidak membedakan huruf besar/kecil pada judul, ringkasan, dan konten.",
        "produces": [
          "application/json"
        ],
        "responses": {
          "200": {
            "description": "Daftar artikel terbit",
            "schema": {
              "$ref": "#/definitions/PublicPostListEnvelope"
            }
          },
          "500": {
            "description": "Kesalahan server",
            "schema": {
              "$ref": "#/definitions/ErrorResponse"
            }
          }
        },
        "parameters": [
          {
            "name": "q",
            "in": "query",
            "type": "string",
            "description": "Kata kunci pencarian"
          },
          {
            "name": "category",
            "in": "query",
            "type": "string",
            "enum": [
              "Teknologi",
              "Pendidikan",
              "Gaya Hidup",
              "Bisnis",
              "Opini",
              "Umum"
            ],
            "description": "Filter kategori (kosong/Semua = semua kategori)"
          }
        ]
      }
    },
    "/api/public/posts/{slug}": {
      "get": {
        "tags": [
          "Publik"
        ],
        "summary": "Detail artikel publik",
        "description": "Artikel terbit berdasarkan slug, lengkap dengan penulis dan reading_time. Draf menghasilkan 404.",
        "produces": [
          "application/json"
        ],
        "responses": {
          "200": {
            "description": "Detail artikel",
            "schema": {
              "$ref": "#/definitions/PublicPostEnvelope"
            }
          },
          "404": {
            "description": "Artikel tidak ditemukan",
            "schema": {
              "$ref": "#/definitions/FailResponse"
            }
          },
          "500": {
            "description": "Kesalahan server",
            "schema": {
              "$ref": "#/definitions/ErrorResponse"
            }
          }
        },
        "parameters": [
          {
            "name": "slug",
            "in": "path",
            "required": true,
            "type": "string",
            "description": "Slug artikel"
          }
        ]
      }
    },
    "/api/auth/register": {
      "post": {
        "tags": [
          "Autentikasi"
        ],
        "summary": "Registrasi akun",
        "description": "Membuat akun penulis dan langsung mengembalikan token JWT. Field `role` opsional: hanya `admin` atau `member` yang diterima, nilai lain dipaksa `member`.",
        "produces": [
          "application/json"
        ],
        "responses": {
          "201": {
            "description": "Registrasi berhasil",
            "schema": {
              "$ref": "#/definitions/LoginEnvelope"
            }
          },
          "400": {
            "description": "Input tidak valid, atau username/email sudah dipakai",
            "schema": {
              "$ref": "#/definitions/FailResponse"
            }
          },
          "500": {
            "description": "Kesalahan server",
            "schema": {
              "$ref": "#/definitions/ErrorResponse"
            }
          }
        },
        "parameters": [
          {
            "name": "body",
            "in": "body",
            "required": true,
            "description": "Payload JSON",
            "schema": {
              "$ref": "#/definitions/RegisterRequest"
            }
          }
        ],
        "consumes": [
          "application/json"
        ]
      }
    },
    "/api/auth/login": {
      "post": {
        "tags": [
          "Autentikasi"
        ],
        "summary": "Login",
        "description": "Mengautentikasi username atau email dan menerbitkan JWT. Pesan gagal tidak membedakan 'pengguna tidak ada' dan 'password salah'.",
        "produces": [
          "application/json"
        ],
        "responses": {
          "200": {
            "description": "Login berhasil",
            "schema": {
              "$ref": "#/definitions/LoginEnvelope"
            }
          },
          "400": {
            "description": "Input tidak valid",
            "schema": {
              "$ref": "#/definitions/FailResponse"
            }
          },
          "401": {
            "description": "Kredensial salah",
            "schema": {
              "$ref": "#/definitions/FailResponse"
            }
          },
          "500": {
            "description": "Kesalahan server",
            "schema": {
              "$ref": "#/definitions/ErrorResponse"
            }
          }
        },
        "parameters": [
          {
            "name": "body",
            "in": "body",
            "required": true,
            "description": "Payload JSON",
            "schema": {
              "$ref": "#/definitions/LoginRequest"
            }
          }
        ],
        "consumes": [
          "application/json"
        ]
      }
    },
    "/api/auth/logout": {
      "post": {
        "tags": [
          "Autentikasi"
        ],
        "summary": "Logout",
        "description": "Mengakhiri sesi (JWT stateless: klien menghapus token).",
        "produces": [
          "application/json"
        ],
        "responses": {
          "200": {
            "description": "Logout berhasil",
            "schema": {
              "$ref": "#/definitions/SuccessMessage"
            }
          },
          "401": {
            "description": "Token tidak ada, tidak valid, atau kedaluwarsa",
            "schema": {
              "$ref": "#/definitions/FailResponse"
            }
          }
        },
        "security": [
          {
            "BearerAuth": []
          }
        ]
      }
    },
    "/api/auth/profile": {
      "get": {
        "tags": [
          "Autentikasi"
        ],
        "summary": "Ambil profil",
        "description": "Profil pengguna yang sedang login.",
        "produces": [
          "application/json"
        ],
        "responses": {
          "200": {
            "description": "Profil",
            "schema": {
              "$ref": "#/definitions/UserEnvelope"
            }
          },
          "401": {
            "description": "Token tidak ada, tidak valid, atau kedaluwarsa",
            "schema": {
              "$ref": "#/definitions/FailResponse"
            }
          },
          "500": {
            "description": "Kesalahan server",
            "schema": {
              "$ref": "#/definitions/ErrorResponse"
            }
          }
        },
        "security": [
          {
            "BearerAuth": []
          }
        ]
      },
      "put": {
        "tags": [
          "Autentikasi"
        ],
        "summary": "Perbarui profil",
        "description": "Memperbarui username, email, dan (opsional) password.",
        "produces": [
          "application/json"
        ],
        "responses": {
          "200": {
            "description": "Profil diperbarui",
            "schema": {
              "$ref": "#/definitions/UserEnvelope"
            }
          },
          "400": {
            "description": "Input tidak valid, atau email sudah dipakai",
            "schema": {
              "$ref": "#/definitions/FailResponse"
            }
          },
          "401": {
            "description": "Token tidak ada, tidak valid, atau kedaluwarsa",
            "schema": {
              "$ref": "#/definitions/FailResponse"
            }
          },
          "500": {
            "description": "Kesalahan server",
            "schema": {
              "$ref": "#/definitions/ErrorResponse"
            }
          }
        },
        "parameters": [
          {
            "name": "body",
            "in": "body",
            "required": true,
            "description": "Payload JSON",
            "schema": {
              "$ref": "#/definitions/UpdateProfileRequest"
            }
          }
        ],
        "consumes": [
          "application/json"
        ],
        "security": [
          {
            "BearerAuth": []
          }
        ]
      }
    },
    "/api/posts": {
      "get": {
        "tags": [
          "Penulis"
        ],
        "summary": "Artikel milik saya",
        "description": "Seluruh artikel milik penulis login (terbit dan draf).",
        "produces": [
          "application/json"
        ],
        "responses": {
          "200": {
            "description": "Daftar artikel",
            "schema": {
              "$ref": "#/definitions/PostListEnvelope"
            }
          },
          "401": {
            "description": "Token tidak ada, tidak valid, atau kedaluwarsa",
            "schema": {
              "$ref": "#/definitions/FailResponse"
            }
          },
          "500": {
            "description": "Kesalahan server",
            "schema": {
              "$ref": "#/definitions/ErrorResponse"
            }
          }
        },
        "security": [
          {
            "BearerAuth": []
          }
        ]
      },
      "post": {
        "tags": [
          "Penulis"
        ],
        "summary": "Buat artikel",
        "description": "Membuat artikel; slug unik otomatis, reading_time dihitung dari konten.",
        "produces": [
          "application/json"
        ],
        "responses": {
          "201": {
            "description": "Artikel dibuat",
            "schema": {
              "$ref": "#/definitions/PostEnvelope"
            }
          },
          "400": {
            "description": "Input tidak valid",
            "schema": {
              "$ref": "#/definitions/FailResponse"
            }
          },
          "401": {
            "description": "Token tidak ada, tidak valid, atau kedaluwarsa",
            "schema": {
              "$ref": "#/definitions/FailResponse"
            }
          },
          "500": {
            "description": "Kesalahan server",
            "schema": {
              "$ref": "#/definitions/ErrorResponse"
            }
          }
        },
        "parameters": [
          {
            "name": "body",
            "in": "body",
            "required": true,
            "description": "Payload JSON",
            "schema": {
              "$ref": "#/definitions/PostRequest"
            }
          }
        ],
        "consumes": [
          "application/json"
        ],
        "security": [
          {
            "BearerAuth": []
          }
        ]
      }
    },
    "/api/posts/stats": {
      "get": {
        "tags": [
          "Penulis"
        ],
        "summary": "Statistik penulis",
        "description": "Tiga kartu statistik: total_articles, total_terbit, total_draf; alias total_selesai (= terbit) dan belum_selesai (= draf).",
        "produces": [
          "application/json"
        ],
        "responses": {
          "200": {
            "description": "Statistik",
            "schema": {
              "$ref": "#/definitions/StatsEnvelope"
            }
          },
          "401": {
            "description": "Token tidak ada, tidak valid, atau kedaluwarsa",
            "schema": {
              "$ref": "#/definitions/FailResponse"
            }
          },
          "500": {
            "description": "Kesalahan server",
            "schema": {
              "$ref": "#/definitions/ErrorResponse"
            }
          }
        },
        "security": [
          {
            "BearerAuth": []
          }
        ]
      }
    },
    "/api/posts/ai-generate": {
      "post": {
        "tags": [
          "Penulis"
        ],
        "summary": "AI Blog Generator (+ Search Engine)",
        "description": "Menyusun draf artikel dengan OpenAI. Bila `include_web_search=true`, konteks dari Search Engine disertakan dan sumbernya dikembalikan di `search_sources`. Kegagalan pencarian tidak menggagalkan request. Hasil tidak otomatis disimpan.",
        "produces": [
          "application/json"
        ],
        "responses": {
          "200": {
            "description": "Draf artikel",
            "schema": {
              "$ref": "#/definitions/AIGenerateEnvelope"
            }
          },
          "400": {
            "description": "Input tidak valid",
            "schema": {
              "$ref": "#/definitions/FailResponse"
            }
          },
          "401": {
            "description": "Token tidak ada, tidak valid, atau kedaluwarsa",
            "schema": {
              "$ref": "#/definitions/FailResponse"
            }
          },
          "500": {
            "description": "OpenAI tidak tersedia / gagal, atau kesalahan server",
            "schema": {
              "$ref": "#/definitions/ErrorResponse"
            }
          }
        },
        "parameters": [
          {
            "name": "body",
            "in": "body",
            "required": true,
            "description": "Payload JSON",
            "schema": {
              "$ref": "#/definitions/AIGenerateRequest"
            }
          }
        ],
        "consumes": [
          "application/json"
        ],
        "security": [
          {
            "BearerAuth": []
          }
        ]
      }
    },
    "/api/posts/{id}": {
      "get": {
        "tags": [
          "Penulis"
        ],
        "summary": "Detail artikel saya",
        "description": "Hanya artikel milik sendiri; milik orang lain menghasilkan 404.",
        "produces": [
          "application/json"
        ],
        "responses": {
          "200": {
            "description": "Detail artikel",
            "schema": {
              "$ref": "#/definitions/PostEnvelope"
            }
          },
          "400": {
            "description": "ID tidak valid",
            "schema": {
              "$ref": "#/definitions/FailResponse"
            }
          },
          "401": {
            "description": "Token tidak ada, tidak valid, atau kedaluwarsa",
            "schema": {
              "$ref": "#/definitions/FailResponse"
            }
          },
          "403": {
            "description": "Artikel milik pengguna lain",
            "schema": {
              "$ref": "#/definitions/FailResponse"
            }
          },
          "404": {
            "description": "Artikel tidak ditemukan",
            "schema": {
              "$ref": "#/definitions/FailResponse"
            }
          },
          "500": {
            "description": "Kesalahan server",
            "schema": {
              "$ref": "#/definitions/ErrorResponse"
            }
          }
        },
        "parameters": [
          {
            "name": "id",
            "in": "path",
            "required": true,
            "type": "integer",
            "description": "ID artikel"
          }
        ],
        "security": [
          {
            "BearerAuth": []
          }
        ]
      },
      "put": {
        "tags": [
          "Penulis"
        ],
        "summary": "Perbarui artikel",
        "description": "Memperbarui title, category, excerpt, content, cover_image_path (dan opsional is_published). Slug dibuat ulang bila judul berubah.",
        "produces": [
          "application/json"
        ],
        "responses": {
          "200": {
            "description": "Artikel diperbarui",
            "schema": {
              "$ref": "#/definitions/PostEnvelope"
            }
          },
          "400": {
            "description": "Input tidak valid",
            "schema": {
              "$ref": "#/definitions/FailResponse"
            }
          },
          "401": {
            "description": "Token tidak ada, tidak valid, atau kedaluwarsa",
            "schema": {
              "$ref": "#/definitions/FailResponse"
            }
          },
          "403": {
            "description": "Artikel milik pengguna lain",
            "schema": {
              "$ref": "#/definitions/FailResponse"
            }
          },
          "404": {
            "description": "Artikel tidak ditemukan",
            "schema": {
              "$ref": "#/definitions/FailResponse"
            }
          },
          "500": {
            "description": "Kesalahan server",
            "schema": {
              "$ref": "#/definitions/ErrorResponse"
            }
          }
        },
        "parameters": [
          {
            "name": "id",
            "in": "path",
            "required": true,
            "type": "integer",
            "description": "ID artikel"
          },
          {
            "name": "body",
            "in": "body",
            "required": true,
            "description": "Payload JSON",
            "schema": {
              "$ref": "#/definitions/PostRequest"
            }
          }
        ],
        "consumes": [
          "application/json"
        ],
        "security": [
          {
            "BearerAuth": []
          }
        ]
      },
      "delete": {
        "tags": [
          "Penulis"
        ],
        "summary": "Hapus artikel",
        "description": "Menghapus artikel milik sendiri.",
        "produces": [
          "application/json"
        ],
        "responses": {
          "200": {
            "description": "Artikel dihapus",
            "schema": {
              "$ref": "#/definitions/SuccessMessage"
            }
          },
          "400": {
            "description": "ID tidak valid",
            "schema": {
              "$ref": "#/definitions/FailResponse"
            }
          },
          "401": {
            "description": "Token tidak ada, tidak valid, atau kedaluwarsa",
            "schema": {
              "$ref": "#/definitions/FailResponse"
            }
          },
          "403": {
            "description": "Artikel milik pengguna lain",
            "schema": {
              "$ref": "#/definitions/FailResponse"
            }
          },
          "404": {
            "description": "Artikel tidak ditemukan",
            "schema": {
              "$ref": "#/definitions/FailResponse"
            }
          },
          "500": {
            "description": "Kesalahan server",
            "schema": {
              "$ref": "#/definitions/ErrorResponse"
            }
          }
        },
        "parameters": [
          {
            "name": "id",
            "in": "path",
            "required": true,
            "type": "integer",
            "description": "ID artikel"
          }
        ],
        "security": [
          {
            "BearerAuth": []
          }
        ]
      }
    },
    "/api/posts/{id}/toggle-publish": {
      "patch": {
        "tags": [
          "Penulis"
        ],
        "summary": "Toggle terbit/draf",
        "description": "Draf → Terbit mengisi published_at; Terbit → Draf mengosongkannya.",
        "produces": [
          "application/json"
        ],
        "responses": {
          "200": {
            "description": "Status diubah",
            "schema": {
              "$ref": "#/definitions/PostEnvelope"
            }
          },
          "400": {
            "description": "ID tidak valid",
            "schema": {
              "$ref": "#/definitions/FailResponse"
            }
          },
          "401": {
            "description": "Token tidak ada, tidak valid, atau kedaluwarsa",
            "schema": {
              "$ref": "#/definitions/FailResponse"
            }
          },
          "403": {
            "description": "Artikel milik pengguna lain",
            "schema": {
              "$ref": "#/definitions/FailResponse"
            }
          },
          "404": {
            "description": "Artikel tidak ditemukan",
            "schema": {
              "$ref": "#/definitions/FailResponse"
            }
          },
          "500": {
            "description": "Kesalahan server",
            "schema": {
              "$ref": "#/definitions/ErrorResponse"
            }
          }
        },
        "parameters": [
          {
            "name": "id",
            "in": "path",
            "required": true,
            "type": "integer",
            "description": "ID artikel"
          }
        ],
        "security": [
          {
            "BearerAuth": []
          }
        ]
      }
    },
    "/api/admin/users": {
      "get": {
        "tags": [
          "Admin"
        ],
        "summary": "Direktori pengguna",
        "description": "Seluruh pengguna beserta total_articles dan total_published. Hanya admin.",
        "produces": [
          "application/json"
        ],
        "responses": {
          "200": {
            "description": "Daftar pengguna",
            "schema": {
              "$ref": "#/definitions/AdminUsersEnvelope"
            }
          },
          "401": {
            "description": "Token tidak ada, tidak valid, atau kedaluwarsa",
            "schema": {
              "$ref": "#/definitions/FailResponse"
            }
          },
          "403": {
            "description": "Bukan admin",
            "schema": {
              "$ref": "#/definitions/FailResponse"
            }
          },
          "500": {
            "description": "Kesalahan server",
            "schema": {
              "$ref": "#/definitions/ErrorResponse"
            }
          }
        },
        "security": [
          {
            "BearerAuth": []
          }
        ]
      }
    },
    "/api/admin/posts": {
      "get": {
        "tags": [
          "Admin"
        ],
        "summary": "Arsip seluruh artikel",
        "description": "Artikel semua penulis (termasuk draf) beserta data penulis. Hanya admin.",
        "produces": [
          "application/json"
        ],
        "responses": {
          "200": {
            "description": "Daftar artikel",
            "schema": {
              "$ref": "#/definitions/PostListEnvelope"
            }
          },
          "401": {
            "description": "Token tidak ada, tidak valid, atau kedaluwarsa",
            "schema": {
              "$ref": "#/definitions/FailResponse"
            }
          },
          "403": {
            "description": "Bukan admin",
            "schema": {
              "$ref": "#/definitions/FailResponse"
            }
          },
          "500": {
            "description": "Kesalahan server",
            "schema": {
              "$ref": "#/definitions/ErrorResponse"
            }
          }
        },
        "security": [
          {
            "BearerAuth": []
          }
        ]
      }
    },
    "/api/admin/users/{id}/posts": {
      "get": {
        "tags": [
          "Admin"
        ],
        "summary": "Artikel per pengguna",
        "description": "Seluruh artikel milik pengguna tertentu. 404 bila pengguna tidak ada. Hanya admin.",
        "produces": [
          "application/json"
        ],
        "responses": {
          "200": {
            "description": "Daftar artikel",
            "schema": {
              "$ref": "#/definitions/PostListEnvelope"
            }
          },
          "400": {
            "description": "ID tidak valid",
            "schema": {
              "$ref": "#/definitions/FailResponse"
            }
          },
          "401": {
            "description": "Token tidak ada, tidak valid, atau kedaluwarsa",
            "schema": {
              "$ref": "#/definitions/FailResponse"
            }
          },
          "403": {
            "description": "Bukan admin",
            "schema": {
              "$ref": "#/definitions/FailResponse"
            }
          },
          "500": {
            "description": "Kesalahan server",
            "schema": {
              "$ref": "#/definitions/ErrorResponse"
            }
          }
        },
        "parameters": [
          {
            "name": "id",
            "in": "path",
            "required": true,
            "type": "integer",
            "description": "ID pengguna"
          }
        ],
        "security": [
          {
            "BearerAuth": []
          }
        ]
      }
    }
  },
  "definitions": {
    "FailResponse": {
      "type": "object",
      "properties": {
        "status": {
          "type": "string",
          "example": "fail",
          "enum": [
            "fail"
          ]
        },
        "message": {
          "type": "string",
          "example": "Pesan kesalahan klien (4xx)"
        }
      },
      "description": "Respons kegagalan klien (HTTP 4xx)."
    },
    "ErrorResponse": {
      "type": "object",
      "properties": {
        "status": {
          "type": "string",
          "example": "error",
          "enum": [
            "error"
          ]
        },
        "message": {
          "type": "string",
          "example": "Terjadi kesalahan pada server"
        }
      },
      "description": "Respons kesalahan server (HTTP 5xx)."
    },
    "SuccessMessage": {
      "type": "object",
      "properties": {
        "status": {
          "type": "string",
          "example": "success",
          "enum": [
            "success"
          ]
        },
        "message": {
          "type": "string",
          "example": "Operasi berhasil"
        }
      },
      "description": "Respons sukses tanpa data."
    },
    "User": {
      "type": "object",
      "properties": {
        "id": {
          "type": "integer",
          "example": 2
        },
        "username": {
          "type": "string",
          "example": "member"
        },
        "email": {
          "type": "string",
          "example": "member@delcom.org"
        },
        "role": {
          "type": "string",
          "example": "member",
          "enum": [
            "member",
            "admin"
          ]
        },
        "created_at": {
          "type": "string",
          "example": "2026-11-19T08:00:00Z",
          "format": "date-time"
        }
      }
    },
    "LoginData": {
      "type": "object",
      "properties": {
        "token": {
          "type": "string",
          "description": "JWT Bearer (berlaku 24 jam; berisi user_id, username, role)",
          "example": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..."
        },
        "user": {
          "$ref": "#/definitions/User"
        }
      }
    },
    "Author": {
      "type": "object",
      "properties": {
        "id": {
          "type": "integer",
          "example": 1
        },
        "username": {
          "type": "string",
          "example": "admin"
        }
      }
    },
    "Post": {
      "type": "object",
      "properties": {
        "id": {
          "type": "integer",
          "example": 12
        },
        "user_id": {
          "type": "integer",
          "example": 2
        },
        "title": {
          "type": "string",
          "example": "Mengenal Clean Architecture pada Aplikasi Go"
        },
        "slug": {
          "type": "string",
          "description": "Slug unik; tabrakan diberi sufiks -2, -3, dst.",
          "example": "mengenal-clean-architecture-pada-aplikasi-go"
        },
        "category": {
          "type": "string",
          "example": "Teknologi",
          "enum": [
            "Teknologi",
            "Pendidikan",
            "Gaya Hidup",
            "Bisnis",
            "Opini",
            "Umum"
          ]
        },
        "excerpt": {
          "type": "string",
          "example": "Memisahkan handler, service, dan repository."
        },
        "content": {
          "type": "string",
          "description": "Isi artikel dalam Markdown",
          "example": "# Judul\n\nIsi artikel..."
        },
        "cover_image_path": {
          "type": "string",
          "description": "URL/teks lokasi gambar sampul (tidak ada endpoint upload)",
          "example": "https://contoh.id/cover.jpg"
        },
        "is_published": {
          "type": "boolean",
          "example": true
        },
        "published_at": {
          "type": "string",
          "description": "null bila draf",
          "example": "2026-11-19T08:00:00Z",
          "format": "date-time"
        },
        "reading_time": {
          "type": "integer",
          "description": "Estimasi menit baca = ceil(jumlah kata / 200), minimal 1",
          "example": 3
        },
        "author": {
          "$ref": "#/definitions/Author"
        },
        "created_at": {
          "type": "string",
          "example": "2026-11-19T08:00:00Z",
          "format": "date-time"
        },
        "updated_at": {
          "type": "string",
          "example": "2026-11-19T08:00:00Z",
          "format": "date-time"
        }
      }
    },
    "PostRequest": {
      "type": "object",
      "properties": {
        "title": {
          "type": "string",
          "description": "Wajib, maksimal 255 karakter",
          "example": "Belajar Go untuk Pemula"
        },
        "category": {
          "type": "string",
          "description": "Salah satu dari 6 kategori; kosong = Umum; di luar daftar = 400",
          "example": "Teknologi",
          "enum": [
            "Teknologi",
            "Pendidikan",
            "Gaya Hidup",
            "Bisnis",
            "Opini",
            "Umum"
          ]
        },
        "excerpt": {
          "type": "string",
          "description": "Ringkasan 1-2 kalimat",
          "example": "Panduan singkat memulai Go."
        },
        "content": {
          "type": "string",
          "description": "Wajib, Markdown",
          "example": "# Halo\n\nIsi artikel."
        },
        "cover_image_path": {
          "type": "string",
          "example": "https://contoh.id/cover.jpg"
        },
        "is_published": {
          "type": "boolean",
          "description": "Opsional; menjaga konsistensi published_at",
          "example": false
        }
      },
      "required": [
        "title",
        "content"
      ]
    },
    "Stats": {
      "type": "object",
      "properties": {
        "total_articles": {
          "type": "integer",
          "description": "Total artikel",
          "example": 5
        },
        "total_terbit": {
          "type": "integer",
          "example": 3
        },
        "total_draf": {
          "type": "integer",
          "example": 2
        },
        "total_selesai": {
          "type": "integer",
          "description": "Alias total_terbit (istilah skrip)",
          "example": 3
        },
        "belum_selesai": {
          "type": "integer",
          "description": "Alias total_draf (istilah skrip)",
          "example": 2
        }
      }
    },
    "AdminUser": {
      "type": "object",
      "properties": {
        "id": {
          "type": "integer",
          "example": 2
        },
        "username": {
          "type": "string",
          "example": "member"
        },
        "email": {
          "type": "string",
          "example": "member@delcom.org"
        },
        "role": {
          "type": "string",
          "example": "member"
        },
        "total_articles": {
          "type": "integer",
          "example": 4
        },
        "total_published": {
          "type": "integer",
          "example": 2
        },
        "created_at": {
          "type": "string",
          "example": "2026-11-19T08:00:00Z",
          "format": "date-time"
        }
      }
    },
    "RegisterRequest": {
      "type": "object",
      "properties": {
        "username": {
          "type": "string",
          "description": "3-50 karakter: huruf, angka, titik, garis bawah, strip",
          "example": "budi"
        },
        "email": {
          "type": "string",
          "example": "budi@contoh.id"
        },
        "password": {
          "type": "string",
          "description": "Minimal 6 karakter (maks 72 byte)",
          "example": "rahasia123"
        },
        "role": {
          "type": "string",
          "description": "Opsional: 'admin' atau 'member'; selain itu dipaksa 'member'",
          "enum": [
            "admin",
            "member"
          ],
          "example": "member"
        }
      },
      "required": [
        "username",
        "email",
        "password"
      ],
      "description": "Field role opsional; hanya 'admin' atau 'member' yang diterima."
    },
    "LoginRequest": {
      "type": "object",
      "properties": {
        "username": {
          "type": "string",
          "description": "Username ATAU email",
          "example": "member"
        },
        "password": {
          "type": "string",
          "example": "member"
        }
      },
      "required": [
        "username",
        "password"
      ]
    },
    "UpdateProfileRequest": {
      "type": "object",
      "properties": {
        "email": {
          "type": "string",
          "example": "budi@contoh.id"
        },
        "password": {
          "type": "string",
          "description": "Opsional; kosongkan bila tidak diganti",
          "example": ""
        }
      },
      "required": [
        "email"
      ],
      "description": "Hanya email dan password yang dapat diubah; username tidak berubah."
    },
    "AIGenerateRequest": {
      "type": "object",
      "properties": {
        "topic": {
          "type": "string",
          "description": "Wajib, maksimal 300 karakter",
          "example": "Dampak AI terhadap pendidikan tinggi di Indonesia"
        },
        "category": {
          "type": "string",
          "description": "Opsional; petunjuk kategori",
          "example": "Pendidikan",
          "enum": [
            "Teknologi",
            "Pendidikan",
            "Gaya Hidup",
            "Bisnis",
            "Opini",
            "Umum"
          ]
        },
        "include_web_search": {
          "type": "boolean",
          "description": "true = konteks penelusuran Search Engine disertakan",
          "example": true
        }
      },
      "required": [
        "topic"
      ]
    },
    "SearchSource": {
      "type": "object",
      "properties": {
        "title": {
          "type": "string",
          "example": "Judul sumber"
        },
        "url": {
          "type": "string",
          "example": "https://contoh.id/sumber"
        },
        "snippet": {
          "type": "string",
          "example": "Cuplikan teks sumber"
        }
      }
    },
    "AIGenerateData": {
      "type": "object",
      "properties": {
        "title": {
          "type": "string",
          "example": "Judul dari AI"
        },
        "category": {
          "type": "string",
          "example": "Pendidikan",
          "enum": [
            "Teknologi",
            "Pendidikan",
            "Gaya Hidup",
            "Bisnis",
            "Opini",
            "Umum"
          ]
        },
        "excerpt": {
          "type": "string",
          "example": "Ringkasan."
        },
        "content": {
          "type": "string",
          "description": "Markdown berbahasa Indonesia (disertai '## Referensi' bila ada konteks web)",
          "example": "## Pendahuluan\n..."
        },
        "search_sources": {
          "type": "array",
          "items": {
            "$ref": "#/definitions/SearchSource"
          }
        }
      },
      "description": "Hasil TIDAK otomatis disimpan; klien menampilkan pratinjau lalu menerapkannya ke editor."
    },
    "UserEnvelope": {
      "type": "object",
      "properties": {
        "status": {
          "type": "string",
          "example": "success",
          "enum": [
            "success"
          ]
        },
        "message": {
          "type": "string",
          "example": "Profil berhasil diambil"
        },
        "data": {
          "$ref": "#/definitions/User"
        }
      }
    },
    "LoginEnvelope": {
      "type": "object",
      "properties": {
        "status": {
          "type": "string",
          "example": "success",
          "enum": [
            "success"
          ]
        },
        "message": {
          "type": "string",
          "example": "Login berhasil"
        },
        "data": {
          "$ref": "#/definitions/LoginData"
        }
      }
    },
    "CategoriesEnvelope": {
      "type": "object",
      "properties": {
        "status": {
          "type": "string",
          "example": "success",
          "enum": [
            "success"
          ]
        },
        "message": {
          "type": "string",
          "example": "Kategori berhasil diambil"
        },
        "data": {
          "type": "array",
          "items": {
            "type": "string",
            "example": "Teknologi",
            "enum": [
              "Teknologi",
              "Pendidikan",
              "Gaya Hidup",
              "Bisnis",
              "Opini",
              "Umum"
            ]
          }
        }
      }
    },
    "PostEnvelope": {
      "type": "object",
      "properties": {
        "status": {
          "type": "string",
          "example": "success",
          "enum": [
            "success"
          ]
        },
        "message": {
          "type": "string",
          "example": "Artikel berhasil diambil"
        },
        "data": {
          "$ref": "#/definitions/Post"
        }
      }
    },
    "PostListEnvelope": {
      "type": "object",
      "properties": {
        "status": {
          "type": "string",
          "example": "success",
          "enum": [
            "success"
          ]
        },
        "message": {
          "type": "string",
          "example": "Artikel berhasil diambil"
        },
        "data": {
          "type": "array",
          "items": {
            "$ref": "#/definitions/Post"
          }
        }
      }
    },
    "StatsEnvelope": {
      "type": "object",
      "properties": {
        "status": {
          "type": "string",
          "example": "success",
          "enum": [
            "success"
          ]
        },
        "message": {
          "type": "string",
          "example": "Statistik berhasil diambil"
        },
        "data": {
          "$ref": "#/definitions/Stats"
        }
      }
    },
    "AdminUsersEnvelope": {
      "type": "object",
      "properties": {
        "status": {
          "type": "string",
          "example": "success",
          "enum": [
            "success"
          ]
        },
        "message": {
          "type": "string",
          "example": "Pengguna berhasil diambil"
        },
        "data": {
          "type": "array",
          "items": {
            "$ref": "#/definitions/AdminUser"
          }
        }
      }
    },
    "AIGenerateEnvelope": {
      "type": "object",
      "properties": {
        "status": {
          "type": "string",
          "example": "success",
          "enum": [
            "success"
          ]
        },
        "message": {
          "type": "string",
          "example": "Draf artikel berhasil dibuat"
        },
        "data": {
          "$ref": "#/definitions/AIGenerateData"
        }
      }
    },
    "PublicPost": {
      "type": "object",
      "properties": {
        "id": {
          "type": "integer",
          "example": 12
        },
        "title": {
          "type": "string",
          "example": "Mengenal Clean Architecture pada Aplikasi Go"
        },
        "slug": {
          "type": "string",
          "description": "Slug unik; tabrakan diberi sufiks -2, -3, dst.",
          "example": "mengenal-clean-architecture-pada-aplikasi-go"
        },
        "category": {
          "type": "string",
          "example": "Teknologi",
          "enum": [
            "Teknologi",
            "Pendidikan",
            "Gaya Hidup",
            "Bisnis",
            "Opini",
            "Umum"
          ]
        },
        "excerpt": {
          "type": "string",
          "example": "Memisahkan handler, service, dan repository."
        },
        "content": {
          "type": "string",
          "description": "Isi artikel dalam Markdown",
          "example": "# Judul\n\nIsi artikel..."
        },
        "cover_image_path": {
          "type": "string",
          "description": "URL/teks lokasi gambar sampul (tidak ada endpoint upload)",
          "example": "https://contoh.id/cover.jpg"
        },
        "is_published": {
          "type": "boolean",
          "example": true
        },
        "published_at": {
          "type": "string",
          "description": "null bila draf",
          "example": "2026-11-19T08:00:00Z",
          "format": "date-time"
        },
        "reading_time": {
          "type": "integer",
          "description": "Estimasi menit baca = ceil(jumlah kata / 200), minimal 1",
          "example": 3
        },
        "created_at": {
          "type": "string",
          "example": "2026-11-19T08:00:00Z",
          "format": "date-time"
        },
        "updated_at": {
          "type": "string",
          "example": "2026-11-19T08:00:00Z",
          "format": "date-time"
        },
        "author_name": {
          "type": "string",
          "description": "Nama penulis",
          "example": "member"
        }
      }
    },
    "PublicPostEnvelope": {
      "type": "object",
      "properties": {
        "status": {
          "type": "string",
          "example": "success",
          "enum": [
            "success"
          ]
        },
        "message": {
          "type": "string",
          "example": "Artikel berhasil diambil"
        },
        "data": {
          "$ref": "#/definitions/PublicPost"
        }
      }
    },
    "PublicPostListEnvelope": {
      "type": "object",
      "properties": {
        "status": {
          "type": "string",
          "example": "success",
          "enum": [
            "success"
          ]
        },
        "message": {
          "type": "string",
          "example": "Artikel berhasil diambil"
        },
        "data": {
          "type": "array",
          "items": {
            "$ref": "#/definitions/PublicPost"
          }
        }
      }
    }
  }
}
'@

Write-Repo 'docs/swagger.yaml' @'
swagger: '2.0'
info:
  title: Delcom Blog REST API
  description: Dokumentasi RESTful API Delcom Blog (Golang Gin, Clean Architecture & Feature-First) dengan
    AI Blog Generator terintegrasi Search Engine. Seluruh respons berformat {status, message, data?}.
  version: 1.0.0
  contact:
    name: Delcom - Labs
host: localhost:8081
basePath: /
schemes:
- http
consumes:
- application/json
produces:
- application/json
tags:
- name: Dokumentasi
- name: Publik
- name: Autentikasi
- name: Penulis
- name: Admin
securityDefinitions:
  BearerAuth:
    type: apiKey
    name: Authorization
    in: header
    description: 'Masukkan: Bearer <token JWT>'
paths:
  /swagger/{any}:
    get:
      tags:
      - Dokumentasi
      summary: Swagger UI
      description: Dokumentasi interaktif Swagger UI (http://localhost:8081/swagger/index.html). `/swagger`
        dialihkan ke `/swagger/index.html`.
      produces:
      - application/json
      responses:
        '200':
          description: Halaman Swagger UI
      parameters:
      - name: any
        in: path
        required: true
        type: string
        description: Berkas Swagger UI, mis. index.html
  /api.json:
    get:
      tags:
      - Dokumentasi
      summary: Spesifikasi OpenAPI dinamis
      description: Spesifikasi OpenAPI/Swagger JSON; host dan scheme menyesuaikan request (menghormati
        X-Forwarded-Host dan X-Forwarded-Proto).
      produces:
      - application/json
      responses:
        '200':
          description: Dokumen OpenAPI 2.0
  /api/public/categories:
    get:
      tags:
      - Publik
      summary: Daftar kategori
      description: 'Enam kategori artikel: Teknologi, Pendidikan, Gaya Hidup, Bisnis, Opini, Umum.'
      produces:
      - application/json
      responses:
        '200':
          description: Daftar kategori
          schema:
            $ref: '#/definitions/CategoriesEnvelope'
  /api/public/posts:
    get:
      tags:
      - Publik
      summary: Daftar artikel terbit
      description: Hanya artikel `is_published=true`, terbaru lebih dulu. Pencarian `q` tidak membedakan
        huruf besar/kecil pada judul, ringkasan, dan konten.
      produces:
      - application/json
      responses:
        '200':
          description: Daftar artikel terbit
          schema:
            $ref: '#/definitions/PublicPostListEnvelope'
        '500':
          description: Kesalahan server
          schema:
            $ref: '#/definitions/ErrorResponse'
      parameters:
      - name: q
        in: query
        type: string
        description: Kata kunci pencarian
      - name: category
        in: query
        type: string
        enum:
        - Teknologi
        - Pendidikan
        - Gaya Hidup
        - Bisnis
        - Opini
        - Umum
        description: Filter kategori (kosong/Semua = semua kategori)
  /api/public/posts/{slug}:
    get:
      tags:
      - Publik
      summary: Detail artikel publik
      description: Artikel terbit berdasarkan slug, lengkap dengan penulis dan reading_time. Draf menghasilkan
        404.
      produces:
      - application/json
      responses:
        '200':
          description: Detail artikel
          schema:
            $ref: '#/definitions/PublicPostEnvelope'
        '404':
          description: Artikel tidak ditemukan
          schema:
            $ref: '#/definitions/FailResponse'
        '500':
          description: Kesalahan server
          schema:
            $ref: '#/definitions/ErrorResponse'
      parameters:
      - name: slug
        in: path
        required: true
        type: string
        description: Slug artikel
  /api/auth/register:
    post:
      tags:
      - Autentikasi
      summary: Registrasi akun
      description: 'Membuat akun penulis dan langsung mengembalikan token JWT. Field `role` opsional:
        hanya `admin` atau `member` yang diterima, nilai lain dipaksa `member`.'
      produces:
      - application/json
      responses:
        '201':
          description: Registrasi berhasil
          schema:
            $ref: '#/definitions/LoginEnvelope'
        '400':
          description: Input tidak valid, atau username/email sudah dipakai
          schema:
            $ref: '#/definitions/FailResponse'
        '500':
          description: Kesalahan server
          schema:
            $ref: '#/definitions/ErrorResponse'
      parameters:
      - name: body
        in: body
        required: true
        description: Payload JSON
        schema:
          $ref: '#/definitions/RegisterRequest'
      consumes:
      - application/json
  /api/auth/login:
    post:
      tags:
      - Autentikasi
      summary: Login
      description: Mengautentikasi username atau email dan menerbitkan JWT. Pesan gagal tidak membedakan
        'pengguna tidak ada' dan 'password salah'.
      produces:
      - application/json
      responses:
        '200':
          description: Login berhasil
          schema:
            $ref: '#/definitions/LoginEnvelope'
        '400':
          description: Input tidak valid
          schema:
            $ref: '#/definitions/FailResponse'
        '401':
          description: Kredensial salah
          schema:
            $ref: '#/definitions/FailResponse'
        '500':
          description: Kesalahan server
          schema:
            $ref: '#/definitions/ErrorResponse'
      parameters:
      - name: body
        in: body
        required: true
        description: Payload JSON
        schema:
          $ref: '#/definitions/LoginRequest'
      consumes:
      - application/json
  /api/auth/logout:
    post:
      tags:
      - Autentikasi
      summary: Logout
      description: 'Mengakhiri sesi (JWT stateless: klien menghapus token).'
      produces:
      - application/json
      responses:
        '200':
          description: Logout berhasil
          schema:
            $ref: '#/definitions/SuccessMessage'
        '401':
          description: Token tidak ada, tidak valid, atau kedaluwarsa
          schema:
            $ref: '#/definitions/FailResponse'
      security:
      - BearerAuth: []
  /api/auth/profile:
    get:
      tags:
      - Autentikasi
      summary: Ambil profil
      description: Profil pengguna yang sedang login.
      produces:
      - application/json
      responses:
        '200':
          description: Profil
          schema:
            $ref: '#/definitions/UserEnvelope'
        '401':
          description: Token tidak ada, tidak valid, atau kedaluwarsa
          schema:
            $ref: '#/definitions/FailResponse'
        '500':
          description: Kesalahan server
          schema:
            $ref: '#/definitions/ErrorResponse'
      security:
      - BearerAuth: []
    put:
      tags:
      - Autentikasi
      summary: Perbarui profil
      description: Memperbarui username, email, dan (opsional) password.
      produces:
      - application/json
      responses:
        '200':
          description: Profil diperbarui
          schema:
            $ref: '#/definitions/UserEnvelope'
        '400':
          description: Input tidak valid, atau email sudah dipakai
          schema:
            $ref: '#/definitions/FailResponse'
        '401':
          description: Token tidak ada, tidak valid, atau kedaluwarsa
          schema:
            $ref: '#/definitions/FailResponse'
        '500':
          description: Kesalahan server
          schema:
            $ref: '#/definitions/ErrorResponse'
      parameters:
      - name: body
        in: body
        required: true
        description: Payload JSON
        schema:
          $ref: '#/definitions/UpdateProfileRequest'
      consumes:
      - application/json
      security:
      - BearerAuth: []
  /api/posts:
    get:
      tags:
      - Penulis
      summary: Artikel milik saya
      description: Seluruh artikel milik penulis login (terbit dan draf).
      produces:
      - application/json
      responses:
        '200':
          description: Daftar artikel
          schema:
            $ref: '#/definitions/PostListEnvelope'
        '401':
          description: Token tidak ada, tidak valid, atau kedaluwarsa
          schema:
            $ref: '#/definitions/FailResponse'
        '500':
          description: Kesalahan server
          schema:
            $ref: '#/definitions/ErrorResponse'
      security:
      - BearerAuth: []
    post:
      tags:
      - Penulis
      summary: Buat artikel
      description: Membuat artikel; slug unik otomatis, reading_time dihitung dari konten.
      produces:
      - application/json
      responses:
        '201':
          description: Artikel dibuat
          schema:
            $ref: '#/definitions/PostEnvelope'
        '400':
          description: Input tidak valid
          schema:
            $ref: '#/definitions/FailResponse'
        '401':
          description: Token tidak ada, tidak valid, atau kedaluwarsa
          schema:
            $ref: '#/definitions/FailResponse'
        '500':
          description: Kesalahan server
          schema:
            $ref: '#/definitions/ErrorResponse'
      parameters:
      - name: body
        in: body
        required: true
        description: Payload JSON
        schema:
          $ref: '#/definitions/PostRequest'
      consumes:
      - application/json
      security:
      - BearerAuth: []
  /api/posts/stats:
    get:
      tags:
      - Penulis
      summary: Statistik penulis
      description: 'Tiga kartu statistik: total_articles, total_terbit, total_draf; alias total_selesai
        (= terbit) dan belum_selesai (= draf).'
      produces:
      - application/json
      responses:
        '200':
          description: Statistik
          schema:
            $ref: '#/definitions/StatsEnvelope'
        '401':
          description: Token tidak ada, tidak valid, atau kedaluwarsa
          schema:
            $ref: '#/definitions/FailResponse'
        '500':
          description: Kesalahan server
          schema:
            $ref: '#/definitions/ErrorResponse'
      security:
      - BearerAuth: []
  /api/posts/ai-generate:
    post:
      tags:
      - Penulis
      summary: AI Blog Generator (+ Search Engine)
      description: Menyusun draf artikel dengan OpenAI. Bila `include_web_search=true`, konteks dari Search
        Engine disertakan dan sumbernya dikembalikan di `search_sources`. Kegagalan pencarian tidak menggagalkan
        request. Hasil tidak otomatis disimpan.
      produces:
      - application/json
      responses:
        '200':
          description: Draf artikel
          schema:
            $ref: '#/definitions/AIGenerateEnvelope'
        '400':
          description: Input tidak valid
          schema:
            $ref: '#/definitions/FailResponse'
        '401':
          description: Token tidak ada, tidak valid, atau kedaluwarsa
          schema:
            $ref: '#/definitions/FailResponse'
        '500':
          description: OpenAI tidak tersedia / gagal, atau kesalahan server
          schema:
            $ref: '#/definitions/ErrorResponse'
      parameters:
      - name: body
        in: body
        required: true
        description: Payload JSON
        schema:
          $ref: '#/definitions/AIGenerateRequest'
      consumes:
      - application/json
      security:
      - BearerAuth: []
  /api/posts/{id}:
    get:
      tags:
      - Penulis
      summary: Detail artikel saya
      description: Hanya artikel milik sendiri; milik orang lain menghasilkan 404.
      produces:
      - application/json
      responses:
        '200':
          description: Detail artikel
          schema:
            $ref: '#/definitions/PostEnvelope'
        '400':
          description: ID tidak valid
          schema:
            $ref: '#/definitions/FailResponse'
        '401':
          description: Token tidak ada, tidak valid, atau kedaluwarsa
          schema:
            $ref: '#/definitions/FailResponse'
        '403':
          description: Artikel milik pengguna lain
          schema:
            $ref: '#/definitions/FailResponse'
        '404':
          description: Artikel tidak ditemukan
          schema:
            $ref: '#/definitions/FailResponse'
        '500':
          description: Kesalahan server
          schema:
            $ref: '#/definitions/ErrorResponse'
      parameters:
      - name: id
        in: path
        required: true
        type: integer
        description: ID artikel
      security:
      - BearerAuth: []
    put:
      tags:
      - Penulis
      summary: Perbarui artikel
      description: Memperbarui title, category, excerpt, content, cover_image_path (dan opsional is_published).
        Slug dibuat ulang bila judul berubah.
      produces:
      - application/json
      responses:
        '200':
          description: Artikel diperbarui
          schema:
            $ref: '#/definitions/PostEnvelope'
        '400':
          description: Input tidak valid
          schema:
            $ref: '#/definitions/FailResponse'
        '401':
          description: Token tidak ada, tidak valid, atau kedaluwarsa
          schema:
            $ref: '#/definitions/FailResponse'
        '403':
          description: Artikel milik pengguna lain
          schema:
            $ref: '#/definitions/FailResponse'
        '404':
          description: Artikel tidak ditemukan
          schema:
            $ref: '#/definitions/FailResponse'
        '500':
          description: Kesalahan server
          schema:
            $ref: '#/definitions/ErrorResponse'
      parameters:
      - name: id
        in: path
        required: true
        type: integer
        description: ID artikel
      - name: body
        in: body
        required: true
        description: Payload JSON
        schema:
          $ref: '#/definitions/PostRequest'
      consumes:
      - application/json
      security:
      - BearerAuth: []
    delete:
      tags:
      - Penulis
      summary: Hapus artikel
      description: Menghapus artikel milik sendiri.
      produces:
      - application/json
      responses:
        '200':
          description: Artikel dihapus
          schema:
            $ref: '#/definitions/SuccessMessage'
        '400':
          description: ID tidak valid
          schema:
            $ref: '#/definitions/FailResponse'
        '401':
          description: Token tidak ada, tidak valid, atau kedaluwarsa
          schema:
            $ref: '#/definitions/FailResponse'
        '403':
          description: Artikel milik pengguna lain
          schema:
            $ref: '#/definitions/FailResponse'
        '404':
          description: Artikel tidak ditemukan
          schema:
            $ref: '#/definitions/FailResponse'
        '500':
          description: Kesalahan server
          schema:
            $ref: '#/definitions/ErrorResponse'
      parameters:
      - name: id
        in: path
        required: true
        type: integer
        description: ID artikel
      security:
      - BearerAuth: []
  /api/posts/{id}/toggle-publish:
    patch:
      tags:
      - Penulis
      summary: Toggle terbit/draf
      description: Draf → Terbit mengisi published_at; Terbit → Draf mengosongkannya.
      produces:
      - application/json
      responses:
        '200':
          description: Status diubah
          schema:
            $ref: '#/definitions/PostEnvelope'
        '400':
          description: ID tidak valid
          schema:
            $ref: '#/definitions/FailResponse'
        '401':
          description: Token tidak ada, tidak valid, atau kedaluwarsa
          schema:
            $ref: '#/definitions/FailResponse'
        '403':
          description: Artikel milik pengguna lain
          schema:
            $ref: '#/definitions/FailResponse'
        '404':
          description: Artikel tidak ditemukan
          schema:
            $ref: '#/definitions/FailResponse'
        '500':
          description: Kesalahan server
          schema:
            $ref: '#/definitions/ErrorResponse'
      parameters:
      - name: id
        in: path
        required: true
        type: integer
        description: ID artikel
      security:
      - BearerAuth: []
  /api/admin/users:
    get:
      tags:
      - Admin
      summary: Direktori pengguna
      description: Seluruh pengguna beserta total_articles dan total_published. Hanya admin.
      produces:
      - application/json
      responses:
        '200':
          description: Daftar pengguna
          schema:
            $ref: '#/definitions/AdminUsersEnvelope'
        '401':
          description: Token tidak ada, tidak valid, atau kedaluwarsa
          schema:
            $ref: '#/definitions/FailResponse'
        '403':
          description: Bukan admin
          schema:
            $ref: '#/definitions/FailResponse'
        '500':
          description: Kesalahan server
          schema:
            $ref: '#/definitions/ErrorResponse'
      security:
      - BearerAuth: []
  /api/admin/posts:
    get:
      tags:
      - Admin
      summary: Arsip seluruh artikel
      description: Artikel semua penulis (termasuk draf) beserta data penulis. Hanya admin.
      produces:
      - application/json
      responses:
        '200':
          description: Daftar artikel
          schema:
            $ref: '#/definitions/PostListEnvelope'
        '401':
          description: Token tidak ada, tidak valid, atau kedaluwarsa
          schema:
            $ref: '#/definitions/FailResponse'
        '403':
          description: Bukan admin
          schema:
            $ref: '#/definitions/FailResponse'
        '500':
          description: Kesalahan server
          schema:
            $ref: '#/definitions/ErrorResponse'
      security:
      - BearerAuth: []
  /api/admin/users/{id}/posts:
    get:
      tags:
      - Admin
      summary: Artikel per pengguna
      description: Seluruh artikel milik pengguna tertentu. 404 bila pengguna tidak ada. Hanya admin.
      produces:
      - application/json
      responses:
        '200':
          description: Daftar artikel
          schema:
            $ref: '#/definitions/PostListEnvelope'
        '400':
          description: ID tidak valid
          schema:
            $ref: '#/definitions/FailResponse'
        '401':
          description: Token tidak ada, tidak valid, atau kedaluwarsa
          schema:
            $ref: '#/definitions/FailResponse'
        '403':
          description: Bukan admin
          schema:
            $ref: '#/definitions/FailResponse'
        '500':
          description: Kesalahan server
          schema:
            $ref: '#/definitions/ErrorResponse'
      parameters:
      - name: id
        in: path
        required: true
        type: integer
        description: ID pengguna
      security:
      - BearerAuth: []
definitions:
  FailResponse:
    type: object
    properties:
      status:
        type: string
        example: fail
        enum:
        - fail
      message:
        type: string
        example: Pesan kesalahan klien (4xx)
    description: Respons kegagalan klien (HTTP 4xx).
  ErrorResponse:
    type: object
    properties:
      status:
        type: string
        example: error
        enum:
        - error
      message:
        type: string
        example: Terjadi kesalahan pada server
    description: Respons kesalahan server (HTTP 5xx).
  SuccessMessage:
    type: object
    properties:
      status:
        type: string
        example: success
        enum:
        - success
      message:
        type: string
        example: Operasi berhasil
    description: Respons sukses tanpa data.
  User:
    type: object
    properties:
      id:
        type: integer
        example: 2
      username:
        type: string
        example: member
      email:
        type: string
        example: member@delcom.org
      role:
        type: string
        example: member
        enum:
        - member
        - admin
      created_at:
        type: string
        example: '2026-11-19T08:00:00Z'
        format: date-time
  LoginData:
    type: object
    properties:
      token:
        type: string
        description: JWT Bearer (berlaku 24 jam; berisi user_id, username, role)
        example: eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...
      user:
        $ref: '#/definitions/User'
  Author:
    type: object
    properties:
      id:
        type: integer
        example: 1
      username:
        type: string
        example: admin
  Post:
    type: object
    properties:
      id:
        type: integer
        example: 12
      user_id:
        type: integer
        example: 2
      title:
        type: string
        example: Mengenal Clean Architecture pada Aplikasi Go
      slug:
        type: string
        description: Slug unik; tabrakan diberi sufiks -2, -3, dst.
        example: mengenal-clean-architecture-pada-aplikasi-go
      category:
        type: string
        example: Teknologi
        enum:
        - Teknologi
        - Pendidikan
        - Gaya Hidup
        - Bisnis
        - Opini
        - Umum
      excerpt:
        type: string
        example: Memisahkan handler, service, dan repository.
      content:
        type: string
        description: Isi artikel dalam Markdown
        example: '# Judul


          Isi artikel...'
      cover_image_path:
        type: string
        description: URL/teks lokasi gambar sampul (tidak ada endpoint upload)
        example: https://contoh.id/cover.jpg
      is_published:
        type: boolean
        example: true
      published_at:
        type: string
        description: null bila draf
        example: '2026-11-19T08:00:00Z'
        format: date-time
      reading_time:
        type: integer
        description: Estimasi menit baca = ceil(jumlah kata / 200), minimal 1
        example: 3
      author:
        $ref: '#/definitions/Author'
      created_at:
        type: string
        example: '2026-11-19T08:00:00Z'
        format: date-time
      updated_at:
        type: string
        example: '2026-11-19T08:00:00Z'
        format: date-time
  PostRequest:
    type: object
    properties:
      title:
        type: string
        description: Wajib, maksimal 255 karakter
        example: Belajar Go untuk Pemula
      category:
        type: string
        description: Salah satu dari 6 kategori; kosong = Umum; di luar daftar = 400
        example: Teknologi
        enum:
        - Teknologi
        - Pendidikan
        - Gaya Hidup
        - Bisnis
        - Opini
        - Umum
      excerpt:
        type: string
        description: Ringkasan 1-2 kalimat
        example: Panduan singkat memulai Go.
      content:
        type: string
        description: Wajib, Markdown
        example: '# Halo


          Isi artikel.'
      cover_image_path:
        type: string
        example: https://contoh.id/cover.jpg
      is_published:
        type: boolean
        description: Opsional; menjaga konsistensi published_at
        example: false
    required:
    - title
    - content
  Stats:
    type: object
    properties:
      total_articles:
        type: integer
        description: Total artikel
        example: 5
      total_terbit:
        type: integer
        example: 3
      total_draf:
        type: integer
        example: 2
      total_selesai:
        type: integer
        description: Alias total_terbit (istilah skrip)
        example: 3
      belum_selesai:
        type: integer
        description: Alias total_draf (istilah skrip)
        example: 2
  AdminUser:
    type: object
    properties:
      id:
        type: integer
        example: 2
      username:
        type: string
        example: member
      email:
        type: string
        example: member@delcom.org
      role:
        type: string
        example: member
      total_articles:
        type: integer
        example: 4
      total_published:
        type: integer
        example: 2
      created_at:
        type: string
        example: '2026-11-19T08:00:00Z'
        format: date-time
  RegisterRequest:
    type: object
    properties:
      username:
        type: string
        description: '3-50 karakter: huruf, angka, titik, garis bawah, strip'
        example: budi
      email:
        type: string
        example: budi@contoh.id
      password:
        type: string
        description: Minimal 6 karakter (maks 72 byte)
        example: rahasia123
      role:
        type: string
        description: 'Opsional: ''admin'' atau ''member''; selain itu dipaksa ''member'''
        enum:
        - admin
        - member
        example: member
    required:
    - username
    - email
    - password
    description: Field role opsional; hanya 'admin' atau 'member' yang diterima.
  LoginRequest:
    type: object
    properties:
      username:
        type: string
        description: Username ATAU email
        example: member
      password:
        type: string
        example: member
    required:
    - username
    - password
  UpdateProfileRequest:
    type: object
    properties:
      email:
        type: string
        example: budi@contoh.id
      password:
        type: string
        description: Opsional; kosongkan bila tidak diganti
        example: ''
    required:
    - email
    description: Hanya email dan password yang dapat diubah; username tidak berubah.
  AIGenerateRequest:
    type: object
    properties:
      topic:
        type: string
        description: Wajib, maksimal 300 karakter
        example: Dampak AI terhadap pendidikan tinggi di Indonesia
      category:
        type: string
        description: Opsional; petunjuk kategori
        example: Pendidikan
        enum:
        - Teknologi
        - Pendidikan
        - Gaya Hidup
        - Bisnis
        - Opini
        - Umum
      include_web_search:
        type: boolean
        description: true = konteks penelusuran Search Engine disertakan
        example: true
    required:
    - topic
  SearchSource:
    type: object
    properties:
      title:
        type: string
        example: Judul sumber
      url:
        type: string
        example: https://contoh.id/sumber
      snippet:
        type: string
        example: Cuplikan teks sumber
  AIGenerateData:
    type: object
    properties:
      title:
        type: string
        example: Judul dari AI
      category:
        type: string
        example: Pendidikan
        enum:
        - Teknologi
        - Pendidikan
        - Gaya Hidup
        - Bisnis
        - Opini
        - Umum
      excerpt:
        type: string
        example: Ringkasan.
      content:
        type: string
        description: Markdown berbahasa Indonesia (disertai '## Referensi' bila ada konteks web)
        example: '## Pendahuluan

          ...'
      search_sources:
        type: array
        items:
          $ref: '#/definitions/SearchSource'
    description: Hasil TIDAK otomatis disimpan; klien menampilkan pratinjau lalu menerapkannya ke editor.
  UserEnvelope:
    type: object
    properties:
      status:
        type: string
        example: success
        enum:
        - success
      message:
        type: string
        example: Profil berhasil diambil
      data:
        $ref: '#/definitions/User'
  LoginEnvelope:
    type: object
    properties:
      status:
        type: string
        example: success
        enum:
        - success
      message:
        type: string
        example: Login berhasil
      data:
        $ref: '#/definitions/LoginData'
  CategoriesEnvelope:
    type: object
    properties:
      status:
        type: string
        example: success
        enum:
        - success
      message:
        type: string
        example: Kategori berhasil diambil
      data:
        type: array
        items:
          type: string
          example: Teknologi
          enum:
          - Teknologi
          - Pendidikan
          - Gaya Hidup
          - Bisnis
          - Opini
          - Umum
  PostEnvelope:
    type: object
    properties:
      status:
        type: string
        example: success
        enum:
        - success
      message:
        type: string
        example: Artikel berhasil diambil
      data:
        $ref: '#/definitions/Post'
  PostListEnvelope:
    type: object
    properties:
      status:
        type: string
        example: success
        enum:
        - success
      message:
        type: string
        example: Artikel berhasil diambil
      data:
        type: array
        items:
          $ref: '#/definitions/Post'
  StatsEnvelope:
    type: object
    properties:
      status:
        type: string
        example: success
        enum:
        - success
      message:
        type: string
        example: Statistik berhasil diambil
      data:
        $ref: '#/definitions/Stats'
  AdminUsersEnvelope:
    type: object
    properties:
      status:
        type: string
        example: success
        enum:
        - success
      message:
        type: string
        example: Pengguna berhasil diambil
      data:
        type: array
        items:
          $ref: '#/definitions/AdminUser'
  AIGenerateEnvelope:
    type: object
    properties:
      status:
        type: string
        example: success
        enum:
        - success
      message:
        type: string
        example: Draf artikel berhasil dibuat
      data:
        $ref: '#/definitions/AIGenerateData'
  PublicPost:
    type: object
    properties:
      id:
        type: integer
        example: 12
      title:
        type: string
        example: Mengenal Clean Architecture pada Aplikasi Go
      slug:
        type: string
        description: Slug unik; tabrakan diberi sufiks -2, -3, dst.
        example: mengenal-clean-architecture-pada-aplikasi-go
      category:
        type: string
        example: Teknologi
        enum:
        - Teknologi
        - Pendidikan
        - Gaya Hidup
        - Bisnis
        - Opini
        - Umum
      excerpt:
        type: string
        example: Memisahkan handler, service, dan repository.
      content:
        type: string
        description: Isi artikel dalam Markdown
        example: '# Judul


          Isi artikel...'
      cover_image_path:
        type: string
        description: URL/teks lokasi gambar sampul (tidak ada endpoint upload)
        example: https://contoh.id/cover.jpg
      is_published:
        type: boolean
        example: true
      published_at:
        type: string
        description: null bila draf
        example: '2026-11-19T08:00:00Z'
        format: date-time
      reading_time:
        type: integer
        description: Estimasi menit baca = ceil(jumlah kata / 200), minimal 1
        example: 3
      created_at:
        type: string
        example: '2026-11-19T08:00:00Z'
        format: date-time
      updated_at:
        type: string
        example: '2026-11-19T08:00:00Z'
        format: date-time
      author_name:
        type: string
        description: Nama penulis
        example: member
  PublicPostEnvelope:
    type: object
    properties:
      status:
        type: string
        example: success
        enum:
        - success
      message:
        type: string
        example: Artikel berhasil diambil
      data:
        $ref: '#/definitions/PublicPost'
  PublicPostListEnvelope:
    type: object
    properties:
      status:
        type: string
        example: success
        enum:
        - success
      message:
        type: string
        example: Artikel berhasil diambil
      data:
        type: array
        items:
          $ref: '#/definitions/PublicPost'
'@

Write-Repo 'internal/features/ai/ai_test.go' @'
package ai

import (
	"bytes"
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"net/http"
	"net/http/httptest"
	"strings"
	"sync"
	"testing"
	"time"

	"github.com/gin-gonic/gin"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

var errBoom = errors.New("boom")

func init() { gin.SetMode(gin.TestMode) }

// serve membuat httptest.Server yang menjawab body tertentu.
func serve(t *testing.T, status int, body string) *httptest.Server {
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Content-Type", "application/json")
		w.WriteHeader(status)
		_, _ = io.WriteString(w, body)
	}))
	t.Cleanup(srv.Close)
	return srv
}

// truncated menjanjikan 100 byte tetapi hanya mengirim sebagian, sehingga pembacaan body gagal.
func truncated(t *testing.T) *httptest.Server {
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Content-Length", "100")
		_, _ = io.WriteString(w, "pendek")
	}))
	t.Cleanup(srv.Close)
	return srv
}

func closedURL(t *testing.T) string {
	srv := httptest.NewServer(http.NotFoundHandler())
	u := srv.URL
	srv.Close()
	return u
}

var ctx = context.Background()

// ---------- search ----------

func TestSearchVariantsOfJSON(t *testing.T) {
	cases := map[string]struct {
		body string
		want []SearchSource
	}{
		"results": {`{"results":[{"title":"A","snippet":"sa","url":"https://a.id"}]}`,
			[]SearchSource{{"A", "https://a.id", "sa"}}},
		"data.results": {`{"data":{"results":[{"title":"B","content":"sb","link":"https://b.id"}]}}`,
			[]SearchSource{{"B", "https://b.id", "sb"}}},
		"data array": {`{"data":[{"name":"C","description":"sc","href":"http://c.id/x"}]}`,
			[]SearchSource{{"C", "http://c.id/x", "sc"}}},
		"items": {`{"items":[{"title":"D","text":"sd","url":"https://d.id"}]}`,
			[]SearchSource{{"D", "https://d.id", "sd"}}},
		"organic_results": {`{"organic_results":[{"title":"E","body":"se","url":"https://e.id"}]}`,
			[]SearchSource{{"E", "https://e.id", "se"}}},
		"top-level array": {`[{"title":"F","summary":"sf","url":"https://f.id"},"bukan objek"]`,
			[]SearchSource{{"F", "https://f.id", "sf"}}},
		"opensearch": {`["topik",["G","H"],["sg"],["https://g.id","https://h.id"]]`,
			[]SearchSource{{"G", "https://g.id", "sg"}, {"H", "https://h.id", ""}}},
		"wikipedia": {`{"query":{"search":[{"title":"Danau Toba","snippet":"<span class=\"x\">danau</span> &amp; kaldera"},"abaikan"]}}`,
			[]SearchSource{{"Danau Toba", "https://id.wikipedia.org/wiki/Danau_Toba", "danau & kaldera"}}},
		"title kosong memakai url": {`{"results":[{"url":"https://z.id","snippet":"s"}]}`,
			[]SearchSource{{"https://z.id", "https://z.id", "s"}}},
		"url berbahaya dibuang": {`{"results":[{"title":"X","url":"javascript:alert(1)","snippet":"s"},{"title":"Y","url":"ftp://y.id"},{"title":"Z","url":"https:///tanpa-host"},{"title":"W","url":"http://[::1"}]}`,
			[]SearchSource{{"X", "", "s"}, {"Y", "", ""}, {"Z", "", ""}, {"W", "", ""}}},
		"item kosong dilewati": {`{"results":[{"foo":"bar"},{"title":"  "},{"title":"Ada","url":"https://ada.id"}]}`,
			[]SearchSource{{"Ada", "https://ada.id", ""}}},
		"results kosong lalu data": {`{"results":[],"data":[{"title":"H2","url":"https://h2.id"}]}`,
			[]SearchSource{{"H2", "https://h2.id", ""}}},
		"bentuk tak dikenal":      {`{"hasil":"nihil"}`, []SearchSource{}},
		"skalar":                  {`"teks"`, []SearchSource{}},
		"terlalu dalam":           {`{"data":{"data":{"data":{"data":[{"title":"Dalam","url":"https://d.id"}]}}}}`, []SearchSource{}},
		"opensearch tak lengkap":  {`["q","bukan-array",[],[]]`, []SearchSource{}},
		"array pendek":            {`["q",["a"]]`, []SearchSource{}},
		"query tanpa search":      {`{"query":{"lain":1}}`, []SearchSource{}},
		"query search bukan list": {`{"query":{"search":"x"}}`, []SearchSource{}},
	}
	for name, tc := range cases {
		t.Run(name, func(t *testing.T) {
			var gotQuery string
			srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
				gotQuery = r.URL.Query().Get("q")
				_, _ = io.WriteString(w, tc.body)
			}))
			defer srv.Close()

			got, err := NewSearchClient(srv.URL+"/api/v1/search?lang=id", srv.Client()).Search(ctx, "danau toba & kaldera")
			require.NoError(t, err)
			assert.Equal(t, "danau toba & kaldera", gotQuery)
			assert.Equal(t, tc.want, got)
		})
	}
}

func TestSearchCleansAndLimits(t *testing.T) {
	var items []string
	for i := 1; i <= 8; i++ {
		items = append(items, fmt.Sprintf(`{"title":"<b>Judul %d</b>","url":"https://s%d.id","snippet":"  banyak   spasi\n<i>miring</i> &lt;ok&gt; "}`, i, i))
	}
	long := strings.Repeat("kata ", 100)
	items[0] = fmt.Sprintf(`{"title":"Panjang","url":"https://p.id","snippet":%q}`, long)
	srv := serve(t, 200, `{"results":[`+strings.Join(items, ",")+`]}`)

	got, err := NewSearchClient(srv.URL, nil).Search(ctx, "x")
	require.NoError(t, err)
	require.Len(t, got, maxSources)
	assert.Equal(t, maxSnippetRunes+1, len([]rune(got[0].Snippet)))
	assert.True(t, strings.HasSuffix(got[0].Snippet, "…"))
	assert.Equal(t, "Judul 2", got[1].Title)
	assert.Equal(t, "banyak spasi miring <ok>", got[1].Snippet)
}

func TestSearchErrors(t *testing.T) {
	_, err := NewSearchClient("  ", nil).Search(ctx, "x")
	assert.ErrorContains(t, err, "belum dikonfigurasi")

	_, err = NewSearchClient("http://[::1", nil).Search(ctx, "x")
	assert.ErrorContains(t, err, "tidak valid")

	_, err = NewSearchClient(closedURL(t), nil).Search(ctx, "x")
	assert.ErrorContains(t, err, "gagal menghubungi")

	_, err = NewSearchClient(serve(t, 500, `{}`).URL, nil).Search(ctx, "x")
	assert.ErrorContains(t, err, "status 500")

	_, err = NewSearchClient(serve(t, 200, `bukan json`).URL, nil).Search(ctx, "x")
	assert.ErrorContains(t, err, "bukan JSON valid")

	_, err = NewSearchClient(truncated(t).URL, nil).Search(ctx, "x")
	assert.ErrorContains(t, err, "gagal membaca")
}

func TestSearchTimeout(t *testing.T) {
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		time.Sleep(300 * time.Millisecond)
	}))
	defer srv.Close()
	c := NewSearchClient(srv.URL, &http.Client{Timeout: 50 * time.Millisecond})
	_, err := c.Search(ctx, "x")
	assert.ErrorContains(t, err, "gagal menghubungi")
}

// ---------- client OpenAI ----------

func chatBody(content string) string {
	b, _ := json.Marshal(map[string]any{"choices": []any{map[string]any{"message": map[string]any{"content": content}}}})
	return string(b)
}

const articleJSON = `{"title":" Judul AI ","category":"Teknologi","excerpt":" ringkas ","content":"## Isi\n\nTeks."}`

func TestCheckAccess(t *testing.T) {
	var path, auth string
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		path, auth = r.URL.Path, r.Header.Get("Authorization")
		_, _ = io.WriteString(w, `{"data":[]}`)
	}))
	defer srv.Close()

	require.NoError(t, NewOpenAIClient(srv.URL+"/v1/", "rahasia", "m", srv.Client()).CheckAccess(ctx))
	assert.Equal(t, "/v1/models", path)
	assert.Equal(t, "Bearer rahasia", auth)

	assert.ErrorContains(t, NewOpenAIClient(srv.URL, "  ", "m", nil).CheckAccess(ctx), "OPENAI_KEY")
	assert.ErrorContains(t, NewOpenAIClient("http://a b", "k", "m", nil).CheckAccess(ctx), "tidak valid")
	assert.ErrorContains(t, NewOpenAIClient(closedURL(t), "k", "m", nil).CheckAccess(ctx), "gagal menghubungi")
	assert.ErrorContains(t, NewOpenAIClient(serve(t, 401, `{}`).URL, "k", "m", nil).CheckAccess(ctx), "status 401")
}

func TestGenerateArticleSuccessAndRequestShape(t *testing.T) {
	var captured chatRequest
	var auth, contentType, path string
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		path, auth, contentType = r.URL.Path, r.Header.Get("Authorization"), r.Header.Get("Content-Type")
		_ = json.NewDecoder(r.Body).Decode(&captured)
		_, _ = io.WriteString(w, chatBody(articleJSON))
	}))
	defer srv.Close()

	c := NewOpenAIClient(srv.URL, "kunci", "model-x", srv.Client())
	article, err := c.GenerateArticle(ctx, "Danau Toba", "Umum", []SearchSource{{"Toba", "https://toba.id", "kaldera"}})
	require.NoError(t, err)
	assert.Equal(t, &GeneratedArticle{Title: "Judul AI", Category: "Teknologi", Excerpt: "ringkas", Content: "## Isi\n\nTeks."}, article)

	assert.Equal(t, "/chat/completions", path)
	assert.Equal(t, "Bearer kunci", auth)
	assert.Equal(t, "application/json", contentType)
	assert.Equal(t, "model-x", captured.Model)
	require.Len(t, captured.Messages, 2)
	assert.Contains(t, captured.Messages[0].Content, "JSON")
	assert.Contains(t, captured.Messages[0].Content, "## Referensi")
	assert.Contains(t, captured.Messages[1].Content, "Danau Toba")
	assert.Contains(t, captured.Messages[1].Content, "Kategori yang diinginkan: Umum")
	assert.Contains(t, captured.Messages[1].Content, "1. Toba (https://toba.id): kaldera")

	// Tanpa konteks web: prompt tidak meminta referensi dan tidak menyebut konteks.
	_, err = c.GenerateArticle(ctx, "Topik", "", nil)
	require.NoError(t, err)
	assert.NotContains(t, captured.Messages[0].Content, "## Referensi")
	assert.NotContains(t, captured.Messages[1].Content, "Konteks hasil penelusuran")
	assert.NotContains(t, captured.Messages[1].Content, "Kategori yang diinginkan")
}

func TestGenerateArticleToleratesWrappers(t *testing.T) {
	wrappers := map[string]string{
		"fence json": "```json\n" + articleJSON + "\n```",
		"fence":      "```\n" + articleJSON + "\n```",
		"pengantar":  "Tentu, ini artikelnya:\n" + articleJSON + "\nSemoga membantu!",
	}
	for name, content := range wrappers {
		srv := serve(t, 200, chatBody(content))
		article, err := NewOpenAIClient(srv.URL, "k", "m", nil).GenerateArticle(ctx, "t", "", nil)
		require.NoError(t, err, name)
		assert.Equal(t, "Judul AI", article.Title, name)
	}
}

func TestGenerateArticleErrors(t *testing.T) {
	gen := func(url string) error {
		_, err := NewOpenAIClient(url, "k", "m", nil).GenerateArticle(ctx, "t", "", nil)
		return err
	}
	assert.ErrorContains(t, gen("http://a b"), "tidak valid")
	assert.ErrorContains(t, gen(closedURL(t)), "gagal menghubungi")
	assert.ErrorContains(t, gen(truncated(t).URL), "gagal membaca")
	assert.ErrorContains(t, gen(serve(t, 429, `{}`).URL), "status 429")
	assert.ErrorContains(t, gen(serve(t, 200, `bukan json`).URL), "bukan JSON valid")
	assert.ErrorContains(t, gen(serve(t, 200, `{"choices":[]}`).URL), "kosong")
	assert.ErrorContains(t, gen(serve(t, 200, chatBody("   ")).URL), "kosong")
	assert.ErrorContains(t, gen(serve(t, 200, chatBody("tanpa kurung kurawal")).URL), "tidak berisi objek JSON")
	assert.ErrorContains(t, gen(serve(t, 200, chatBody("} terbalik {")).URL), "tidak berisi objek JSON")
	assert.ErrorContains(t, gen(serve(t, 200, chatBody(`{"title": "rusak",}`)).URL), "rusak")
	assert.ErrorContains(t, gen(serve(t, 200, chatBody(`{"title":"","content":"x"}`)).URL), "tidak lengkap")
	assert.ErrorContains(t, gen(serve(t, 200, chatBody(`{"title":"x","content":" "}`)).URL), "tidak lengkap")
}

func TestGenerateArticleMarshalError(t *testing.T) {
	old := jsonMarshal
	jsonMarshal = func(any) ([]byte, error) { return nil, errBoom }
	t.Cleanup(func() { jsonMarshal = old })
	_, err := NewOpenAIClient("http://x", "k", "m", nil).GenerateArticle(ctx, "t", "", nil)
	assert.ErrorIs(t, err, errBoom)
}

// ---------- service ----------

type stubChat struct {
	accessErr, genErr error
	article           *GeneratedArticle
	gotCategory       string
	gotSources        []SearchSource
}

func (s *stubChat) CheckAccess(context.Context) error { return s.accessErr }
func (s *stubChat) GenerateArticle(_ context.Context, _ string, category string, sources []SearchSource) (*GeneratedArticle, error) {
	s.gotCategory, s.gotSources = category, sources
	return s.article, s.genErr
}

type stubSearch struct {
	res    []SearchSource
	err    error
	mu     sync.Mutex
	called int
}

func (s *stubSearch) Search(context.Context, string) ([]SearchSource, error) {
	s.mu.Lock()
	defer s.mu.Unlock()
	s.called++
	return s.res, s.err
}

func okArticle() *GeneratedArticle {
	return &GeneratedArticle{Title: "T", Category: "bisnis", Excerpt: "E", Content: "C"}
}

func TestServiceValidation(t *testing.T) {
	svc := NewService(&stubChat{}, &stubSearch{})
	for _, topic := range []string{"", "   ", strings.Repeat("é", 301)} {
		_, err := svc.Generate(ctx, GenerateRequest{Topic: topic})
		var ve *ValidationError
		require.ErrorAs(t, err, &ve)
	}
	_, err := svc.Generate(ctx, GenerateRequest{Topic: ""})
	assert.EqualError(t, err, "Field topic wajib diisi")
	_, err = svc.Generate(ctx, GenerateRequest{Topic: strings.Repeat("a", 301)})
	assert.EqualError(t, err, "Field topic maksimal 300 karakter")
}

func TestServiceUpstreamErrors(t *testing.T) {
	var se *ServiceError

	_, err := NewService(&stubChat{accessErr: errBoom}, &stubSearch{}).Generate(ctx, GenerateRequest{Topic: "x"})
	require.ErrorAs(t, err, &se)
	assert.Equal(t, 500, se.Status)
	assert.ErrorIs(t, err, errBoom)
	assert.Equal(t, "Layanan OpenAI sedang tidak tersedia. Silakan coba lagi nanti.", se.Error())

	_, err = NewService(&stubChat{genErr: errBoom}, &stubSearch{}).Generate(ctx, GenerateRequest{Topic: "x"})
	require.ErrorAs(t, err, &se)
	assert.Equal(t, "Gagal menghasilkan artikel dengan OpenAI. Silakan coba lagi.", se.Error())
}

func TestServiceSearchFlow(t *testing.T) {
	src := []SearchSource{{"A", "https://a.id", "s"}}

	// Tanpa web search: search tidak dipanggil, sumber kosong (bukan null).
	chat, search := &stubChat{article: okArticle()}, &stubSearch{res: src}
	res, err := NewService(chat, search).Generate(ctx, GenerateRequest{Topic: " x "})
	require.NoError(t, err)
	assert.Zero(t, search.called)
	assert.NotNil(t, res.SearchSources)
	assert.Empty(t, res.SearchSources)
	b, _ := json.Marshal(res)
	assert.Contains(t, string(b), `"search_sources":[]`)

	// Dengan web search: sumber diteruskan ke OpenAI dan dikembalikan.
	chat, search = &stubChat{article: okArticle()}, &stubSearch{res: src}
	res, err = NewService(chat, search).Generate(ctx, GenerateRequest{Topic: "x", IncludeWebSearch: true})
	require.NoError(t, err)
	assert.Equal(t, 1, search.called)
	assert.Equal(t, src, chat.gotSources)
	assert.Equal(t, src, res.SearchSources)

	// Search gagal atau nil: request tetap sukses tanpa konteks web.
	for _, s := range []*stubSearch{{err: errBoom}, {res: nil}} {
		chat = &stubChat{article: okArticle()}
		res, err = NewService(chat, s).Generate(ctx, GenerateRequest{Topic: "x", IncludeWebSearch: true})
		require.NoError(t, err)
		assert.NotNil(t, res.SearchSources)
		assert.Empty(t, res.SearchSources)
		assert.Empty(t, chat.gotSources)
	}
}

func TestServiceCategoryNormalization(t *testing.T) {
	cases := []struct{ input, ai, want, sentToAI string }{
		{"", "bisnis", "Bisnis", ""},
		{"Opini", "Teknologi", "Teknologi", "Opini"},
		{"opini", "Ngawur", "Opini", "Opini"},
		{"Ngawur", "Ngawur", "Umum", ""},
		{"", "", "Umum", ""},
	}
	for _, tc := range cases {
		chat := &stubChat{article: &GeneratedArticle{Title: "T", Category: tc.ai, Content: "C"}}
		res, err := NewService(chat, &stubSearch{}).Generate(ctx, GenerateRequest{Topic: "x", Category: tc.input})
		require.NoError(t, err)
		assert.Equal(t, tc.want, res.Category, "%+v", tc)
		assert.Equal(t, tc.sentToAI, chat.gotCategory, "%+v", tc)
	}
}

// ---------- handler ----------

type stubService struct {
	res *GenerateResponse
	err error
}

func (s stubService) Generate(context.Context, GenerateRequest) (*GenerateResponse, error) {
	return s.res, s.err
}

func doPost(svc Service, body string) (int, map[string]any) {
	r := gin.New()
	r.POST("/ai", NewHandler(svc).Generate)
	req := httptest.NewRequest("POST", "/ai", bytes.NewBufferString(body))
	req.Header.Set("Content-Type", "application/json")
	w := httptest.NewRecorder()
	r.ServeHTTP(w, req)
	var out map[string]any
	_ = json.Unmarshal(w.Body.Bytes(), &out)
	return w.Code, out
}

func TestHandler(t *testing.T) {
	code, out := doPost(stubService{}, "{rusak")
	assert.Equal(t, 400, code)
	assert.Equal(t, "fail", out["status"])

	code, out = doPost(stubService{err: &ValidationError{"Topik wajib diisi"}}, `{}`)
	assert.Equal(t, 400, code)
	assert.Equal(t, "Topik wajib diisi", out["message"])

	code, out = doPost(stubService{err: &ServiceError{Status: 502, Message: "AI mati", Err: errBoom}}, `{"topic":"x"}`)
	assert.Equal(t, 502, code)
	assert.Equal(t, "error", out["status"])
	assert.Equal(t, "AI mati", out["message"])

	code, out = doPost(stubService{err: errBoom}, `{"topic":"x"}`)
	assert.Equal(t, 500, code)
	assert.Equal(t, "Terjadi kesalahan pada server", out["message"])

	code, out = doPost(stubService{res: &GenerateResponse{Title: "T", Category: "Umum", Content: "C", SearchSources: []SearchSource{}}}, `{"topic":"x"}`)
	assert.Equal(t, 200, code)
	data := out["data"].(map[string]any)
	assert.Equal(t, "T", data["title"])
	assert.Equal(t, []any{}, data["search_sources"])
}

func TestEndToEndWithMockServers(t *testing.T) {
	search := serve(t, 200, `{"results":[{"title":"Toba","url":"https://toba.id","snippet":"kaldera"}]}`)
	mux := http.NewServeMux()
	mux.HandleFunc("/models", func(w http.ResponseWriter, r *http.Request) { _, _ = io.WriteString(w, `{}`) })
	mux.HandleFunc("/chat/completions", func(w http.ResponseWriter, r *http.Request) {
		_, _ = io.WriteString(w, chatBody("```json\n"+articleJSON+"\n```"))
	})
	oa := httptest.NewServer(mux)
	defer oa.Close()

	svc := NewService(NewOpenAIClient(oa.URL, "k", "m", nil), NewSearchClient(search.URL, nil))
	code, out := doPost(svc, `{"topic":"Toba","category":"Opini","include_web_search":true}`)
	require.Equal(t, 200, code)
	data := out["data"].(map[string]any)
	assert.Equal(t, "Judul AI", data["title"])
	assert.Equal(t, "Teknologi", data["category"])
	assert.Len(t, data["search_sources"], 1)
}
'@

Write-Repo 'internal/features/ai/service.go' @'
package ai

import (
	"context"
	"strings"
	"unicode/utf8"

	"app/internal/features/post"
)

const (
	maxTopicRunes = 300
	// upstreamStatus adalah status HTTP bila OpenAI tidak dapat dipakai.
	upstreamStatus = 500
)

// ValidationError menandakan input tidak valid (HTTP 400).
type ValidationError struct{ Message string }

func (e *ValidationError) Error() string { return e.Message }

// ServiceError menandakan kegagalan layanan hulu (OpenAI) dengan pesan ramah pengguna.
type ServiceError struct {
	Status  int
	Message string
	Err     error
}

func (e *ServiceError) Error() string { return e.Message }
func (e *ServiceError) Unwrap() error { return e.Err }

// Service menyusun draf artikel dengan bantuan search engine dan OpenAI.
type Service interface {
	Generate(ctx context.Context, req GenerateRequest) (*GenerateResponse, error)
}

type service struct {
	chat   ChatClient
	search SearchClient
}

// NewService membuat Service.
func NewService(chat ChatClient, search SearchClient) Service {
	return &service{chat: chat, search: search}
}

func (s *service) Generate(ctx context.Context, req GenerateRequest) (*GenerateResponse, error) {
	topic := strings.TrimSpace(req.Topic)
	if topic == "" {
		return nil, &ValidationError{"Field topic wajib diisi"}
	}
	if utf8.RuneCountInString(topic) > maxTopicRunes {
		return nil, &ValidationError{"Field topic maksimal 300 karakter"}
	}
	// Kategori input hanyalah petunjuk; nilai yang tidak dikenal diabaikan.
	inputCategory, _ := post.NormalizeCategory(req.Category)

	if err := s.chat.CheckAccess(ctx); err != nil {
		return nil, &ServiceError{Status: upstreamStatus, Message: "Layanan OpenAI sedang tidak tersedia. Silakan coba lagi nanti.", Err: err}
	}

	// Kegagalan penelusuran web tidak menggagalkan request: lanjut tanpa konteks web.
	sources := []SearchSource{}
	if req.IncludeWebSearch {
		if found, err := s.search.Search(ctx, topic); err == nil && found != nil {
			sources = found
		}
	}

	article, err := s.chat.GenerateArticle(ctx, topic, inputCategory, sources)
	if err != nil {
		return nil, &ServiceError{Status: upstreamStatus, Message: "Gagal menghasilkan artikel dengan OpenAI. Silakan coba lagi.", Err: err}
	}

	category := post.DefaultCategory
	if normalized, ok := post.NormalizeCategory(article.Category); ok {
		category = normalized
	} else if inputCategory != "" {
		category = inputCategory
	}
	return &GenerateResponse{
		Title: article.Title, Category: category, Excerpt: article.Excerpt,
		Content: article.Content, SearchSources: sources,
	}, nil
}
'@

Write-Repo 'internal/features/auth/auth_test.go' @'
package auth

import (
	"bytes"
	"encoding/json"
	"errors"
	"fmt"
	"net/http/httptest"
	"strings"
	"testing"
	"time"

	"app/internal/database"
	"app/internal/middleware"

	"github.com/gin-gonic/gin"
	"github.com/golang-jwt/jwt/v5"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
	"golang.org/x/crypto/bcrypt"
	"gorm.io/gorm"
)

const testSecret = "kunci-uji"

var errBoom = errors.New("boom")

func init() { gin.SetMode(gin.TestMode) }

func newDB(t *testing.T) *gorm.DB {
	db, err := database.ConnectTest()
	require.NoError(t, err)
	return db
}

func newSvc(t *testing.T) (Service, Repository, *gorm.DB) {
	db := newDB(t)
	repo := NewRepository(db)
	return NewService(repo, testSecret), repo, db
}

func mustRegister(t *testing.T, svc Service, username, email, password string) *UserResponse {
	res, err := svc.Register(RegisterRequest{Username: username, Email: email, Password: password})
	require.NoError(t, err)
	return &res.User
}

// flakyRepo membungkus Repository nyata dan gagal pada method tertentu.
type flakyRepo struct {
	Repository
	failOn map[string]bool
}

func (r *flakyRepo) FindByID(id uint) (*database.User, error) {
	if r.failOn["FindByID"] {
		return nil, errBoom
	}
	return r.Repository.FindByID(id)
}
func (r *flakyRepo) FindByUsername(u string) (*database.User, error) {
	if r.failOn["FindByUsername"] {
		return nil, errBoom
	}
	return r.Repository.FindByUsername(u)
}
func (r *flakyRepo) FindByEmail(e string) (*database.User, error) {
	if r.failOn["FindByEmail"] {
		return nil, errBoom
	}
	return r.Repository.FindByEmail(e)
}
func (r *flakyRepo) ExistsByUsername(u string, id uint) (bool, error) {
	if r.failOn["ExistsByUsername"] {
		return false, errBoom
	}
	return r.Repository.ExistsByUsername(u, id)
}
func (r *flakyRepo) ExistsByEmail(e string, id uint) (bool, error) {
	if r.failOn["ExistsByEmail"] {
		return false, errBoom
	}
	return r.Repository.ExistsByEmail(e, id)
}
func (r *flakyRepo) Create(u *database.User) error {
	if r.failOn["Create"] {
		return errBoom
	}
	return r.Repository.Create(u)
}
func (r *flakyRepo) Update(u *database.User) error {
	if r.failOn["Update"] {
		return errBoom
	}
	return r.Repository.Update(u)
}

func flaky(t *testing.T, fail ...string) Service {
	_, repo, _ := newSvc(t)
	m := map[string]bool{}
	for _, f := range fail {
		m[f] = true
	}
	return NewService(&flakyRepo{Repository: repo, failOn: m}, testSecret)
}

func TestRepository(t *testing.T) {
	_, repo, db := newSvc(t)
	u := &database.User{Username: "Budi", Email: "budi@x.id", Password: "h", Role: "member"}
	require.NoError(t, repo.Create(u))

	byID, err := repo.FindByID(u.ID)
	require.NoError(t, err)
	assert.Equal(t, "Budi", byID.Username)
	byName, err := repo.FindByUsername("budi")
	require.NoError(t, err)
	assert.Equal(t, u.ID, byName.ID)
	byMail, err := repo.FindByEmail("BUDI@x.id")
	require.NoError(t, err)
	assert.Equal(t, u.ID, byMail.ID)

	_, err = repo.FindByID(999)
	assert.ErrorIs(t, err, ErrUserNotFound)

	taken, err := repo.ExistsByUsername("BUDI", 0)
	require.NoError(t, err)
	assert.True(t, taken)
	taken, err = repo.ExistsByUsername("budi", u.ID)
	require.NoError(t, err)
	assert.False(t, taken)
	taken, err = repo.ExistsByEmail("budi@x.id", 0)
	require.NoError(t, err)
	assert.True(t, taken)

	u.Username = "Budi2"
	require.NoError(t, repo.Update(u))
	byID, _ = repo.FindByID(u.ID)
	assert.Equal(t, "Budi2", byID.Username)

	require.NoError(t, db.Migrator().DropTable(&database.Post{}, &database.User{}))
	_, err = repo.FindByID(1)
	assert.Error(t, err)
	assert.NotErrorIs(t, err, ErrUserNotFound)
	_, err = repo.ExistsByUsername("x", 0)
	assert.Error(t, err)
}

func TestRegister(t *testing.T) {
	svc, _, db := newSvc(t)
	res, err := svc.Register(RegisterRequest{Username: "  Siti  ", Email: " Siti@Contoh.ID ", Password: "rahasia1"})
	require.NoError(t, err)
	u := res.User
	assert.Equal(t, 3, len(strings.Split(res.Token, ".")), "register mengembalikan token JWT")
	assert.Equal(t, "Siti", u.Username)
	assert.Equal(t, "siti@contoh.id", u.Email)
	assert.Equal(t, "member", u.Role)

	var stored database.User
	require.NoError(t, db.First(&stored, u.ID).Error)
	assert.NotEqual(t, "rahasia1", stored.Password)
	assert.NoError(t, bcrypt.CompareHashAndPassword([]byte(stored.Password), []byte("rahasia1")))
}

func TestRegisterRole(t *testing.T) {
	svc, _, _ := newSvc(t)
	cases := []struct{ in, want string }{
		{"admin", "admin"}, {" ADMIN ", "admin"}, {"member", "member"}, {"superuser", "member"}, {"", "member"},
	}
	for i, tc := range cases {
		res, err := svc.Register(RegisterRequest{
			Username: fmt.Sprintf("user%d", i), Email: fmt.Sprintf("user%d@x.id", i), Password: "123456", Role: tc.in,
		})
		require.NoError(t, err)
		assert.Equal(t, tc.want, res.User.Role, "role=%q", tc.in)

		claims := &middleware.Claims{}
		_, err = jwt.ParseWithClaims(res.Token, claims, func(*jwt.Token) (any, error) { return []byte(testSecret), nil })
		require.NoError(t, err)
		assert.Equal(t, tc.want, claims.Role)
	}
}

func TestRegisterValidation(t *testing.T) {
	svc, _, _ := newSvc(t)
	long := strings.Repeat("a", 251) + "@x.id"
	cases := []struct {
		name string
		req  RegisterRequest
		msg  string
	}{
		{"username kosong", RegisterRequest{Username: "", Email: "a@b.id", Password: "123456"}, "Username wajib diisi"},
		{"username pendek", RegisterRequest{Username: "ab", Email: "a@b.id", Password: "123456"}, "Username harus 3-50 karakter"},
		{"username panjang", RegisterRequest{Username: strings.Repeat("a", 51), Email: "a@b.id", Password: "123456"}, "Username harus 3-50 karakter"},
		{"username simbol", RegisterRequest{Username: "bud i", Email: "a@b.id", Password: "123456"}, "Username hanya boleh berisi huruf, angka, titik, garis bawah, dan strip"},
		{"email kosong", RegisterRequest{Username: "budi", Email: "  ", Password: "123456"}, "Email wajib diisi"},
		{"email salah", RegisterRequest{Username: "budi", Email: "bukan-email", Password: "123456"}, "Format email tidak valid"},
		{"email panjang", RegisterRequest{Username: "budi", Email: long, Password: "123456"}, "Format email tidak valid"},
		{"password pendek", RegisterRequest{Username: "budi", Email: "a@b.id", Password: "12345"}, "Password minimal 6 karakter"},
		{"password terlalu panjang", RegisterRequest{Username: "budi", Email: "a@b.id", Password: strings.Repeat("x", 73)}, "Password maksimal 72 byte"},
	}
	for _, tc := range cases {
		t.Run(tc.name, func(t *testing.T) {
			_, err := svc.Register(tc.req)
			var ve *ValidationError
			require.ErrorAs(t, err, &ve)
			assert.Equal(t, tc.msg, ve.Error())
		})
	}
}

func TestRegisterConflictsAndErrors(t *testing.T) {
	svc, _, _ := newSvc(t)
	mustRegister(t, svc, "budi", "budi@x.id", "123456")

	var ce *ConflictError
	_, err := svc.Register(RegisterRequest{Username: "BUDI", Email: "lain@x.id", Password: "123456"})
	require.ErrorAs(t, err, &ce)
	assert.Equal(t, "Username sudah digunakan", ce.Error())
	_, err = svc.Register(RegisterRequest{Username: "lain", Email: "budi@x.id", Password: "123456"})
	require.ErrorAs(t, err, &ce)
	assert.Equal(t, "Email sudah terdaftar", ce.Error())

	ok := RegisterRequest{Username: "baru", Email: "baru@x.id", Password: "123456"}
	for _, f := range []string{"ExistsByUsername", "ExistsByEmail", "Create"} {
		_, err = flaky(t, f).Register(ok)
		assert.ErrorIs(t, err, errBoom, f)
	}

	old := hashPassword
	hashPassword = func([]byte, int) ([]byte, error) { return nil, errBoom }
	t.Cleanup(func() { hashPassword = old })
	_, err = svc.Register(ok)
	assert.ErrorIs(t, err, errBoom)
}

func TestLogin(t *testing.T) {
	svc, _, _ := newSvc(t)
	u := mustRegister(t, svc, "budi", "budi@x.id", "123456")

	for _, id := range []string{"budi", "BUDI", "budi@x.id", "  budi@X.id "} {
		res, err := svc.Login(LoginRequest{Username: id, Password: "123456"})
		require.NoError(t, err, id)
		assert.Equal(t, u.ID, res.User.ID)

		claims := &middleware.Claims{}
		tok, err := jwt.ParseWithClaims(res.Token, claims, func(*jwt.Token) (any, error) { return []byte(testSecret), nil })
		require.NoError(t, err)
		assert.True(t, tok.Valid)
		assert.Equal(t, u.ID, claims.UserID)
		assert.Equal(t, "budi", claims.Username)
		assert.Equal(t, "member", claims.Role)
		assert.WithinDuration(t, time.Now().Add(24*time.Hour), claims.ExpiresAt.Time, time.Minute)
	}
}

func TestLoginFailures(t *testing.T) {
	svc, _, _ := newSvc(t)
	mustRegister(t, svc, "budi", "budi@x.id", "123456")

	var ve *ValidationError
	_, err := svc.Login(LoginRequest{Username: " ", Password: "x"})
	require.ErrorAs(t, err, &ve)
	_, err = svc.Login(LoginRequest{Username: "budi", Password: ""})
	require.ErrorAs(t, err, &ve)

	_, errUnknown := svc.Login(LoginRequest{Username: "tidakada", Password: "123456"})
	_, errWrong := svc.Login(LoginRequest{Username: "budi", Password: "salahsalah"})
	assert.ErrorIs(t, errUnknown, InvalidCredentialsError{})
	assert.ErrorIs(t, errWrong, InvalidCredentialsError{})
	assert.Equal(t, errUnknown.Error(), errWrong.Error())

	_, err = flaky(t, "FindByUsername").Login(LoginRequest{Username: "budi", Password: "123456"})
	assert.ErrorIs(t, err, errBoom)
	_, err = flaky(t, "FindByEmail").Login(LoginRequest{Username: "a@b.id", Password: "123456"})
	assert.ErrorIs(t, err, errBoom)

	old := signToken
	signToken = func(jwt.Claims, []byte) (string, error) { return "", errBoom }
	t.Cleanup(func() { signToken = old })
	_, err = svc.Login(LoginRequest{Username: "budi", Password: "123456"})
	assert.ErrorIs(t, err, errBoom)
}

func TestGetProfile(t *testing.T) {
	svc, _, _ := newSvc(t)
	u := mustRegister(t, svc, "budi", "budi@x.id", "123456")
	got, err := svc.GetProfile(u.ID)
	require.NoError(t, err)
	assert.Equal(t, "budi", got.Username)
	_, err = svc.GetProfile(999)
	assert.ErrorIs(t, err, ErrUserNotFound)
}

func TestUpdateProfile(t *testing.T) {
	svc, _, db := newSvc(t)
	u := mustRegister(t, svc, "budi", "budi@x.id", "123456")
	mustRegister(t, svc, "siti", "siti@x.id", "123456")

	// Hanya email; email milik sendiri tidak dianggap bentrok, username tidak berubah.
	got, err := svc.UpdateProfile(u.ID, UpdateProfileRequest{Email: " Baru@X.id "})
	require.NoError(t, err)
	assert.Equal(t, "baru@x.id", got.Email)
	assert.Equal(t, "budi", got.Username)
	got, err = svc.UpdateProfile(u.ID, UpdateProfileRequest{Email: "baru@x.id"})
	require.NoError(t, err)
	assert.Equal(t, "baru@x.id", got.Email)

	// Mengganti password.
	_, err = svc.UpdateProfile(u.ID, UpdateProfileRequest{Email: "baru@x.id", Password: "passwordbaru"})
	require.NoError(t, err)
	var stored database.User
	require.NoError(t, db.First(&stored, u.ID).Error)
	assert.Equal(t, "budi", stored.Username)
	assert.NoError(t, bcrypt.CompareHashAndPassword([]byte(stored.Password), []byte("passwordbaru")))

	var ve *ValidationError
	var ce *ConflictError
	_, err = svc.UpdateProfile(u.ID, UpdateProfileRequest{Email: ""})
	require.ErrorAs(t, err, &ve)
	_, err = svc.UpdateProfile(u.ID, UpdateProfileRequest{Email: "bukan-email"})
	require.ErrorAs(t, err, &ve)
	_, err = svc.UpdateProfile(u.ID, UpdateProfileRequest{Email: "baru@x.id", Password: "123"})
	require.ErrorAs(t, err, &ve)
	_, err = svc.UpdateProfile(u.ID, UpdateProfileRequest{Email: "siti@x.id"})
	require.ErrorAs(t, err, &ce)
	_, err = svc.UpdateProfile(999, UpdateProfileRequest{Email: "a@b.id"})
	assert.ErrorIs(t, err, ErrUserNotFound)

	req := UpdateProfileRequest{Email: "b3@x.id", Password: "passwordbaru"}
	for _, f := range []string{"FindByID", "ExistsByEmail", "Update"} {
		base, repo, _ := newSvc(t)
		owner := mustRegister(t, base, "pemilik", "pemilik@x.id", "123456")
		failing := NewService(&flakyRepo{Repository: repo, failOn: map[string]bool{f: true}}, testSecret)
		_, err = failing.UpdateProfile(owner.ID, req)
		assert.ErrorIs(t, err, errBoom, f)
	}

	old := hashPassword
	hashPassword = func([]byte, int) ([]byte, error) { return nil, errBoom }
	t.Cleanup(func() { hashPassword = old })
	_, err = svc.UpdateProfile(u.ID, req)
	assert.ErrorIs(t, err, errBoom)
}

// ---------- Handler ----------

func newRouter(t *testing.T) (*gin.Engine, Service) {
	svc, _, _ := newSvc(t)
	h := NewHandler(svc)
	r := gin.New()
	r.POST("/register", h.Register)
	r.POST("/login", h.Login)
	secured := r.Group("/", middleware.Auth(testSecret))
	secured.POST("/logout", h.Logout)
	secured.GET("/profile", h.GetProfile)
	secured.PUT("/profile", h.UpdateProfile)
	return r, svc
}

func call(r *gin.Engine, method, path, token string, body any) (int, map[string]any) {
	var buf bytes.Buffer
	switch b := body.(type) {
	case string:
		buf.WriteString(b)
	case nil:
	default:
		_ = json.NewEncoder(&buf).Encode(b)
	}
	req := httptest.NewRequest(method, path, &buf)
	req.Header.Set("Content-Type", "application/json")
	if token != "" {
		req.Header.Set("Authorization", "Bearer "+token)
	}
	w := httptest.NewRecorder()
	r.ServeHTTP(w, req)
	var out map[string]any
	_ = json.Unmarshal(w.Body.Bytes(), &out)
	return w.Code, out
}

func TestHandlerFlow(t *testing.T) {
	r, _ := newRouter(t)

	code, body := call(r, "POST", "/register", "", gin.H{"username": "budi", "email": "budi@x.id", "password": "123456", "role": "admin"})
	assert.Equal(t, 201, code)
	data := body["data"].(map[string]any)
	assert.NotEmpty(t, data["token"], "register mengembalikan token")
	user := data["user"].(map[string]any)
	assert.Equal(t, "admin", user["role"], "role admin diterima")
	assert.NotContains(t, user, "password")

	code, body = call(r, "POST", "/register", "", gin.H{"username": "ucok", "email": "ucok@x.id", "password": "123456", "role": "superuser"})
	assert.Equal(t, 201, code)
	assert.Equal(t, "member", body["data"].(map[string]any)["user"].(map[string]any)["role"], "role tak dikenal menjadi member")

	code, body = call(r, "POST", "/register", "", gin.H{"username": "budi", "email": "lain@x.id", "password": "123456"})
	assert.Equal(t, 400, code)
	assert.Equal(t, "fail", body["status"])
	code, _ = call(r, "POST", "/register", "", "{bukan json")
	assert.Equal(t, 400, code)
	code, _ = call(r, "POST", "/register", "", gin.H{"username": "x"})
	assert.Equal(t, 400, code)

	code, _ = call(r, "POST", "/login", "", "{bukan json")
	assert.Equal(t, 400, code)
	code, body = call(r, "POST", "/login", "", gin.H{"username": "budi", "password": "salah"})
	assert.Equal(t, 401, code)
	assert.Equal(t, "Username/email atau password salah", body["message"])

	code, body = call(r, "POST", "/login", "", gin.H{"username": "budi@x.id", "password": "123456"})
	require.Equal(t, 200, code)
	token := body["data"].(map[string]any)["token"].(string)
	assert.NotEmpty(t, token)

	code, _ = call(r, "POST", "/logout", token, nil)
	assert.Equal(t, 200, code)
	code, _ = call(r, "POST", "/logout", "", nil)
	assert.Equal(t, 401, code)

	code, body = call(r, "GET", "/profile", token, nil)
	assert.Equal(t, 200, code)
	assert.Equal(t, "budi", body["data"].(map[string]any)["username"])

	code, body = call(r, "PUT", "/profile", token, gin.H{"email": "ganti@x.id", "password": "passwordbaru"})
	assert.Equal(t, 200, code)
	assert.Equal(t, "ganti@x.id", body["data"].(map[string]any)["email"])
	code, _ = call(r, "PUT", "/profile", token, gin.H{"email": "bukan-email"})
	assert.Equal(t, 400, code)
	code, _ = call(r, "PUT", "/profile", token, "{rusak")
	assert.Equal(t, 400, code)

	_, _ = call(r, "POST", "/register", "", gin.H{"username": "siti", "email": "siti@x.id", "password": "123456"})
	code, _ = call(r, "PUT", "/profile", token, gin.H{"email": "siti@x.id"})
	assert.Equal(t, 400, code)
}

func TestHandlerSessionAndServerErrors(t *testing.T) {
	r, _ := newRouter(t)
	// Token sah untuk pengguna yang tidak ada → 401.
	claims := &middleware.Claims{UserID: 4242, Username: "hantu", Role: "member",
		RegisteredClaims: jwt.RegisteredClaims{ExpiresAt: jwt.NewNumericDate(time.Now().Add(time.Hour))}}
	tok, err := jwt.NewWithClaims(jwt.SigningMethodHS256, claims).SignedString([]byte(testSecret))
	require.NoError(t, err)
	code, _ := call(r, "GET", "/profile", tok, nil)
	assert.Equal(t, 401, code)

	// Kegagalan internal → 500 tanpa membocorkan detail.
	svc, _, db := newSvc(t)
	h := NewHandler(svc)
	r2 := gin.New()
	r2.POST("/login", h.Login)
	require.NoError(t, db.Migrator().DropTable(&database.Post{}, &database.User{}))
	code, body := call(r2, "POST", "/login", "", gin.H{"username": "budi", "password": "123456"})
	assert.Equal(t, 500, code)
	assert.Equal(t, "error", body["status"])
	assert.Equal(t, "Terjadi kesalahan pada server", body["message"])
}
'@

Write-Repo 'internal/features/auth/dto.go' @'
package auth

import (
	"time"

	"app/internal/database"
)

// RegisterRequest adalah payload pendaftaran. Field role bersifat opsional:
// hanya "admin" atau "member" yang diterima, nilai lain dipaksa menjadi "member".
type RegisterRequest struct {
	Username string `json:"username"`
	Email    string `json:"email"`
	Password string `json:"password"`
	Role     string `json:"role"`
}

// LoginRequest menerima username ATAU email pada field username.
type LoginRequest struct {
	Username string `json:"username"`
	Password string `json:"password"`
}

// UpdateProfileRequest adalah payload pembaruan profil: hanya email dan password
// (opsional). Username tidak dapat diubah.
type UpdateProfileRequest struct {
	Email    string `json:"email"`
	Password string `json:"password"`
}

// UserResponse adalah representasi pengguna yang aman (tanpa hash password).
type UserResponse struct {
	ID        uint      `json:"id"`
	Username  string    `json:"username"`
	Email     string    `json:"email"`
	Role      string    `json:"role"`
	CreatedAt time.Time `json:"created_at"`
}

// LoginResponse berisi token JWT beserta data pengguna.
type LoginResponse struct {
	Token string       `json:"token"`
	User  UserResponse `json:"user"`
}

// ToUserResponse memetakan model ke DTO.
func ToUserResponse(u *database.User) UserResponse {
	return UserResponse{ID: u.ID, Username: u.Username, Email: u.Email, Role: u.Role, CreatedAt: u.CreatedAt}
}
'@

Write-Repo 'internal/features/auth/handler.go' @'
package auth

import (
	"errors"
	"log"
	"net/http"

	"app/internal/middleware"
	"app/internal/response"

	"github.com/gin-gonic/gin"
)

// Handler menangani endpoint /api/auth/*.
type Handler struct{ svc Service }

// NewHandler membuat Handler.
func NewHandler(svc Service) *Handler { return &Handler{svc: svc} }

func handleError(c *gin.Context, err error) {
	var validation *ValidationError
	var conflict *ConflictError
	var invalid InvalidCredentialsError
	switch {
	case errors.As(err, &validation):
		response.Fail(c, http.StatusBadRequest, validation.Message)
	case errors.As(err, &conflict):
		response.Fail(c, http.StatusBadRequest, conflict.Message)
	case errors.As(err, &invalid):
		response.Fail(c, http.StatusUnauthorized, invalid.Error())
	case errors.Is(err, ErrUserNotFound):
		response.Fail(c, http.StatusUnauthorized, "Sesi tidak valid: pengguna tidak ditemukan")
	default:
		log.Printf("auth: kesalahan internal: %v", err)
		response.Error(c, http.StatusInternalServerError, "Terjadi kesalahan pada server")
	}
}

// Register godoc: POST /api/auth/register. Mengembalikan token JWT beserta profil pengguna.
func (h *Handler) Register(c *gin.Context) {
	var req RegisterRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		response.Fail(c, http.StatusBadRequest, "Format permintaan tidak valid")
		return
	}
	res, err := h.svc.Register(req)
	if err != nil {
		handleError(c, err)
		return
	}
	response.Success(c, http.StatusCreated, "Registrasi berhasil", res)
}

// Login godoc: POST /api/auth/login
func (h *Handler) Login(c *gin.Context) {
	var req LoginRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		response.Fail(c, http.StatusBadRequest, "Format permintaan tidak valid")
		return
	}
	res, err := h.svc.Login(req)
	if err != nil {
		handleError(c, err)
		return
	}
	response.Success(c, http.StatusOK, "Login berhasil", res)
}

// Logout godoc: POST /api/auth/logout. JWT bersifat stateless: klien menghapus tokennya.
func (h *Handler) Logout(c *gin.Context) {
	response.Success(c, http.StatusOK, "Logout berhasil")
}

// GetProfile godoc: GET /api/auth/profile
func (h *Handler) GetProfile(c *gin.Context) {
	user, err := h.svc.GetProfile(c.GetUint(middleware.CtxUserID))
	if err != nil {
		handleError(c, err)
		return
	}
	response.Success(c, http.StatusOK, "Profil berhasil diambil", user)
}

// UpdateProfile godoc: PUT /api/auth/profile
func (h *Handler) UpdateProfile(c *gin.Context) {
	var req UpdateProfileRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		response.Fail(c, http.StatusBadRequest, "Format permintaan tidak valid")
		return
	}
	user, err := h.svc.UpdateProfile(c.GetUint(middleware.CtxUserID), req)
	if err != nil {
		handleError(c, err)
		return
	}
	response.Success(c, http.StatusOK, "Profil berhasil diperbarui", user)
}
'@

Write-Repo 'internal/features/auth/service.go' @'
package auth

import (
	"errors"
	"regexp"
	"strings"
	"time"
	"unicode/utf8"

	"app/internal/database"
	"app/internal/middleware"

	"github.com/golang-jwt/jwt/v5"
	"golang.org/x/crypto/bcrypt"
)

// ValidationError menandakan input tidak valid (HTTP 400).
type ValidationError struct{ Message string }

func (e *ValidationError) Error() string { return e.Message }

// ConflictError menandakan data sudah dipakai (HTTP 409).
type ConflictError struct{ Message string }

func (e *ConflictError) Error() string { return e.Message }

// InvalidCredentialsError menandakan login gagal (HTTP 401). Pesannya sengaja
// tidak membedakan "pengguna tidak ada" dan "password salah".
type InvalidCredentialsError struct{}

func (InvalidCredentialsError) Error() string { return "Username/email atau password salah" }

// tokenTTL adalah masa berlaku JWT.
const tokenTTL = 24 * time.Hour

// Dapat diganti saat pengujian untuk menjangkau cabang error.
var (
	hashPassword = bcrypt.GenerateFromPassword
	signToken    = func(claims jwt.Claims, secret []byte) (string, error) {
		return jwt.NewWithClaims(jwt.SigningMethodHS256, claims).SignedString(secret)
	}
	nowFunc = time.Now
)

var (
	usernameRe = regexp.MustCompile(`^[A-Za-z0-9_.-]+$`)
	emailRe    = regexp.MustCompile(`^[^@\s]+@[^@\s]+\.[^@\s]+$`)
)

// Service memuat logika bisnis autentikasi.
type Service interface {
	Register(req RegisterRequest) (*LoginResponse, error)
	Login(req LoginRequest) (*LoginResponse, error)
	GetProfile(userID uint) (*UserResponse, error)
	UpdateProfile(userID uint, req UpdateProfileRequest) (*UserResponse, error)
}

type service struct {
	repo   Repository
	secret string
}

// NewService membuat Service dengan kunci penandatangan JWT.
func NewService(repo Repository, secret string) Service {
	return &service{repo: repo, secret: secret}
}

func validateIdentity(username, email string) (string, string, error) {
	username = strings.TrimSpace(username)

	if username == "" {
		return "", "", &ValidationError{"Username wajib diisi"}
	}
	if n := utf8.RuneCountInString(username); n < 3 || n > 50 {
		return "", "", &ValidationError{"Username harus 3-50 karakter"}
	}
	if !usernameRe.MatchString(username) {
		return "", "", &ValidationError{"Username hanya boleh berisi huruf, angka, titik, garis bawah, dan strip"}
	}
	email, err := validateEmail(email)
	if err != nil {
		return "", "", err
	}
	return username, email, nil
}

func validateEmail(email string) (string, error) {
	email = strings.ToLower(strings.TrimSpace(email))
	if email == "" {
		return "", &ValidationError{"Email wajib diisi"}
	}
	if len(email) > 255 || !emailRe.MatchString(email) {
		return "", &ValidationError{"Format email tidak valid"}
	}
	return email, nil
}

// normalizeRole hanya menerima "admin"; nilai lain (termasuk kosong) menjadi "member".
func normalizeRole(role string) string {
	if strings.EqualFold(strings.TrimSpace(role), database.RoleAdmin) {
		return database.RoleAdmin
	}
	return database.RoleMember
}

func validatePassword(password string) error {
	if utf8.RuneCountInString(password) < 6 {
		return &ValidationError{"Password minimal 6 karakter"}
	}
	if len(password) > 72 {
		return &ValidationError{"Password maksimal 72 byte"}
	}
	return nil
}

func (s *service) ensureUnique(username, email string, excludeID uint) error {
	taken, err := s.repo.ExistsByUsername(username, excludeID)
	if err != nil {
		return err
	}
	if taken {
		return &ConflictError{"Username sudah digunakan"}
	}
	return s.ensureEmailFree(email, excludeID)
}

func (s *service) ensureEmailFree(email string, excludeID uint) error {
	taken, err := s.repo.ExistsByEmail(email, excludeID)
	if err != nil {
		return err
	}
	if taken {
		return &ConflictError{"Email sudah terdaftar"}
	}
	return nil
}

func (s *service) Register(req RegisterRequest) (*LoginResponse, error) {
	username, email, err := validateIdentity(req.Username, req.Email)
	if err != nil {
		return nil, err
	}
	if err := validatePassword(req.Password); err != nil {
		return nil, err
	}
	if err := s.ensureUnique(username, email, 0); err != nil {
		return nil, err
	}
	hash, err := hashPassword([]byte(req.Password), bcrypt.DefaultCost)
	if err != nil {
		return nil, err
	}

	user := &database.User{Username: username, Email: email, Password: string(hash), Role: normalizeRole(req.Role)}
	if err := s.repo.Create(user); err != nil {
		return nil, err
	}
	return s.issueToken(user)
}

func (s *service) Login(req LoginRequest) (*LoginResponse, error) {
	identifier := strings.TrimSpace(req.Username)
	if identifier == "" || req.Password == "" {
		return nil, &ValidationError{"Username/email dan password wajib diisi"}
	}

	find := s.repo.FindByUsername
	if strings.Contains(identifier, "@") {
		find = s.repo.FindByEmail
	}
	user, err := find(identifier)
	if errors.Is(err, ErrUserNotFound) {
		return nil, InvalidCredentialsError{}
	}
	if err != nil {
		return nil, err
	}
	if bcrypt.CompareHashAndPassword([]byte(user.Password), []byte(req.Password)) != nil {
		return nil, InvalidCredentialsError{}
	}

	return s.issueToken(user)
}

// issueToken menandatangani JWT untuk pengguna dan membungkusnya bersama profilnya.
func (s *service) issueToken(user *database.User) (*LoginResponse, error) {
	claims := &middleware.Claims{
		UserID: user.ID, Username: user.Username, Role: user.Role,
		RegisteredClaims: jwt.RegisteredClaims{
			ExpiresAt: jwt.NewNumericDate(nowFunc().Add(tokenTTL)),
			IssuedAt:  jwt.NewNumericDate(nowFunc()),
		},
	}
	token, err := signToken(claims, []byte(s.secret))
	if err != nil {
		return nil, err
	}
	return &LoginResponse{Token: token, User: ToUserResponse(user)}, nil
}

func (s *service) GetProfile(userID uint) (*UserResponse, error) {
	user, err := s.repo.FindByID(userID)
	if err != nil {
		return nil, err
	}
	res := ToUserResponse(user)
	return &res, nil
}

func (s *service) UpdateProfile(userID uint, req UpdateProfileRequest) (*UserResponse, error) {
	user, err := s.repo.FindByID(userID)
	if err != nil {
		return nil, err
	}
	email, err := validateEmail(req.Email)
	if err != nil {
		return nil, err
	}
	if req.Password != "" {
		if err := validatePassword(req.Password); err != nil {
			return nil, err
		}
	}
	if err := s.ensureEmailFree(email, userID); err != nil {
		return nil, err
	}

	user.Email = email
	if req.Password != "" {
		hash, err := hashPassword([]byte(req.Password), bcrypt.DefaultCost)
		if err != nil {
			return nil, err
		}
		user.Password = string(hash)
	}
	if err := s.repo.Update(user); err != nil {
		return nil, err
	}
	res := ToUserResponse(user)
	return &res, nil
}
'@

Write-Repo 'internal/features/post/dto.go' @'
package post

import (
	"strings"
	"time"

	"app/internal/database"
)

// DefaultCategory dipakai bila kategori kosong.
const DefaultCategory = "Umum"

var categories = []string{"Teknologi", "Pendidikan", "Gaya Hidup", "Bisnis", "Opini", "Umum"}

// Categories mengembalikan salinan daftar kategori yang sah.
func Categories() []string { return append([]string(nil), categories...) }

// NormalizeCategory mencocokkan input (tanpa membedakan huruf besar/kecil) ke kategori
// kanonik. Hasil kedua false bila input tidak cocok dengan kategori mana pun.
func NormalizeCategory(raw string) (string, bool) {
	raw = strings.TrimSpace(raw)
	for _, c := range categories {
		if strings.EqualFold(c, raw) {
			return c, true
		}
	}
	return "", false
}

// PostRequest adalah payload pembuatan/pembaruan artikel. IsPublished bersifat opsional.
type PostRequest struct {
	Title          string `json:"title"`
	Category       string `json:"category"`
	Excerpt        string `json:"excerpt"`
	Content        string `json:"content"`
	CoverImagePath string `json:"cover_image_path"`
	IsPublished    *bool  `json:"is_published"`
}

// AuthorResponse adalah data ringkas penulis (tanpa email).
type AuthorResponse struct {
	ID       uint   `json:"id"`
	Username string `json:"username"`
}

// PostResponse adalah representasi artikel pada seluruh respons.
type PostResponse struct {
	ID             uint            `json:"id"`
	UserID         uint            `json:"user_id"`
	Title          string          `json:"title"`
	Slug           string          `json:"slug"`
	Category       string          `json:"category"`
	Excerpt        string          `json:"excerpt"`
	Content        string          `json:"content"`
	CoverImagePath string          `json:"cover_image_path"`
	IsPublished    bool            `json:"is_published"`
	PublishedAt    *time.Time      `json:"published_at"`
	ReadingTime    int             `json:"reading_time"`
	Author         *AuthorResponse `json:"author,omitempty"`
	CreatedAt      time.Time       `json:"created_at"`
	UpdatedAt      time.Time       `json:"updated_at"`
}

// PublicPostResponse adalah representasi artikel untuk endpoint publik: tanpa
// user_id maupun data internal lain; penulis hanya berupa author_name.
type PublicPostResponse struct {
	ID             uint       `json:"id"`
	Title          string     `json:"title"`
	Slug           string     `json:"slug"`
	Category       string     `json:"category"`
	Excerpt        string     `json:"excerpt"`
	Content        string     `json:"content"`
	CoverImagePath string     `json:"cover_image_path"`
	IsPublished    bool       `json:"is_published"`
	PublishedAt    *time.Time `json:"published_at"`
	ReadingTime    int        `json:"reading_time"`
	AuthorName     string     `json:"author_name"`
	CreatedAt      time.Time  `json:"created_at"`
	UpdatedAt      time.Time  `json:"updated_at"`
}

// ToPublicResponse memetakan PostResponse ke bentuk publik.
func ToPublicResponse(p PostResponse) PublicPostResponse {
	res := PublicPostResponse{
		ID: p.ID, Title: p.Title, Slug: p.Slug, Category: p.Category, Excerpt: p.Excerpt,
		Content: p.Content, CoverImagePath: p.CoverImagePath, IsPublished: p.IsPublished,
		PublishedAt: p.PublishedAt, ReadingTime: p.ReadingTime, CreatedAt: p.CreatedAt, UpdatedAt: p.UpdatedAt,
	}
	if p.Author != nil {
		res.AuthorName = p.Author.Username
	}
	return res
}

func toPublicResponses(posts []PostResponse) []PublicPostResponse {
	res := make([]PublicPostResponse, 0, len(posts))
	for _, p := range posts {
		res = append(res, ToPublicResponse(p))
	}
	return res
}

// StatsResponse berisi tiga kartu statistik penulis beserta alias istilah skrip.
type StatsResponse struct {
	Total        int64 `json:"total_articles"`
	TotalTerbit  int64 `json:"total_terbit"`
	TotalDraf    int64 `json:"total_draf"`
	TotalSelesai int64 `json:"total_selesai"`
	BelumSelesai int64 `json:"belum_selesai"`
}

// AdminUserResponse adalah baris direktori pengguna untuk admin.
type AdminUserResponse struct {
	ID             uint      `json:"id"`
	Username       string    `json:"username"`
	Email          string    `json:"email"`
	Role           string    `json:"role"`
	TotalPosts     int64     `json:"total_articles"`
	TotalPublished int64     `json:"total_published"`
	CreatedAt      time.Time `json:"created_at"`
}

// ToPostResponse memetakan model ke DTO dan menghitung reading_time.
func ToPostResponse(p *database.Post) PostResponse {
	res := PostResponse{
		ID: p.ID, UserID: p.UserID, Title: p.Title, Slug: p.Slug, Category: p.Category,
		Excerpt: p.Excerpt, Content: p.Content, CoverImagePath: p.CoverImagePath,
		IsPublished: p.IsPublished, PublishedAt: p.PublishedAt, ReadingTime: ReadingTime(p.Content),
		CreatedAt: p.CreatedAt, UpdatedAt: p.UpdatedAt,
	}
	if p.User.ID != 0 {
		res.Author = &AuthorResponse{ID: p.User.ID, Username: p.User.Username}
	}
	return res
}
'@

Write-Repo 'internal/features/post/handler.go' @'
package post

import (
	"errors"
	"log"
	"net/http"
	"strconv"

	"app/internal/middleware"
	"app/internal/response"

	"github.com/gin-gonic/gin"
)

// Handler menangani /api/public/*, /api/posts/*, dan /api/admin/*.
type Handler struct{ svc Service }

// NewHandler membuat Handler.
func NewHandler(svc Service) *Handler { return &Handler{svc: svc} }

func handleError(c *gin.Context, err error) {
	var validation *ValidationError
	switch {
	case errors.As(err, &validation):
		response.Fail(c, http.StatusBadRequest, validation.Message)
	case errors.Is(err, ErrPostNotFound):
		response.Fail(c, http.StatusNotFound, "Artikel tidak ditemukan")
	case errors.Is(err, ErrForbidden):
		response.Fail(c, http.StatusForbidden, "Dilarang: artikel ini milik pengguna lain")
	default:
		log.Printf("post: kesalahan internal: %v", err)
		response.Error(c, http.StatusInternalServerError, "Terjadi kesalahan pada server")
	}
}

func parseID(c *gin.Context) (uint, bool) {
	id, err := strconv.ParseUint(c.Param("id"), 10, 32)
	if err != nil || id == 0 {
		response.Fail(c, http.StatusBadRequest, "ID tidak valid")
		return 0, false
	}
	return uint(id), true
}

func currentUser(c *gin.Context) uint { return c.GetUint(middleware.CtxUserID) }

// PublicCategories: GET /api/public/categories
func (h *Handler) PublicCategories(c *gin.Context) {
	response.Success(c, http.StatusOK, "Kategori berhasil diambil", h.svc.Categories())
}

// PublicList: GET /api/public/posts?q=&category=
func (h *Handler) PublicList(c *gin.Context) {
	posts, err := h.svc.ListPublic(c.Query("q"), c.Query("category"))
	if err != nil {
		handleError(c, err)
		return
	}
	response.Success(c, http.StatusOK, "Artikel berhasil diambil", toPublicResponses(posts))
}

// PublicDetail: GET /api/public/posts/:slug
func (h *Handler) PublicDetail(c *gin.Context) {
	p, err := h.svc.GetPublic(c.Param("slug"))
	if err != nil {
		handleError(c, err)
		return
	}
	response.Success(c, http.StatusOK, "Artikel berhasil diambil", ToPublicResponse(*p))
}

// List: GET /api/posts
func (h *Handler) List(c *gin.Context) {
	posts, err := h.svc.ListMine(currentUser(c))
	if err != nil {
		handleError(c, err)
		return
	}
	response.Success(c, http.StatusOK, "Artikel berhasil diambil", posts)
}

// Create: POST /api/posts
func (h *Handler) Create(c *gin.Context) {
	var req PostRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		response.Fail(c, http.StatusBadRequest, "Format permintaan tidak valid")
		return
	}
	p, err := h.svc.Create(currentUser(c), req)
	if err != nil {
		handleError(c, err)
		return
	}
	response.Success(c, http.StatusCreated, "Artikel berhasil dibuat", p)
}

// Stats: GET /api/posts/stats
func (h *Handler) Stats(c *gin.Context) {
	stats, err := h.svc.Stats(currentUser(c))
	if err != nil {
		handleError(c, err)
		return
	}
	response.Success(c, http.StatusOK, "Statistik berhasil diambil", stats)
}

// Get: GET /api/posts/:id
func (h *Handler) Get(c *gin.Context) {
	id, ok := parseID(c)
	if !ok {
		return
	}
	p, err := h.svc.Get(currentUser(c), id)
	if err != nil {
		handleError(c, err)
		return
	}
	response.Success(c, http.StatusOK, "Artikel berhasil diambil", p)
}

// Update: PUT /api/posts/:id
func (h *Handler) Update(c *gin.Context) {
	id, ok := parseID(c)
	if !ok {
		return
	}
	var req PostRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		response.Fail(c, http.StatusBadRequest, "Format permintaan tidak valid")
		return
	}
	p, err := h.svc.Update(currentUser(c), id, req)
	if err != nil {
		handleError(c, err)
		return
	}
	response.Success(c, http.StatusOK, "Artikel berhasil diperbarui", p)
}

// TogglePublish: PATCH /api/posts/:id/toggle-publish
func (h *Handler) TogglePublish(c *gin.Context) {
	id, ok := parseID(c)
	if !ok {
		return
	}
	p, err := h.svc.TogglePublish(currentUser(c), id)
	if err != nil {
		handleError(c, err)
		return
	}
	message := "Artikel dikembalikan ke draf"
	if p.IsPublished {
		message = "Artikel berhasil diterbitkan"
	}
	response.Success(c, http.StatusOK, message, p)
}

// Delete: DELETE /api/posts/:id
func (h *Handler) Delete(c *gin.Context) {
	id, ok := parseID(c)
	if !ok {
		return
	}
	if err := h.svc.Delete(currentUser(c), id); err != nil {
		handleError(c, err)
		return
	}
	response.Success(c, http.StatusOK, "Artikel berhasil dihapus")
}

// AdminUsers: GET /api/admin/users
func (h *Handler) AdminUsers(c *gin.Context) {
	users, err := h.svc.AdminUsers()
	if err != nil {
		handleError(c, err)
		return
	}
	response.Success(c, http.StatusOK, "Pengguna berhasil diambil", users)
}

// AdminPosts: GET /api/admin/posts
func (h *Handler) AdminPosts(c *gin.Context) {
	posts, err := h.svc.AdminPosts()
	if err != nil {
		handleError(c, err)
		return
	}
	response.Success(c, http.StatusOK, "Arsip artikel berhasil diambil", posts)
}

// AdminUserPosts: GET /api/admin/users/:id/posts
func (h *Handler) AdminUserPosts(c *gin.Context) {
	id, ok := parseID(c)
	if !ok {
		return
	}
	posts, err := h.svc.AdminUserPosts(id)
	if err != nil {
		handleError(c, err)
		return
	}
	response.Success(c, http.StatusOK, "Artikel pengguna berhasil diambil", posts)
}
'@

Write-Repo 'internal/features/post/post_test.go' @'
package post

import (
	"bytes"
	"encoding/json"
	"errors"
	"fmt"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
	"time"

	"app/internal/database"
	"app/internal/middleware"

	"github.com/gin-gonic/gin"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
	"gorm.io/gorm"
)

var errBoom = errors.New("boom")

func init() { gin.SetMode(gin.TestMode) }

type env struct {
	db                *gorm.DB
	repo              Repository
	svc               Service
	alice, bob, admin database.User
}

func newEnv(t *testing.T) *env {
	db, err := database.ConnectTest()
	require.NoError(t, err)
	e := &env{db: db, repo: NewRepository(db)}
	e.svc = NewService(e.repo)
	mk := func(name, role string) database.User {
		u := database.User{Username: name, Email: name + "@x.id", Password: "h", Role: role}
		require.NoError(t, db.Create(&u).Error)
		return u
	}
	e.alice, e.bob, e.admin = mk("alice", "member"), mk("bob", "member"), mk("root", "admin")
	return e
}

func (e *env) create(t *testing.T, owner uint, title, content string, published bool) *PostResponse {
	p, err := e.svc.Create(owner, PostRequest{Title: title, Content: content, IsPublished: &published})
	require.NoError(t, err)
	return p
}

func words(n int) string { return strings.TrimSpace(strings.Repeat("kata ", n)) }

// ---------- fungsi murni ----------

func TestReadingTime(t *testing.T) {
	cases := map[int]int{0: 1, 1: 1, 199: 1, 200: 1, 201: 2, 400: 2, 401: 3}
	for n, want := range cases {
		assert.Equal(t, want, ReadingTime(words(n)), "kata=%d", n)
	}
	assert.Equal(t, 1, ReadingTime("   \n\t "))
}

func TestSlugify(t *testing.T) {
	cases := map[string]string{
		"Halo Dunia!":               "halo-dunia",
		"  Éclair à la crème  ":     "eclair-a-la-creme",
		"Straße & Çaña":             "strase-cana",
		"a---b   c":                 "a-b-c",
		"Belajar Go 1.27 (Edisi 2)": "belajar-go-1-27-edisi-2",
		"!!!":                       "artikel",
		"日本語":                       "artikel",
		"":                          "artikel",
	}
	for in, want := range cases {
		assert.Equal(t, want, slugify(in), in)
	}
	long := slugify(strings.Repeat("abc ", 100))
	assert.LessOrEqual(t, len(long), maxSlugLength)
	assert.False(t, strings.HasSuffix(long, "-"))
	assert.Equal(t, maxSlugLength-1, len(long))
}

func TestCategories(t *testing.T) {
	assert.Equal(t, []string{"Teknologi", "Pendidikan", "Gaya Hidup", "Bisnis", "Opini", "Umum"}, Categories())
	c := Categories()
	c[0] = "Rusak"
	assert.Equal(t, "Teknologi", Categories()[0])

	got, ok := NormalizeCategory("  gaya hidup ")
	assert.True(t, ok)
	assert.Equal(t, "Gaya Hidup", got)
	_, ok = NormalizeCategory("Olahraga")
	assert.False(t, ok)
	_, ok = NormalizeCategory("")
	assert.False(t, ok)
}

func TestValidate(t *testing.T) {
	cases := []struct {
		name string
		req  PostRequest
		msg  string
	}{
		{"judul kosong", PostRequest{Title: " ", Content: "x"}, "Judul wajib diisi"},
		{"judul panjang", PostRequest{Title: strings.Repeat("a", 256), Content: "x"}, "Judul maksimal 255 karakter"},
		{"konten kosong", PostRequest{Title: "J", Content: " \n "}, "Konten wajib diisi"},
		{"kategori salah", PostRequest{Title: "J", Content: "x", Category: "Olahraga"}, "Kategori tidak valid. Pilih salah satu dari: Teknologi, Pendidikan, Gaya Hidup, Bisnis, Opini, Umum"},
	}
	for _, tc := range cases {
		_, err := validate(tc.req)
		var ve *ValidationError
		require.ErrorAs(t, err, &ve, tc.name)
		assert.Equal(t, tc.msg, ve.Error(), tc.name)
	}
	in, err := validate(PostRequest{Title: strings.Repeat("é", 255), Content: "x"})
	require.NoError(t, err)
	assert.Equal(t, "Umum", in.category)
	in, err = validate(PostRequest{Title: " J ", Content: "x", Category: "BISNIS", Excerpt: " r ", CoverImagePath: " http://c "})
	require.NoError(t, err)
	assert.Equal(t, &cleanInput{title: "J", category: "Bisnis", excerpt: "r", content: "x", cover: "http://c"}, in)
}

// ---------- service ----------

func TestCreateSlugAndFields(t *testing.T) {
	e := newEnv(t)
	fixed := time.Date(2026, 5, 1, 8, 0, 0, 0, time.UTC)
	old := nowFunc
	nowFunc = func() time.Time { return fixed }
	t.Cleanup(func() { nowFunc = old })

	a := e.create(t, e.alice.ID, "Halo Dunia", words(250), true)
	assert.Equal(t, "halo-dunia", a.Slug)
	assert.Equal(t, "Umum", a.Category)
	assert.Equal(t, 2, a.ReadingTime)
	assert.True(t, a.IsPublished)
	require.NotNil(t, a.PublishedAt)
	assert.True(t, a.PublishedAt.Equal(fixed))
	assert.Equal(t, e.alice.ID, a.UserID)

	assert.Equal(t, "halo-dunia-2", e.create(t, e.bob.ID, "Halo, Dunia!", "x", false).Slug)
	assert.Equal(t, "halo-dunia-3", e.create(t, e.bob.ID, "HALO DUNIA", "x", false).Slug)
	assert.Equal(t, "artikel", e.create(t, e.bob.ID, "???", "x", false).Slug)
	assert.Equal(t, "artikel-2", e.create(t, e.bob.ID, "!!!", "x", false).Slug)

	draft := e.create(t, e.alice.ID, "Draf", "x", false)
	assert.False(t, draft.IsPublished)
	assert.Nil(t, draft.PublishedAt)

	noFlag, err := e.svc.Create(e.alice.ID, PostRequest{Title: "Tanpa Flag", Content: "x", Category: "opini", Excerpt: "ringkas", CoverImagePath: "http://x/y.png"})
	require.NoError(t, err)
	assert.False(t, noFlag.IsPublished)
	assert.Equal(t, "Opini", noFlag.Category)
	assert.Equal(t, "ringkas", noFlag.Excerpt)
	assert.Equal(t, "http://x/y.png", noFlag.CoverImagePath)

	_, err = e.svc.Create(e.alice.ID, PostRequest{Title: "", Content: "x"})
	assert.Error(t, err)
}

func TestOwnershipReturnsForbidden(t *testing.T) {
	e := newEnv(t)
	p := e.create(t, e.alice.ID, "Milik Alice", "x", false)

	_, err := e.svc.Get(e.bob.ID, p.ID)
	assert.ErrorIs(t, err, ErrForbidden)
	_, err = e.svc.Update(e.bob.ID, p.ID, PostRequest{Title: "Curian", Content: "x"})
	assert.ErrorIs(t, err, ErrForbidden)
	_, err = e.svc.TogglePublish(e.bob.ID, p.ID)
	assert.ErrorIs(t, err, ErrForbidden)
	assert.ErrorIs(t, e.svc.Delete(e.bob.ID, p.ID), ErrForbidden)

	// ID yang tidak ada tetap 404, bukan 403.
	_, err = e.svc.Get(e.bob.ID, 9999)
	assert.ErrorIs(t, err, ErrPostNotFound)

	got, err := e.svc.Get(e.alice.ID, p.ID)
	require.NoError(t, err)
	assert.Equal(t, "Milik Alice", got.Title)
	require.NotNil(t, got.Author)
	assert.Equal(t, "alice", got.Author.Username)
}

func TestUpdate(t *testing.T) {
	e := newEnv(t)
	p := e.create(t, e.alice.ID, "Judul Awal", "isi awal", false)
	other := e.create(t, e.alice.ID, "Judul Lain", "x", false)

	// Judul sama: slug tetap.
	same, err := e.svc.Update(e.alice.ID, p.ID, PostRequest{Title: "Judul Awal", Content: "isi baru", Category: "Bisnis"})
	require.NoError(t, err)
	assert.Equal(t, "judul-awal", same.Slug)
	assert.Equal(t, "isi baru", same.Content)
	assert.Equal(t, "Bisnis", same.Category)

	// Judul berubah menjadi slug yang sama dengan miliknya sendiri → tidak diberi sufiks.
	self, err := e.svc.Update(e.alice.ID, p.ID, PostRequest{Title: "Judul Awal!", Content: "x"})
	require.NoError(t, err)
	assert.Equal(t, "judul-awal", self.Slug)

	// Judul bentrok dengan artikel lain → sufiks.
	clash, err := e.svc.Update(e.alice.ID, p.ID, PostRequest{Title: "Judul Lain", Content: "x"})
	require.NoError(t, err)
	assert.Equal(t, "judul-lain-2", clash.Slug)
	assert.Equal(t, "judul-lain", mustGet(t, e, e.alice.ID, other.ID).Slug)

	// Judul benar-benar baru.
	renamed, err := e.svc.Update(e.alice.ID, p.ID, PostRequest{Title: "Nama Baru", Content: "x"})
	require.NoError(t, err)
	assert.Equal(t, "nama-baru", renamed.Slug)

	_, err = e.svc.Update(e.alice.ID, p.ID, PostRequest{Title: "", Content: "x"})
	assert.Error(t, err)
	_, err = e.svc.Update(e.alice.ID, 9999, PostRequest{Title: "x", Content: "x"})
	assert.ErrorIs(t, err, ErrPostNotFound)
}

func mustGet(t *testing.T, e *env, user, id uint) *PostResponse {
	p, err := e.svc.Get(user, id)
	require.NoError(t, err)
	return p
}

func TestUpdateKeepsPublishedAtConsistent(t *testing.T) {
	e := newEnv(t)
	p := e.create(t, e.alice.ID, "Konsisten", "x", false)
	yes, no := true, false

	pub, err := e.svc.Update(e.alice.ID, p.ID, PostRequest{Title: "Konsisten", Content: "x", IsPublished: &yes})
	require.NoError(t, err)
	assert.True(t, pub.IsPublished)
	require.NotNil(t, pub.PublishedAt)
	first := *pub.PublishedAt

	time.Sleep(5 * time.Millisecond)
	again, err := e.svc.Update(e.alice.ID, p.ID, PostRequest{Title: "Konsisten", Content: "x", IsPublished: &yes})
	require.NoError(t, err)
	assert.True(t, again.PublishedAt.Equal(first), "published_at tidak boleh berubah bila sudah terbit")

	untouched, err := e.svc.Update(e.alice.ID, p.ID, PostRequest{Title: "Konsisten", Content: "x"})
	require.NoError(t, err)
	assert.True(t, untouched.IsPublished)

	draft, err := e.svc.Update(e.alice.ID, p.ID, PostRequest{Title: "Konsisten", Content: "x", IsPublished: &no})
	require.NoError(t, err)
	assert.False(t, draft.IsPublished)
	assert.Nil(t, draft.PublishedAt)
}

func TestTogglePublishAndDelete(t *testing.T) {
	e := newEnv(t)
	p := e.create(t, e.alice.ID, "Toggle", "x", false)

	on, err := e.svc.TogglePublish(e.alice.ID, p.ID)
	require.NoError(t, err)
	assert.True(t, on.IsPublished)
	assert.NotNil(t, on.PublishedAt)
	pub, err := e.svc.GetPublic("toggle")
	require.NoError(t, err)
	assert.Equal(t, p.ID, pub.ID)

	off, err := e.svc.TogglePublish(e.alice.ID, p.ID)
	require.NoError(t, err)
	assert.False(t, off.IsPublished)
	assert.Nil(t, off.PublishedAt)
	_, err = e.svc.GetPublic("toggle")
	assert.ErrorIs(t, err, ErrPostNotFound)

	require.NoError(t, e.svc.Delete(e.alice.ID, p.ID))
	_, err = e.svc.Get(e.alice.ID, p.ID)
	assert.ErrorIs(t, err, ErrPostNotFound)
}

func TestListMineAndStats(t *testing.T) {
	e := newEnv(t)
	e.create(t, e.alice.ID, "A1", "x", true)
	e.create(t, e.alice.ID, "A2", "x", false)
	e.create(t, e.alice.ID, "A3", "x", false)
	e.create(t, e.bob.ID, "B1", "x", true)

	mine, err := e.svc.ListMine(e.alice.ID)
	require.NoError(t, err)
	assert.Len(t, mine, 3)
	for _, p := range mine {
		assert.Equal(t, e.alice.ID, p.UserID)
	}

	s, err := e.svc.Stats(e.alice.ID)
	require.NoError(t, err)
	assert.Equal(t, &StatsResponse{Total: 3, TotalTerbit: 1, TotalDraf: 2, TotalSelesai: 1, BelumSelesai: 2}, s)
	empty, err := e.svc.Stats(e.admin.ID)
	require.NoError(t, err)
	assert.Equal(t, &StatsResponse{}, empty)

	none, err := e.svc.ListMine(e.admin.ID)
	require.NoError(t, err)
	assert.NotNil(t, none)
	assert.Empty(t, none)
}

func TestPublicListSearchAndFilter(t *testing.T) {
	e := newEnv(t)
	mk := func(title, cat, excerpt, content string, published bool, at time.Time) {
		p := database.Post{UserID: e.alice.ID, Title: title, Slug: slugify(title), Category: cat, Excerpt: excerpt, Content: content, IsPublished: published}
		if published {
			p.PublishedAt = &at
		}
		require.NoError(t, e.db.Create(&p).Error)
	}
	base := time.Date(2026, 1, 1, 0, 0, 0, 0, time.UTC)
	mk("Belajar GOLANG", "Teknologi", "intro", "isi", true, base)
	mk("Resep Nasi", "Gaya Hidup", "Memasak dengan Golang? bukan", "isi", true, base.Add(time.Hour))
	mk("Diskon 50% Hari Ini", "Bisnis", "promo", "kode_unik di sini", true, base.Add(2*time.Hour))
	mk("Konten Rahasia", "Teknologi", "draf", "golang", false, base)

	list, err := e.svc.ListPublic("", "")
	require.NoError(t, err)
	require.Len(t, list, 3)
	assert.Equal(t, []string{"diskon-50-hari-ini", "resep-nasi", "belajar-golang"}, []string{list[0].Slug, list[1].Slug, list[2].Slug}, "urut terbaru dulu")
	require.NotNil(t, list[0].Author)
	assert.Equal(t, "alice", list[0].Author.Username)

	byTitle, _ := e.svc.ListPublic("golang", "")
	assert.Len(t, byTitle, 2, "cocok di judul dan excerpt, tanpa membedakan huruf, tanpa draf")
	byContent, _ := e.svc.ListPublic("  KODE_UNIK ", "")
	assert.Len(t, byContent, 1)
	literalPercent, _ := e.svc.ListPublic("50%", "")
	assert.Len(t, literalPercent, 1)
	wildcard, _ := e.svc.ListPublic("%", "")
	assert.Len(t, wildcard, 1, "% harus dicari secara harfiah")
	underscore, _ := e.svc.ListPublic("_", "")
	assert.Len(t, underscore, 1)
	backslash, _ := e.svc.ListPublic(`\`, "")
	assert.Empty(t, backslash)

	tech, _ := e.svc.ListPublic("", "teknologi")
	require.Len(t, tech, 1)
	assert.Equal(t, "Teknologi", tech[0].Category)
	all, _ := e.svc.ListPublic("", "Semua")
	assert.Len(t, all, 3)
	unknown, err := e.svc.ListPublic("", "Tidak Ada")
	require.NoError(t, err)
	assert.NotNil(t, unknown)
	assert.Empty(t, unknown)
	combo, _ := e.svc.ListPublic("golang", "Gaya Hidup")
	assert.Len(t, combo, 1)
}

func TestAdminViews(t *testing.T) {
	e := newEnv(t)
	e.create(t, e.alice.ID, "A1", "x", true)
	e.create(t, e.alice.ID, "A2", "x", false)
	e.create(t, e.bob.ID, "B1", "x", true)

	users, err := e.svc.AdminUsers()
	require.NoError(t, err)
	require.Len(t, users, 3)
	byName := map[string]AdminUserResponse{}
	for _, u := range users {
		byName[u.Username] = u
	}
	assert.EqualValues(t, 2, byName["alice"].TotalPosts)
	assert.EqualValues(t, 1, byName["alice"].TotalPublished)
	assert.EqualValues(t, 1, byName["bob"].TotalPosts)
	assert.EqualValues(t, 0, byName["root"].TotalPosts)
	assert.Equal(t, "alice@x.id", byName["alice"].Email)

	all, err := e.svc.AdminPosts()
	require.NoError(t, err)
	assert.Len(t, all, 3)
	for _, p := range all {
		assert.NotNil(t, p.Author)
	}

	mine, err := e.svc.AdminUserPosts(e.alice.ID)
	require.NoError(t, err)
	assert.Len(t, mine, 2)
	empty, err := e.svc.AdminUserPosts(e.admin.ID)
	require.NoError(t, err)
	assert.Empty(t, empty)
	ghost, err := e.svc.AdminUserPosts(4242)
	require.NoError(t, err)
	assert.NotNil(t, ghost)
	assert.Empty(t, ghost, "pengguna yang tidak ada menghasilkan daftar kosong")
}

func TestToPublicResponse(t *testing.T) {
	now := time.Now()
	withAuthor := ToPublicResponse(PostResponse{
		ID: 7, UserID: 3, Title: "J", Slug: "j", Content: "isi", ReadingTime: 1, IsPublished: true,
		PublishedAt: &now, Author: &AuthorResponse{ID: 3, Username: "alice"},
	})
	assert.Equal(t, "alice", withAuthor.AuthorName)
	assert.EqualValues(t, 7, withAuthor.ID)
	raw, err := json.Marshal(withAuthor)
	require.NoError(t, err)
	assert.NotContains(t, string(raw), "user_id")
	assert.Contains(t, string(raw), `"author_name":"alice"`)

	noAuthor := ToPublicResponse(PostResponse{ID: 8, Title: "T"})
	assert.Equal(t, "", noAuthor.AuthorName)
	assert.Empty(t, toPublicResponses(nil))
	assert.NotNil(t, toPublicResponses(nil))
}

func TestCascadeDeleteUserRemovesPosts(t *testing.T) {
	e := newEnv(t)
	e.create(t, e.alice.ID, "A1", "x", true)
	require.NoError(t, e.db.Delete(&e.alice).Error)
	all, err := e.svc.AdminPosts()
	require.NoError(t, err)
	assert.Empty(t, all)
}

// ---------- repository: galat basis data ----------

func TestRepositoryErrors(t *testing.T) {
	e := newEnv(t)
	post := &database.Post{UserID: e.alice.ID, Title: "t", Slug: "t", Content: "c"}
	require.NoError(t, e.repo.Create(post))
	require.NoError(t, e.db.Migrator().DropTable(&database.Post{}))

	assert.Error(t, e.repo.Create(&database.Post{UserID: 1, Slug: "z"}))
	assert.Error(t, e.repo.Update(post))
	assert.Error(t, e.repo.Delete(post))
	_, err := e.repo.FindByIDAndUser(1, 1)
	assert.Error(t, err)
	assert.NotErrorIs(t, err, ErrPostNotFound)
	_, err = e.repo.FindPublishedBySlug("t")
	assert.Error(t, err)
	_, err = e.repo.SlugExists("t", 0)
	assert.Error(t, err)
	_, err = e.repo.ListPublished("", "")
	assert.Error(t, err)
	_, err = e.repo.ListByUser(1)
	assert.Error(t, err)
	_, err = e.repo.ListAll()
	assert.Error(t, err)
	_, _, err = e.repo.CountByUser(1)
	assert.Error(t, err)
	_, err = e.repo.CountsPerUser()
	assert.Error(t, err)
}

func TestRepositoryUserErrors(t *testing.T) {
	e := newEnv(t)
	_, err := e.repo.FindUser(4242)
	assert.ErrorIs(t, err, ErrUserNotFound)
	require.NoError(t, e.db.Migrator().DropTable(&database.Post{}, &database.User{}))
	_, err = e.repo.FindUser(1)
	assert.Error(t, err)
	assert.NotErrorIs(t, err, ErrUserNotFound)
	_, err = e.repo.ListUsers()
	assert.Error(t, err)
}

func TestCountByUserSecondQueryError(t *testing.T) {
	e := newEnv(t)
	calls := 0
	require.NoError(t, e.db.Callback().Query().Before("gorm:query").Register("gagal_kedua", func(tx *gorm.DB) {
		calls++
		if calls == 2 {
			_ = tx.AddError(errBoom)
		}
	}))
	_, _, err := e.repo.CountByUser(e.alice.ID)
	assert.ErrorIs(t, err, errBoom)
}

// ---------- service: repository gagal ----------

type flakyRepo struct {
	Repository
	fail map[string]bool
}

func (r *flakyRepo) Create(p *database.Post) error {
	if r.fail["Create"] {
		return errBoom
	}
	return r.Repository.Create(p)
}
func (r *flakyRepo) Update(p *database.Post) error {
	if r.fail["Update"] {
		return errBoom
	}
	return r.Repository.Update(p)
}
func (r *flakyRepo) Delete(p *database.Post) error {
	if r.fail["Delete"] {
		return errBoom
	}
	return r.Repository.Delete(p)
}
func (r *flakyRepo) FindByIDAndUser(id, u uint) (*database.Post, error) {
	if r.fail["FindByIDAndUser"] {
		return nil, errBoom
	}
	return r.Repository.FindByIDAndUser(id, u)
}
func (r *flakyRepo) FindPublishedBySlug(s string) (*database.Post, error) {
	if r.fail["FindPublishedBySlug"] {
		return nil, errBoom
	}
	return r.Repository.FindPublishedBySlug(s)
}
func (r *flakyRepo) SlugExists(s string, id uint) (bool, error) {
	if r.fail["SlugExists"] {
		return false, errBoom
	}
	return r.Repository.SlugExists(s, id)
}
func (r *flakyRepo) ListPublished(q, c string) ([]database.Post, error) {
	if r.fail["ListPublished"] {
		return nil, errBoom
	}
	return r.Repository.ListPublished(q, c)
}
func (r *flakyRepo) ListByUser(u uint) ([]database.Post, error) {
	if r.fail["ListByUser"] {
		return nil, errBoom
	}
	return r.Repository.ListByUser(u)
}
func (r *flakyRepo) ListAll() ([]database.Post, error) {
	if r.fail["ListAll"] {
		return nil, errBoom
	}
	return r.Repository.ListAll()
}
func (r *flakyRepo) CountByUser(u uint) (int64, int64, error) {
	if r.fail["CountByUser"] {
		return 0, 0, errBoom
	}
	return r.Repository.CountByUser(u)
}
func (r *flakyRepo) ListUsers() ([]database.User, error) {
	if r.fail["ListUsers"] {
		return nil, errBoom
	}
	return r.Repository.ListUsers()
}
func (r *flakyRepo) FindUser(id uint) (*database.User, error) {
	if r.fail["FindUser"] {
		return nil, errBoom
	}
	return r.Repository.FindUser(id)
}
func (r *flakyRepo) CountsPerUser() (map[uint]UserCount, error) {
	if r.fail["CountsPerUser"] {
		return nil, errBoom
	}
	return r.Repository.CountsPerUser()
}

func (e *env) failing(methods ...string) Service {
	m := map[string]bool{}
	for _, f := range methods {
		m[f] = true
	}
	return NewService(&flakyRepo{Repository: e.repo, fail: m})
}

func TestServiceRepositoryFailures(t *testing.T) {
	e := newEnv(t)
	p := e.create(t, e.alice.ID, "Ada", "x", false)
	ok := PostRequest{Title: "Ada", Content: "x"}
	renamed := PostRequest{Title: "Berganti", Content: "x"}

	checks := map[string]func(Service) error{
		"SlugExists:create":       func(s Service) error { _, err := s.Create(e.alice.ID, ok); return err },
		"Create:create":           func(s Service) error { _, err := s.Create(e.alice.ID, ok); return err },
		"SlugExists:update":       func(s Service) error { _, err := s.Update(e.alice.ID, p.ID, renamed); return err },
		"Update:update":           func(s Service) error { _, err := s.Update(e.alice.ID, p.ID, ok); return err },
		"FindByIDAndUser:get":     func(s Service) error { _, err := s.Get(e.alice.ID, p.ID); return err },
		"Update:toggle":           func(s Service) error { _, err := s.TogglePublish(e.alice.ID, p.ID); return err },
		"Delete:delete":           func(s Service) error { return s.Delete(e.alice.ID, p.ID) },
		"CountByUser:stats":       func(s Service) error { _, err := s.Stats(e.alice.ID); return err },
		"ListPublished:public":    func(s Service) error { _, err := s.ListPublic("", ""); return err },
		"FindPublishedBySlug:pub": func(s Service) error { _, err := s.GetPublic("ada"); return err },
		"ListByUser:mine":         func(s Service) error { _, err := s.ListMine(e.alice.ID); return err },
		"ListUsers:admin":         func(s Service) error { _, err := s.AdminUsers(); return err },
		"CountsPerUser:admin":     func(s Service) error { _, err := s.AdminUsers(); return err },
		"ListAll:admin":           func(s Service) error { _, err := s.AdminPosts(); return err },
		"ListByUser:adminposts":   func(s Service) error { _, err := s.AdminUserPosts(e.alice.ID); return err },
	}
	for name, run := range checks {
		method := strings.SplitN(name, ":", 2)[0]
		assert.ErrorIs(t, run(e.failing(method)), errBoom, name)
	}
}

// ---------- handler ----------

type apiResp struct {
	Status  string          `json:"status"`
	Message string          `json:"message"`
	Data    json.RawMessage `json:"data"`
}

func engine(svc Service, userID uint) *gin.Engine {
	h := NewHandler(svc)
	r := gin.New()
	r.Use(func(c *gin.Context) { c.Set(middleware.CtxUserID, userID); c.Next() })
	r.GET("/public/categories", h.PublicCategories)
	r.GET("/public/posts", h.PublicList)
	r.GET("/public/posts/:slug", h.PublicDetail)
	r.GET("/posts", h.List)
	r.POST("/posts", h.Create)
	r.GET("/posts/stats", h.Stats)
	r.GET("/posts/:id", h.Get)
	r.PUT("/posts/:id", h.Update)
	r.PATCH("/posts/:id/toggle-publish", h.TogglePublish)
	r.DELETE("/posts/:id", h.Delete)
	r.GET("/admin/users", h.AdminUsers)
	r.GET("/admin/posts", h.AdminPosts)
	r.GET("/admin/users/:id/posts", h.AdminUserPosts)
	return r
}

func send(r *gin.Engine, method, path string, body any) (int, apiResp) {
	var buf bytes.Buffer
	switch b := body.(type) {
	case string:
		buf.WriteString(b)
	case nil:
	default:
		_ = json.NewEncoder(&buf).Encode(b)
	}
	req := httptest.NewRequest(method, path, &buf)
	req.Header.Set("Content-Type", "application/json")
	w := httptest.NewRecorder()
	r.ServeHTTP(w, req)
	var out apiResp
	_ = json.Unmarshal(w.Body.Bytes(), &out)
	return w.Code, out
}

func TestHandlerHappyPaths(t *testing.T) {
	e := newEnv(t)
	r := engine(e.svc, e.alice.ID)

	code, res := send(r, "GET", "/public/categories", nil)
	assert.Equal(t, 200, code)
	assert.JSONEq(t, `["Teknologi","Pendidikan","Gaya Hidup","Bisnis","Opini","Umum"]`, string(res.Data))

	code, res = send(r, "POST", "/posts", gin.H{"title": "Artikel Satu", "content": words(10), "category": "Teknologi", "is_published": true})
	require.Equal(t, 201, code)
	var created PostResponse
	require.NoError(t, json.Unmarshal(res.Data, &created))
	assert.Equal(t, "artikel-satu", created.Slug)
	assert.Equal(t, 1, created.ReadingTime)

	code, res = send(r, "GET", "/public/posts?q=satu&category=Teknologi", nil)
	assert.Equal(t, 200, code)
	var list []PostResponse
	require.NoError(t, json.Unmarshal(res.Data, &list))
	assert.Len(t, list, 1)

	code, res = send(r, "GET", "/public/posts/artikel-satu", nil)
	assert.Equal(t, 200, code)
	assert.Contains(t, string(res.Data), `"author_name":"alice"`)
	assert.NotContains(t, string(res.Data), "user_id")
	code, _ = send(r, "GET", "/public/posts/tidak-ada", nil)
	assert.Equal(t, 404, code)

	path := fmt.Sprintf("/posts/%d", created.ID)
	code, _ = send(r, "GET", "/posts", nil)
	assert.Equal(t, 200, code)
	code, res = send(r, "GET", "/posts/stats", nil)
	assert.Equal(t, 200, code)
	assert.JSONEq(t, `{"total_articles":1,"total_terbit":1,"total_draf":0,"total_selesai":1,"belum_selesai":0}`, string(res.Data))
	code, _ = send(r, "GET", path, nil)
	assert.Equal(t, 200, code)
	code, res = send(r, "PUT", path, gin.H{"title": "Judul Baru", "content": "isi"})
	assert.Equal(t, 200, code)
	assert.Contains(t, string(res.Data), `"slug":"judul-baru"`)

	code, res = send(r, "PATCH", path+"/toggle-publish", nil)
	assert.Equal(t, 200, code)
	assert.Equal(t, "Artikel dikembalikan ke draf", res.Message)
	code, res = send(r, "PATCH", path+"/toggle-publish", nil)
	assert.Equal(t, 200, code)
	assert.Equal(t, "Artikel berhasil diterbitkan", res.Message)

	code, res = send(r, "DELETE", path, nil)
	assert.Equal(t, 200, code)
	assert.Empty(t, res.Data)
	code, _ = send(r, "GET", path, nil)
	assert.Equal(t, 404, code)
}

func TestHandlerAdminEndpoints(t *testing.T) {
	e := newEnv(t)
	e.create(t, e.alice.ID, "A1", "x", true)
	r := engine(e.svc, e.admin.ID)

	code, res := send(r, "GET", "/admin/users", nil)
	assert.Equal(t, 200, code)
	assert.Contains(t, string(res.Data), `"total_articles":1`)
	assert.Contains(t, string(res.Data), `"total_published":1`)
	code, _ = send(r, "GET", "/admin/posts", nil)
	assert.Equal(t, 200, code)
	code, _ = send(r, "GET", fmt.Sprintf("/admin/users/%d/posts", e.alice.ID), nil)
	assert.Equal(t, 200, code)
	code, res = send(r, "GET", "/admin/users/4242/posts", nil)
	assert.Equal(t, 200, code)
	assert.JSONEq(t, `[]`, string(res.Data))
	code, _ = send(r, "GET", "/admin/users/abc/posts", nil)
	assert.Equal(t, 400, code)
}

func TestHandlerClientErrors(t *testing.T) {
	e := newEnv(t)
	r := engine(e.svc, e.alice.ID)

	code, res := send(r, "POST", "/posts", "{rusak")
	assert.Equal(t, 400, code)
	assert.Equal(t, "fail", res.Status)
	code, res = send(r, "POST", "/posts", gin.H{"title": "", "content": "x"})
	assert.Equal(t, 400, code)
	assert.Equal(t, "Judul wajib diisi", res.Message)

	for _, m := range []string{"GET", "PUT", "PATCH", "DELETE"} {
		path := "/posts/abc"
		if m == "PATCH" {
			path += "/toggle-publish"
		}
		code, res = send(r, m, path, gin.H{"title": "x", "content": "x"})
		assert.Equal(t, 400, code, m)
		assert.Equal(t, "ID tidak valid", res.Message, m)
	}
	code, _ = send(r, "GET", "/posts/0", nil)
	assert.Equal(t, 400, code)

	code, _ = send(r, "PUT", "/posts/1", "{rusak")
	assert.Equal(t, 400, code)
	code, _ = send(r, "PUT", "/posts/9999", gin.H{"title": "x", "content": "x"})
	assert.Equal(t, 404, code)
	code, _ = send(r, "PATCH", "/posts/9999/toggle-publish", nil)
	assert.Equal(t, 404, code)
	code, _ = send(r, "DELETE", "/posts/9999", nil)
	assert.Equal(t, 404, code)
}

func TestHandlerForbiddenForOtherUsersPost(t *testing.T) {
	e := newEnv(t)
	p := e.create(t, e.alice.ID, "Milik Alice", "x", false)
	r := engine(e.svc, e.bob.ID)
	path := fmt.Sprintf("/posts/%d", p.ID)
	for _, tc := range []struct{ method, path string }{
		{"GET", path}, {"PUT", path}, {"PATCH", path + "/toggle-publish"}, {"DELETE", path},
	} {
		code, res := send(r, tc.method, tc.path, gin.H{"title": "Curian", "content": "x"})
		assert.Equal(t, http.StatusForbidden, code, tc.method)
		assert.Equal(t, "fail", res.Status, tc.method)
	}
}

func TestHandlerServerErrors(t *testing.T) {
	e := newEnv(t)
	p := e.create(t, e.alice.ID, "Ada", "x", true)
	id := fmt.Sprint(p.ID)
	cases := []struct{ method, path, fail string }{
		{"GET", "/public/posts", "ListPublished"},
		{"GET", "/public/posts/ada", "FindPublishedBySlug"},
		{"GET", "/posts", "ListByUser"},
		{"POST", "/posts", "SlugExists"},
		{"GET", "/posts/stats", "CountByUser"},
		{"GET", "/posts/" + id, "FindByIDAndUser"},
		{"PUT", "/posts/" + id, "FindByIDAndUser"},
		{"PATCH", "/posts/" + id + "/toggle-publish", "FindByIDAndUser"},
		{"DELETE", "/posts/" + id, "FindByIDAndUser"},
		{"GET", "/admin/users", "ListUsers"},
		{"GET", "/admin/posts", "ListAll"},
		{"GET", "/admin/users/1/posts", "ListByUser"},
	}
	for _, tc := range cases {
		r := engine(e.failing(tc.fail), e.alice.ID)
		code, res := send(r, tc.method, tc.path, gin.H{"title": "Ada", "content": "x"})
		assert.Equal(t, http.StatusInternalServerError, code, tc.path)
		assert.Equal(t, "error", res.Status, tc.path)
		assert.Equal(t, "Terjadi kesalahan pada server", res.Message, tc.path)
	}
}
'@

Write-Repo 'internal/features/post/repository.go' @'
package post

import (
	"errors"
	"strings"

	"app/internal/database"

	"gorm.io/gorm"
	"gorm.io/gorm/clause"
)

// Galat domain pada lapisan data/service.
var (
	ErrPostNotFound = errors.New("artikel tidak ditemukan")
	ErrUserNotFound = errors.New("pengguna tidak ditemukan")
	ErrForbidden    = errors.New("artikel milik pengguna lain")
)

// UserCount adalah agregat jumlah artikel per pengguna.
type UserCount struct {
	UserID    uint
	Total     int64
	Published int64
}

// Repository mengabstraksi akses data artikel.
type Repository interface {
	Create(p *database.Post) error
	Update(p *database.Post) error
	Delete(p *database.Post) error
	FindByIDAndUser(id, userID uint) (*database.Post, error)
	FindPublishedBySlug(slug string) (*database.Post, error)
	SlugExists(slug string, excludeID uint) (bool, error)
	ListPublished(query, category string) ([]database.Post, error)
	ListByUser(userID uint) ([]database.Post, error)
	ListAll() ([]database.Post, error)
	CountByUser(userID uint) (total, published int64, err error)
	ListUsers() ([]database.User, error)
	FindUser(id uint) (*database.User, error)
	CountsPerUser() (map[uint]UserCount, error)
}

type repository struct{ db *gorm.DB }

// NewRepository membuat Repository berbasis GORM.
func NewRepository(db *gorm.DB) Repository { return &repository{db: db} }

func (r *repository) Create(p *database.Post) error {
	return r.db.Omit(clause.Associations).Create(p).Error
}

func (r *repository) Update(p *database.Post) error {
	return r.db.Omit(clause.Associations).Save(p).Error
}

func (r *repository) Delete(p *database.Post) error {
	return r.db.Delete(p).Error
}

func (r *repository) findOne(query string, args ...any) (*database.Post, error) {
	var p database.Post
	if err := r.db.Preload("User").Where(query, args...).First(&p).Error; err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			return nil, ErrPostNotFound
		}
		return nil, err
	}
	return &p, nil
}

// FindByIDAndUser mengambil artikel berdasarkan ID. ErrPostNotFound bila tidak ada,
// ErrForbidden bila artikel ada tetapi dimiliki pengguna lain.
func (r *repository) FindByIDAndUser(id, userID uint) (*database.Post, error) {
	p, err := r.findOne("id = ?", id)
	if err != nil {
		return nil, err
	}
	if p.UserID != userID {
		return nil, ErrForbidden
	}
	return p, nil
}

func (r *repository) FindPublishedBySlug(slug string) (*database.Post, error) {
	return r.findOne("slug = ? AND is_published = ?", slug, true)
}

func (r *repository) SlugExists(slug string, excludeID uint) (bool, error) {
	var count int64
	err := r.db.Model(&database.Post{}).Where("slug = ? AND id <> ?", slug, excludeID).Count(&count).Error
	return count > 0, err
}

// escapeLike meloloskan karakter khusus LIKE agar kata kunci dicari apa adanya.
func escapeLike(s string) string {
	return strings.NewReplacer(`\`, `\\`, `%`, `\%`, `_`, `\_`).Replace(s)
}

func (r *repository) ListPublished(query, category string) ([]database.Post, error) {
	tx := r.db.Preload("User").Where("is_published = ?", true)
	if category != "" {
		tx = tx.Where("category = ?", category)
	}
	if query != "" {
		like := "%" + escapeLike(strings.ToLower(query)) + "%"
		tx = tx.Where(`(LOWER(title) LIKE ? ESCAPE '\' OR LOWER(excerpt) LIKE ? ESCAPE '\' OR LOWER(content) LIKE ? ESCAPE '\')`, like, like, like)
	}
	var posts []database.Post
	err := tx.Order("published_at DESC, id DESC").Find(&posts).Error
	return posts, err
}

func (r *repository) ListByUser(userID uint) ([]database.Post, error) {
	var posts []database.Post
	err := r.db.Preload("User").Where("user_id = ?", userID).Order("created_at DESC, id DESC").Find(&posts).Error
	return posts, err
}

func (r *repository) ListAll() ([]database.Post, error) {
	var posts []database.Post
	err := r.db.Preload("User").Order("created_at DESC, id DESC").Find(&posts).Error
	return posts, err
}

func (r *repository) CountByUser(userID uint) (int64, int64, error) {
	var total, published int64
	if err := r.db.Model(&database.Post{}).Where("user_id = ?", userID).Count(&total).Error; err != nil {
		return 0, 0, err
	}
	err := r.db.Model(&database.Post{}).Where("user_id = ? AND is_published = ?", userID, true).Count(&published).Error
	return total, published, err
}

func (r *repository) ListUsers() ([]database.User, error) {
	var users []database.User
	err := r.db.Order("id ASC").Find(&users).Error
	return users, err
}

func (r *repository) FindUser(id uint) (*database.User, error) {
	var u database.User
	if err := r.db.First(&u, id).Error; err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			return nil, ErrUserNotFound
		}
		return nil, err
	}
	return &u, nil
}

func (r *repository) CountsPerUser() (map[uint]UserCount, error) {
	var rows []UserCount
	err := r.db.Model(&database.Post{}).
		Select("user_id, COUNT(*) AS total, COALESCE(SUM(CASE WHEN is_published = ? THEN 1 ELSE 0 END), 0) AS published", true).
		Group("user_id").Scan(&rows).Error
	if err != nil {
		return nil, err
	}
	counts := make(map[uint]UserCount, len(rows))
	for _, row := range rows {
		counts[row.UserID] = row
	}
	return counts, nil
}
'@

Write-Repo 'internal/features/post/service.go' @'
package post

import (
	"fmt"
	"strings"
	"time"
	"unicode/utf8"

	"app/internal/database"
)

// ValidationError menandakan input tidak valid (HTTP 400).
type ValidationError struct{ Message string }

func (e *ValidationError) Error() string { return e.Message }

// nowFunc dapat diganti saat pengujian.
var nowFunc = time.Now

const (
	wordsPerMinute = 200
	maxSlugLength  = 200
	fallbackSlug   = "artikel"
)

// Service memuat logika bisnis artikel.
type Service interface {
	Categories() []string
	ListPublic(query, category string) ([]PostResponse, error)
	GetPublic(slug string) (*PostResponse, error)
	ListMine(userID uint) ([]PostResponse, error)
	Create(userID uint, req PostRequest) (*PostResponse, error)
	Get(userID, id uint) (*PostResponse, error)
	Update(userID, id uint, req PostRequest) (*PostResponse, error)
	TogglePublish(userID, id uint) (*PostResponse, error)
	Delete(userID, id uint) error
	Stats(userID uint) (*StatsResponse, error)
	AdminUsers() ([]AdminUserResponse, error)
	AdminPosts() ([]PostResponse, error)
	AdminUserPosts(userID uint) ([]PostResponse, error)
}

type service struct{ repo Repository }

// NewService membuat Service.
func NewService(repo Repository) Service { return &service{repo: repo} }

// ReadingTime menghitung estimasi menit baca: ceil(kata/200), minimal 1 menit.
func ReadingTime(content string) int {
	words := len(strings.Fields(content))
	if words == 0 {
		return 1
	}
	return (words + wordsPerMinute - 1) / wordsPerMinute
}

var accentGroups = []string{
	"aàáâãäåāăą", "cçćč", "eèéêëēěę", "iìíîïī", "nñń", "oòóôõöøō", "sšśß", "uùúûüū", "yýÿ", "zžźż",
}

var accentMap = func() map[rune]rune {
	m := make(map[rune]rune)
	for _, g := range accentGroups {
		runes := []rune(g)
		for _, r := range runes[1:] {
			m[r] = runes[0]
		}
	}
	return m
}()

// slugify mengubah judul menjadi slug URL: huruf kecil, tanpa aksen/simbol, dipisah "-".
func slugify(title string) string {
	var b strings.Builder
	lastDash := true // mencegah tanda hubung di awal
	for _, r := range strings.ToLower(title) {
		if mapped, ok := accentMap[r]; ok {
			r = mapped
		}
		if (r >= 'a' && r <= 'z') || (r >= '0' && r <= '9') {
			b.WriteRune(r)
			lastDash = false
			continue
		}
		if !lastDash {
			b.WriteByte('-')
			lastDash = true
		}
	}
	slug := strings.Trim(b.String(), "-")
	if len(slug) > maxSlugLength {
		slug = strings.Trim(slug[:maxSlugLength], "-")
	}
	if slug == "" {
		return fallbackSlug
	}
	return slug
}

// uniqueSlug menghasilkan slug unik; tabrakan diberi sufiks -2, -3, dst.
func (s *service) uniqueSlug(title string, excludeID uint) (string, error) {
	base := slugify(title)
	candidate := base
	for i := 2; ; i++ {
		exists, err := s.repo.SlugExists(candidate, excludeID)
		if err != nil {
			return "", err
		}
		if !exists {
			return candidate, nil
		}
		candidate = fmt.Sprintf("%s-%d", base, i)
	}
}

type cleanInput struct{ title, category, excerpt, content, cover string }

func validate(req PostRequest) (*cleanInput, error) {
	title := strings.TrimSpace(req.Title)
	if title == "" {
		return nil, &ValidationError{"Judul wajib diisi"}
	}
	if utf8.RuneCountInString(title) > 255 {
		return nil, &ValidationError{"Judul maksimal 255 karakter"}
	}
	if strings.TrimSpace(req.Content) == "" {
		return nil, &ValidationError{"Konten wajib diisi"}
	}
	category := DefaultCategory
	if strings.TrimSpace(req.Category) != "" {
		normalized, ok := NormalizeCategory(req.Category)
		if !ok {
			return nil, &ValidationError{"Kategori tidak valid. Pilih salah satu dari: " + strings.Join(categories, ", ")}
		}
		category = normalized
	}
	return &cleanInput{
		title: title, category: category, content: req.Content,
		excerpt: strings.TrimSpace(req.Excerpt), cover: strings.TrimSpace(req.CoverImagePath),
	}, nil
}

// setPublished menjaga konsistensi is_published dan published_at.
func setPublished(p *database.Post, published bool, now time.Time) {
	p.IsPublished = published
	if !published {
		p.PublishedAt = nil
		return
	}
	if p.PublishedAt == nil {
		p.PublishedAt = &now
	}
}

func toResponses(posts []database.Post) []PostResponse {
	res := make([]PostResponse, 0, len(posts))
	for i := range posts {
		res = append(res, ToPostResponse(&posts[i]))
	}
	return res
}

func (s *service) Categories() []string { return Categories() }

func (s *service) ListPublic(query, category string) ([]PostResponse, error) {
	query = strings.TrimSpace(query)
	category = strings.TrimSpace(category)
	if strings.EqualFold(category, "semua") {
		category = ""
	}
	if canonical, ok := NormalizeCategory(category); ok {
		category = canonical
	}
	posts, err := s.repo.ListPublished(query, category)
	if err != nil {
		return nil, err
	}
	return toResponses(posts), nil
}

func (s *service) GetPublic(slug string) (*PostResponse, error) {
	p, err := s.repo.FindPublishedBySlug(slug)
	if err != nil {
		return nil, err
	}
	res := ToPostResponse(p)
	return &res, nil
}

func (s *service) ListMine(userID uint) ([]PostResponse, error) {
	posts, err := s.repo.ListByUser(userID)
	if err != nil {
		return nil, err
	}
	return toResponses(posts), nil
}

func (s *service) Create(userID uint, req PostRequest) (*PostResponse, error) {
	in, err := validate(req)
	if err != nil {
		return nil, err
	}
	slug, err := s.uniqueSlug(in.title, 0)
	if err != nil {
		return nil, err
	}
	p := &database.Post{
		UserID: userID, Title: in.title, Slug: slug, Category: in.category,
		Excerpt: in.excerpt, Content: in.content, CoverImagePath: in.cover,
	}
	if req.IsPublished != nil {
		setPublished(p, *req.IsPublished, nowFunc())
	}
	if err := s.repo.Create(p); err != nil {
		return nil, err
	}
	res := ToPostResponse(p)
	return &res, nil
}

func (s *service) Get(userID, id uint) (*PostResponse, error) {
	p, err := s.repo.FindByIDAndUser(id, userID)
	if err != nil {
		return nil, err
	}
	res := ToPostResponse(p)
	return &res, nil
}

func (s *service) Update(userID, id uint, req PostRequest) (*PostResponse, error) {
	p, err := s.repo.FindByIDAndUser(id, userID)
	if err != nil {
		return nil, err
	}
	in, err := validate(req)
	if err != nil {
		return nil, err
	}
	if in.title != p.Title {
		slug, err := s.uniqueSlug(in.title, p.ID)
		if err != nil {
			return nil, err
		}
		p.Slug = slug
	}
	p.Title, p.Category, p.Excerpt, p.Content, p.CoverImagePath = in.title, in.category, in.excerpt, in.content, in.cover
	if req.IsPublished != nil {
		setPublished(p, *req.IsPublished, nowFunc())
	}
	if err := s.repo.Update(p); err != nil {
		return nil, err
	}
	res := ToPostResponse(p)
	return &res, nil
}

func (s *service) TogglePublish(userID, id uint) (*PostResponse, error) {
	p, err := s.repo.FindByIDAndUser(id, userID)
	if err != nil {
		return nil, err
	}
	setPublished(p, !p.IsPublished, nowFunc())
	if err := s.repo.Update(p); err != nil {
		return nil, err
	}
	res := ToPostResponse(p)
	return &res, nil
}

func (s *service) Delete(userID, id uint) error {
	p, err := s.repo.FindByIDAndUser(id, userID)
	if err != nil {
		return err
	}
	return s.repo.Delete(p)
}

func (s *service) Stats(userID uint) (*StatsResponse, error) {
	total, published, err := s.repo.CountByUser(userID)
	if err != nil {
		return nil, err
	}
	drafts := total - published
	return &StatsResponse{
		Total: total, TotalTerbit: published, TotalDraf: drafts,
		TotalSelesai: published, BelumSelesai: drafts,
	}, nil
}

func (s *service) AdminUsers() ([]AdminUserResponse, error) {
	users, err := s.repo.ListUsers()
	if err != nil {
		return nil, err
	}
	counts, err := s.repo.CountsPerUser()
	if err != nil {
		return nil, err
	}
	res := make([]AdminUserResponse, 0, len(users))
	for _, u := range users {
		c := counts[u.ID]
		res = append(res, AdminUserResponse{
			ID: u.ID, Username: u.Username, Email: u.Email, Role: u.Role,
			TotalPosts: c.Total, TotalPublished: c.Published, CreatedAt: u.CreatedAt,
		})
	}
	return res, nil
}

func (s *service) AdminPosts() ([]PostResponse, error) {
	posts, err := s.repo.ListAll()
	if err != nil {
		return nil, err
	}
	return toResponses(posts), nil
}

// AdminUserPosts mengembalikan artikel milik userID; pengguna yang tidak ada
// menghasilkan daftar kosong (bukan galat).
func (s *service) AdminUserPosts(userID uint) ([]PostResponse, error) {
	posts, err := s.repo.ListByUser(userID)
	if err != nil {
		return nil, err
	}
	return toResponses(posts), nil
}
'@

Write-Repo 'internal/server/router_test.go' @'
package server

import (
	"bytes"
	"crypto/tls"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"net/http/httptest"
	"sort"
	"strings"
	"testing"

	"app/docs"
	"app/internal/config"
	"app/internal/database"

	"github.com/gin-gonic/gin"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

type fixture struct {
	r      *gin.Engine
	cfg    *config.Config
	search *httptest.Server
	openai *httptest.Server
}

func newFixture(t *testing.T) *fixture {
	gin.SetMode(gin.TestMode)
	search := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		_, _ = io.WriteString(w, `{"data":{"results":[{"title":"Toba","url":"https://toba.id","snippet":"kaldera"}]}}`)
	}))
	mux := http.NewServeMux()
	mux.HandleFunc("/models", func(w http.ResponseWriter, r *http.Request) { _, _ = io.WriteString(w, `{}`) })
	mux.HandleFunc("/chat/completions", func(w http.ResponseWriter, r *http.Request) {
		content := "```json\n" + `{"title":"Artikel AI","category":"opini","excerpt":"Ringkas","content":"## Isi\n\nTeks\n\n## Referensi\n- Toba"}` + "\n```"
		b, _ := json.Marshal(map[string]any{"choices": []any{map[string]any{"message": map[string]any{"content": content}}}})
		_, _ = w.Write(b)
	})
	openai := httptest.NewServer(mux)
	t.Cleanup(search.Close)
	t.Cleanup(openai.Close)

	cfg := &config.Config{
		AppEnv: "development", AppKey: "kunci-router-uji", AdminUsername: "admin", AdminPassword: "admin",
		SearchEngineEndpoint: search.URL, OpenAIEndpoint: openai.URL, OpenAIKey: "k", OpenAIModel: "m",
	}
	db, err := database.ConnectTest()
	require.NoError(t, err)
	require.NoError(t, database.Seed(db, cfg))
	return &fixture{r: SetupRouter(cfg, db), cfg: cfg, search: search, openai: openai}
}

type result struct {
	Code    int
	Status  string          `json:"status"`
	Message string          `json:"message"`
	Data    json.RawMessage `json:"data"`
	Raw     *httptest.ResponseRecorder
}

func (f *fixture) do(method, path, token string, body any, headers ...string) result {
	var buf bytes.Buffer
	if body != nil {
		_ = json.NewEncoder(&buf).Encode(body)
	}
	req := httptest.NewRequest(method, path, &buf)
	req.Header.Set("Content-Type", "application/json")
	if token != "" {
		req.Header.Set("Authorization", "Bearer "+token)
	}
	for i := 0; i+1 < len(headers); i += 2 {
		req.Header.Set(headers[i], headers[i+1])
	}
	w := httptest.NewRecorder()
	f.r.ServeHTTP(w, req)
	res := result{Code: w.Code, Raw: w}
	_ = json.Unmarshal(w.Body.Bytes(), &res)
	return res
}

func (f *fixture) login(t *testing.T, username, password string) string {
	res := f.do("POST", "/api/auth/login", "", gin.H{"username": username, "password": password})
	require.Equal(t, 200, res.Code, res.Message)
	var data struct{ Token string }
	require.NoError(t, json.Unmarshal(res.Data, &data))
	return data.Token
}

func TestRoutesMatchOpenAPIDocument(t *testing.T) {
	f := newFixture(t)

	var spec struct {
		Paths map[string]map[string]json.RawMessage `json:"paths"`
	}
	require.NoError(t, json.Unmarshal(docs.ApiJSON, &spec))
	documented := map[string]bool{}
	for path, methods := range spec.Paths {
		for m := range methods {
			documented[strings.ToUpper(m)+" "+path] = true
		}
	}

	registered := map[string]bool{}
	for _, rt := range f.r.Routes() {
		if rt.Path == "/swagger" { // alias pengalihan ke /swagger/index.html
			continue
		}
		path := rt.Path
		for _, seg := range strings.Split(path, "/") {
			if strings.HasPrefix(seg, ":") || strings.HasPrefix(seg, "*") {
				path = strings.Replace(path, seg, "{"+seg[1:]+"}", 1)
			}
		}
		registered[rt.Method+" "+path] = true
	}

	keys := func(m map[string]bool) []string {
		out := make([]string, 0, len(m))
		for k := range m {
			out = append(out, k)
		}
		sort.Strings(out)
		return out
	}
	assert.Equal(t, keys(registered), keys(documented), "rute router harus identik dengan api.json")
	assert.Len(t, registered, 21)
}

func TestNoRouteAndCORS(t *testing.T) {
	f := newFixture(t)
	res := f.do("GET", "/api/xyz", "", nil)
	assert.Equal(t, 404, res.Code)
	assert.Equal(t, "fail", res.Status)
	assert.Equal(t, "Endpoint not found", res.Message)

	pre := f.do("OPTIONS", "/api/posts", "", nil, "Origin", "https://blog.example", "Access-Control-Request-Method", "POST")
	assert.Equal(t, 204, pre.Code)
	assert.Equal(t, "*", pre.Raw.Header().Get("Access-Control-Allow-Origin"))
}

func TestSwaggerRoutes(t *testing.T) {
	f := newFixture(t)

	for _, p := range []string{"/swagger", "/swagger/"} {
		res := f.do("GET", p, "", nil)
		assert.Equal(t, 301, res.Code, p)
		assert.Equal(t, "/swagger/index.html", res.Raw.Header().Get("Location"), p)
	}

	ui := f.do("GET", "/swagger/index.html", "", nil)
	assert.Equal(t, 200, ui.Code)
	assert.Contains(t, ui.Raw.Body.String(), "swagger-initializer.js")
	init := f.do("GET", "/swagger/swagger-initializer.js", "", nil)
	assert.Equal(t, 200, init.Code)
	assert.Contains(t, init.Raw.Body.String(), "/swagger/api.json")
	assert.Equal(t, 200, f.do("GET", "/swagger/swagger-ui.css", "", nil).Code)

	for _, p := range []string{"/swagger/api.json", "/swagger/doc.json", "/api.json"} {
		res := f.do("GET", p, "", nil)
		assert.Equal(t, 200, res.Code, p)
		assert.Contains(t, res.Raw.Header().Get("Content-Type"), "application/json")
		var doc map[string]any
		require.NoError(t, json.Unmarshal(res.Raw.Body.Bytes(), &doc), p)
		assert.Equal(t, "Delcom Blog REST API", doc["info"].(map[string]any)["title"])
	}
}

func TestAPIJSONIsDynamic(t *testing.T) {
	f := newFixture(t)
	get := func(headers ...string) map[string]any {
		res := f.do("GET", "/api.json", "", nil, headers...)
		var doc map[string]any
		require.NoError(t, json.Unmarshal(res.Raw.Body.Bytes(), &doc))
		return doc
	}

	doc := get()
	assert.Equal(t, "example.com", doc["host"])
	assert.Equal(t, []any{"http"}, doc["schemes"])

	doc = get("X-Forwarded-Host", "blog.delcom.org", "X-Forwarded-Proto", "https")
	assert.Equal(t, "blog.delcom.org", doc["host"])
	assert.Equal(t, []any{"https"}, doc["schemes"])

	req := httptest.NewRequest("GET", "/api.json", nil)
	req.TLS = &tls.ConnectionState{}
	w := httptest.NewRecorder()
	f.r.ServeHTTP(w, req)
	assert.Contains(t, w.Body.String(), `"https"`)
}

func TestProductionModeUsesReleaseMode(t *testing.T) {
	gin.SetMode(gin.TestMode)
	t.Cleanup(func() { gin.SetMode(gin.TestMode) })
	db, err := database.ConnectTest()
	require.NoError(t, err)
	SetupRouter(&config.Config{AppEnv: "production", AppKey: "k"}, db)
	assert.Equal(t, gin.ReleaseMode, gin.Mode())
}

func TestPublicEndpoints(t *testing.T) {
	f := newFixture(t)

	cats := f.do("GET", "/api/public/categories", "", nil)
	assert.Equal(t, 200, cats.Code)
	assert.JSONEq(t, `["Teknologi","Pendidikan","Gaya Hidup","Bisnis","Opini","Umum"]`, string(cats.Data))

	var posts []struct {
		Slug        string `json:"slug"`
		Category    string `json:"category"`
		IsPublished bool   `json:"is_published"`
		ReadingTime int    `json:"reading_time"`
		AuthorName  string `json:"author_name"`
	}
	list := f.do("GET", "/api/public/posts", "", nil)
	require.Equal(t, 200, list.Code)
	require.NoError(t, json.Unmarshal(list.Data, &posts))
	assert.Len(t, posts, 7, "hanya artikel terbit dari seeder")
	assert.NotContains(t, string(list.Data), "user_id", "respons publik tanpa user_id")
	for _, p := range posts {
		assert.True(t, p.IsPublished)
		assert.GreaterOrEqual(t, p.ReadingTime, 1)
		assert.NotEmpty(t, p.AuthorName)
	}

	_ = json.Unmarshal(f.do("GET", "/api/public/posts?q=CLEAN+architecture", "", nil).Data, &posts)
	require.Len(t, posts, 1)
	assert.Equal(t, "mengenal-clean-architecture-pada-aplikasi-go", posts[0].Slug)
	_ = json.Unmarshal(f.do("GET", "/api/public/posts?category=Bisnis", "", nil).Data, &posts)
	assert.Len(t, posts, 1)

	assert.Equal(t, 200, f.do("GET", "/api/public/posts/selamat-datang-di-delcom-blog", "", nil).Code)
	assert.Equal(t, 404, f.do("GET", "/api/public/posts/rencana-belajar-kubernetes-untuk-pemula", "", nil).Code, "draf tidak boleh publik")
}

func TestAuthFlow(t *testing.T) {
	f := newFixture(t)

	reg := f.do("POST", "/api/auth/register", "", gin.H{"username": "budi", "email": "budi@contoh.id", "password": "rahasia1", "role": "admin"})
	require.Equal(t, 201, reg.Code)
	assert.NotContains(t, string(reg.Data), "password")
	assert.Contains(t, string(reg.Data), `"role":"admin"`)
	assert.Contains(t, string(reg.Data), `"token":"`)
	assert.Equal(t, 400, f.do("POST", "/api/auth/register", "", gin.H{"username": "budi", "email": "lain@contoh.id", "password": "rahasia1"}).Code)

	token := f.login(t, "budi@contoh.id", "rahasia1")
	assert.Equal(t, 200, f.do("GET", "/api/auth/profile", token, nil).Code)
	assert.Equal(t, 200, f.do("PUT", "/api/auth/profile", token, gin.H{"email": "baru@contoh.id"}).Code)
	assert.Equal(t, 200, f.do("POST", "/api/auth/logout", token, nil).Code)

	assert.Equal(t, 401, f.do("GET", "/api/auth/profile", "", nil).Code)
	assert.Equal(t, 401, f.do("POST", "/api/auth/logout", "", nil).Code)
	bad := f.do("POST", "/api/auth/login", "", gin.H{"username": "budi", "password": "salah"})
	assert.Equal(t, 401, bad.Code)
	unknown := f.do("POST", "/api/auth/login", "", gin.H{"username": "hantu", "password": "salah"})
	assert.Equal(t, bad.Message, unknown.Message)
}

func TestAuthorWorkflowAndOwnership(t *testing.T) {
	f := newFixture(t)
	member := f.login(t, "member", "member")
	admin := f.login(t, "admin", "admin")

	assert.Equal(t, 401, f.do("GET", "/api/posts", "", nil).Code)

	var before struct {
		Total       int `json:"total_articles"`
		TotalTerbit int `json:"total_terbit"`
	}
	require.NoError(t, json.Unmarshal(f.do("GET", "/api/posts/stats", member, nil).Data, &before))
	assert.Equal(t, 5, before.Total)

	created := f.do("POST", "/api/posts", member, gin.H{"title": "Catatan Baru", "content": strings.Repeat("kata ", 201), "category": "Opini"})
	require.Equal(t, 201, created.Code)
	var p struct {
		ID          int
		Slug        string
		ReadingTime int  `json:"reading_time"`
		IsPublished bool `json:"is_published"`
	}
	require.NoError(t, json.Unmarshal(created.Data, &p))
	assert.Equal(t, "catatan-baru", p.Slug)
	assert.Equal(t, 2, p.ReadingTime)
	assert.False(t, p.IsPublished)

	path := fmt.Sprintf("/api/posts/%d", p.ID)
	assert.Equal(t, 403, f.do("GET", path, admin, nil).Code, "milik orang lain → 403")
	assert.Equal(t, 403, f.do("PUT", path, admin, gin.H{"title": "x", "content": "x"}).Code)
	assert.Equal(t, 403, f.do("PATCH", path+"/toggle-publish", admin, nil).Code)
	assert.Equal(t, 403, f.do("DELETE", path, admin, nil).Code)
	assert.Equal(t, 404, f.do("GET", "/api/posts/99999999", admin, nil).Code, "ID tidak ada → 404")

	assert.Equal(t, 404, f.do("GET", "/api/public/posts/catatan-baru", "", nil).Code)
	assert.Equal(t, 200, f.do("PATCH", path+"/toggle-publish", member, nil).Code)
	assert.Equal(t, 200, f.do("GET", "/api/public/posts/catatan-baru", "", nil).Code)

	var after struct {
		Total        int `json:"total_articles"`
		TotalTerbit  int `json:"total_terbit"`
		TotalDraf    int `json:"total_draf"`
		TotalSelesai int `json:"total_selesai"`
		BelumSelesai int `json:"belum_selesai"`
	}
	require.NoError(t, json.Unmarshal(f.do("GET", "/api/posts/stats", member, nil).Data, &after))
	assert.Equal(t, before.Total+1, after.Total)
	assert.Equal(t, before.TotalTerbit+1, after.TotalTerbit)
	assert.Equal(t, after.TotalTerbit, after.TotalSelesai)
	assert.Equal(t, after.TotalDraf, after.BelumSelesai)

	mine := f.do("GET", "/api/posts", member, nil)
	assert.Equal(t, 200, mine.Code)
	assert.Equal(t, 200, f.do("PUT", path, member, gin.H{"title": "Catatan Final", "content": "isi"}).Code)
	assert.Equal(t, 200, f.do("DELETE", path, member, nil).Code)
	assert.Equal(t, 404, f.do("GET", path, member, nil).Code)
}

func TestAdminRBAC(t *testing.T) {
	f := newFixture(t)
	member := f.login(t, "member", "member")
	admin := f.login(t, "admin", "admin")

	for _, p := range []string{"/api/admin/users", "/api/admin/posts", "/api/admin/users/1/posts"} {
		assert.Equal(t, 401, f.do("GET", p, "", nil).Code, p)
		assert.Equal(t, 403, f.do("GET", p, member, nil).Code, p)
		assert.Equal(t, 200, f.do("GET", p, admin, nil).Code, p)
	}
	assert.Equal(t, 200, f.do("GET", "/api/admin/users/9999/posts", admin, nil).Code, "pengguna tidak ada → daftar kosong")

	var users []struct {
		Username       string
		TotalPosts     int `json:"total_articles"`
		TotalPublished int `json:"total_published"`
	}
	require.NoError(t, json.Unmarshal(f.do("GET", "/api/admin/users", admin, nil).Data, &users))
	require.Len(t, users, 2)
	total := 0
	for _, u := range users {
		total += u.TotalPosts
	}
	assert.Equal(t, 10, total)

	var all []struct{ Author struct{ Username string } }
	require.NoError(t, json.Unmarshal(f.do("GET", "/api/admin/posts", admin, nil).Data, &all))
	assert.Len(t, all, 10)
}

func TestAIGenerateThroughRouter(t *testing.T) {
	f := newFixture(t)
	token := f.login(t, "member", "member")

	assert.Equal(t, 401, f.do("POST", "/api/posts/ai-generate", "", gin.H{"topic": "x"}).Code)
	blank := f.do("POST", "/api/posts/ai-generate", token, gin.H{"topic": " "})
	assert.Equal(t, 400, blank.Code)
	assert.Contains(t, strings.ToLower(blank.Message), "topic")

	res := f.do("POST", "/api/posts/ai-generate", token, gin.H{"topic": "Danau Toba", "category": "Umum", "include_web_search": true})
	require.Equal(t, 200, res.Code, res.Message)
	var data struct {
		Title, Category, Excerpt, Content string
		SearchSources                     []struct{ Title, URL, Snippet string } `json:"search_sources"`
	}
	require.NoError(t, json.Unmarshal(res.Data, &data))
	assert.Equal(t, "Artikel AI", data.Title)
	assert.Equal(t, "Opini", data.Category)
	require.Len(t, data.SearchSources, 1)
	assert.Equal(t, "https://toba.id", data.SearchSources[0].URL)

	// Hasil AI tidak otomatis tersimpan.
	var stats struct {
		Total int `json:"total_articles"`
	}
	require.NoError(t, json.Unmarshal(f.do("GET", "/api/posts/stats", token, nil).Data, &stats))
	assert.Equal(t, 5, stats.Total)

	// Tanpa web search: sumber kosong.
	res = f.do("POST", "/api/posts/ai-generate", token, gin.H{"topic": "Danau Toba"})
	require.Equal(t, 200, res.Code)
	assert.Contains(t, string(res.Data), `"search_sources":[]`)

	// OpenAI mati → 500 status error dengan pesan yang menyebut OpenAI.
	f.openai.Close()
	down := f.do("POST", "/api/posts/ai-generate", token, gin.H{"topic": "Danau Toba"})
	assert.Equal(t, 500, down.Code)
	assert.Equal(t, "error", down.Status)
	assert.Contains(t, strings.ToLower(down.Message), "openai")
}

func TestStaticRoutesDoNotClashWithID(t *testing.T) {
	f := newFixture(t)
	token := f.login(t, "member", "member")
	assert.Equal(t, 200, f.do("GET", "/api/posts/stats", token, nil).Code)
	// GET /api/posts/ai-generate jatuh ke /:id (ID bukan angka), sedangkan POST menuju handler AI.
	assert.Equal(t, 400, f.do("GET", "/api/posts/ai-generate", token, nil).Code)
	assert.Equal(t, 400, f.do("POST", "/api/posts/ai-generate", token, gin.H{"topic": ""}).Code)
}
'@

Write-Host 'Selesai. Lanjut: go build -o server . ; go vet ./... ; go test -cover ./...'
