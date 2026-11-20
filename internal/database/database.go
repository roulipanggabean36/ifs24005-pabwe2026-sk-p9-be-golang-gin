package database

import (
	"errors"
	"fmt"
	"log"
	"os"
	"strings"
	"sync/atomic"
	"time"

	"app/internal/config"

	"github.com/glebarez/sqlite"
	"golang.org/x/crypto/bcrypt"
	"gorm.io/driver/postgres"
	"gorm.io/gorm"
	"gorm.io/gorm/logger"
)

// Peran pengguna.
const (
	RoleAdmin  = "admin"
	RoleMember = "member"
)

// User adalah model tabel users.
type User struct {
	ID        uint   `gorm:"primaryKey"`
	Username  string `gorm:"type:varchar(255);uniqueIndex;not null"`
	Email     string `gorm:"type:varchar(255);uniqueIndex;not null"`
	Password  string `gorm:"type:text;not null" json:"-"`
	Role      string `gorm:"type:varchar(50);not null;default:member"`
	CreatedAt time.Time
	UpdatedAt time.Time
}

// Post adalah model tabel posts. Menghapus user ikut menghapus artikelnya (ON DELETE CASCADE).
type Post struct {
	ID             uint   `gorm:"primaryKey"`
	UserID         uint   `gorm:"not null;index"`
	User           User   `gorm:"foreignKey:UserID;references:ID;constraint:OnDelete:CASCADE"`
	Title          string `gorm:"type:varchar(255);not null"`
	Slug           string `gorm:"type:varchar(255);uniqueIndex;not null"`
	Category       string `gorm:"type:varchar(100);not null;default:Umum"`
	Excerpt        string `gorm:"type:text"`
	Content        string `gorm:"type:text;not null"`
	CoverImagePath string `gorm:"type:text"`
	IsPublished    bool   `gorm:"not null;default:false"`
	PublishedAt    *time.Time
	CreatedAt      time.Time
	UpdatedAt      time.Time
}

// Dapat diganti saat pengujian untuk menjangkau cabang error.
var (
	hashPassword = bcrypt.GenerateFromPassword
	nowFunc      = time.Now
	testDBSeq    atomic.Int64
)

const sqlitePragma = "_pragma=foreign_keys(1)"

func gormConfig() *gorm.Config {
	return &gorm.Config{
		Logger: logger.New(log.New(os.Stdout, "\r\n", log.LstdFlags), logger.Config{
			SlowThreshold:             time.Second,
			LogLevel:                  logger.Warn,
			IgnoreRecordNotFoundError: true,
		}),
	}
}

// sqliteDSN membangun DSN SQLite dengan foreign key aktif agar cascade berfungsi.
func sqliteDSN(name string) string {
	switch {
	case name == "" || name == ":memory:":
		return "file::memory:?cache=shared&" + sqlitePragma
	case strings.HasPrefix(name, "file:") && strings.Contains(name, "?"):
		return name + "&" + sqlitePragma
	case strings.HasPrefix(name, "file:"):
		return name + "?" + sqlitePragma
	default:
		return "file:" + name + "?" + sqlitePragma
	}
}

// Connect membuka koneksi sesuai DB_CONNECTION (pgsql bawaan, atau sqlite).
func Connect(cfg *config.Config) (*gorm.DB, error) {
	if strings.EqualFold(cfg.DBConnection, "sqlite") {
		return gorm.Open(sqlite.Open(sqliteDSN(cfg.DBDatabase)), gormConfig())
	}
	return gorm.Open(postgres.Open(cfg.DSN()), gormConfig())
}

// ConnectTest membuka basis data SQLite in-memory yang terisolasi (untuk pengujian) dan memigrasikannya.
func ConnectTest() (*gorm.DB, error) {
	name := fmt.Sprintf("file:memdb%d?mode=memory&cache=shared", testDBSeq.Add(1))
	return openAndMigrate(name)
}

func openAndMigrate(dsn string) (*gorm.DB, error) {
	sep := "?"
	if strings.Contains(dsn, "?") {
		sep = "&"
	}
	db, err := gorm.Open(sqlite.Open(dsn+sep+sqlitePragma), gormConfig())
	if err != nil {
		return nil, err
	}
	if err := Migrate(db); err != nil {
		sqlDB, _ := db.DB()
		_ = sqlDB.Close()
		return nil, err
	}
	return db, nil
}

// Migrate menjalankan AutoMigrate untuk seluruh model.
func Migrate(db *gorm.DB) error {
	return db.AutoMigrate(&User{}, &Post{})
}

// Seed mengisi akun bawaan dan artikel contoh. Aman dijalankan berulang kali.
func Seed(db *gorm.DB, cfg *config.Config) error {
	admin, err := ensureUser(db, cfg.AdminUsername, strings.ToLower(cfg.AdminUsername)+"@delcom.org", cfg.AdminPassword, RoleAdmin)
	if err != nil {
		return err
	}
	member, err := ensureUser(db, "member", "member@delcom.org", "member", RoleMember)
	if err != nil {
		return err
	}
	owners := map[string]uint{RoleAdmin: admin.ID, RoleMember: member.ID}
	return seedPosts(db, owners)
}

func ensureUser(db *gorm.DB, username, email, password, role string) (*User, error) {
	var user User
	err := db.Where("username = ?", username).First(&user).Error
	if err == nil {
		return &user, nil
	}
	if !errors.Is(err, gorm.ErrRecordNotFound) {
		return nil, err
	}

	hash, err := hashPassword([]byte(password), bcrypt.DefaultCost)
	if err != nil {
		return nil, err
	}
	user = User{Username: username, Email: email, Password: string(hash), Role: role}
	if err := db.Create(&user).Error; err != nil {
		return nil, err
	}
	return &user, nil
}

type seedPost struct {
	Slug, Title, Category, Excerpt, Content, Owner string
	Published                                      bool
	DaysAgo                                        int
}

func seedPosts(db *gorm.DB, owners map[string]uint) error {
	now := nowFunc()
	for _, sp := range seedArticles {
		var count int64
		if err := db.Model(&Post{}).Where("slug = ?", sp.Slug).Count(&count).Error; err != nil {
			return err
		}
		if count > 0 {
			continue
		}
		created := now.AddDate(0, 0, -sp.DaysAgo)
		post := Post{
			UserID: owners[sp.Owner], Title: sp.Title, Slug: sp.Slug, Category: sp.Category,
			Excerpt: sp.Excerpt, Content: sp.Content, IsPublished: sp.Published,
			CreatedAt: created, UpdatedAt: created,
		}
		if sp.Published {
			post.PublishedAt = &created
		}
		if err := db.Create(&post).Error; err != nil {
			return err
		}
	}
	return nil
}

var seedArticles = []seedPost{
	{
		Slug: "selamat-datang-di-delcom-blog", Title: "Selamat Datang di Delcom Blog", Category: "Umum", Owner: RoleAdmin, Published: true, DaysAgo: 30,
		Excerpt: "Delcom Blog adalah ruang terbuka untuk berbagi gagasan, pengalaman, dan pengetahuan lintas bidang.",
		Content: `# Selamat Datang di Delcom Blog

Delcom Blog adalah platform publikasi artikel yang dibangun untuk siapa saja yang ingin **menulis** dan **membaca** dengan nyaman.

## Apa yang bisa dilakukan di sini?

- Membaca artikel dari berbagai kategori tanpa perlu login.
- Menulis artikel dengan editor Markdown yang mendukung pratinjau langsung.
- Menyimpan tulisan sebagai draf, lalu menerbitkannya kapan pun siap.
- Meminta bantuan asisten AI untuk menyusun kerangka artikel berbasis informasi terkini.

Silakan daftar, mulai menulis, dan jadikan blog ini rumah bagi gagasan Anda.`,
	},
	{
		Slug: "mengenal-clean-architecture-pada-aplikasi-go", Title: "Mengenal Clean Architecture pada Aplikasi Go", Category: "Teknologi", Owner: RoleAdmin, Published: true, DaysAgo: 24,
		Excerpt: "Memisahkan handler, service, dan repository membuat kode Go lebih mudah diuji dan dirawat.",
		Content: `# Mengenal Clean Architecture pada Aplikasi Go

Clean Architecture memisahkan tanggung jawab kode ke dalam lapisan yang jelas sehingga perubahan di satu lapisan tidak merambat ke lapisan lain.

## Lapisan utama

1. **Handler** menerima request HTTP dan menyusun respons.
2. **Service** memuat aturan bisnis, misalnya validasi dan penghitungan.
3. **Repository** mengurus akses ke basis data.

## Mengapa penting?

Karena service hanya bergantung pada *interface* repository, kita dapat mengganti basis data atau membuat tiruan (mock) saat pengujian tanpa mengubah logika bisnis.

> Kode yang mudah diuji hampir selalu kode yang tertata dengan baik.

Pendekatan **feature-first** melengkapinya: seluruh berkas satu fitur dikelompokkan dalam satu folder.`,
	},
	{
		Slug: "rencana-belajar-kubernetes-untuk-pemula", Title: "Rencana Belajar Kubernetes untuk Pemula", Category: "Teknologi", Owner: RoleMember, Published: false, DaysAgo: 5,
		Excerpt: "Draf peta belajar Kubernetes selama delapan minggu, dari konsep dasar hingga deployment pertama.",
		Content: `# Rencana Belajar Kubernetes untuk Pemula

*Draf — masih disempurnakan.*

## Minggu 1-2: Fondasi

- Memahami kontainer dan perbedaannya dengan mesin virtual.
- Mencoba membuat image sederhana.

## Minggu 3-5: Konsep inti

- Pod, Deployment, dan Service.
- ConfigMap dan Secret.

## Minggu 6-8: Praktik

- Men-deploy aplikasi web beserta basis datanya.
- Membaca log dan melakukan pemecahan masalah dasar.`,
	},
	{
		Slug: "teknik-belajar-aktif-untuk-mahasiswa-informatika", Title: "Teknik Belajar Aktif untuk Mahasiswa Informatika", Category: "Pendidikan", Owner: RoleMember, Published: true, DaysAgo: 20,
		Excerpt: "Belajar pemrograman paling efektif ketika kita langsung mempraktikkan dan menjelaskannya kembali.",
		Content: `# Teknik Belajar Aktif untuk Mahasiswa Informatika

Membaca materi saja jarang cukup. Pemahaman tumbuh ketika kita **mengerjakan** dan **menjelaskan**.

## Tiga kebiasaan yang membantu

1. **Praktik langsung.** Setelah mempelajari satu konsep, segera tulis kode kecil yang memakainya.
2. **Mengajar teman.** Menjelaskan ulang dengan kata-kata sendiri memperlihatkan bagian yang belum dipahami.
3. **Pengulangan berjarak.** Tinjau kembali catatan pada hari ke-1, ke-3, dan ke-7.

Mulailah dari proyek kecil dan tingkatkan kesulitannya sedikit demi sedikit.`,
	},
	{
		Slug: "mengapa-menulis-catatan-kuliah-dengan-markdown", Title: "Mengapa Menulis Catatan Kuliah dengan Markdown?", Category: "Pendidikan", Owner: RoleAdmin, Published: true, DaysAgo: 15,
		Excerpt: "Markdown membuat catatan ringan, rapi, dan dapat dibuka di perangkat apa pun.",
		Content: `# Mengapa Menulis Catatan Kuliah dengan Markdown?

Markdown adalah format teks sederhana yang diubah menjadi tampilan rapi.

## Keuntungannya

- **Ringan**: berkas hanya berupa teks biasa.
- **Portabel**: terbuka di editor mana pun.
- **Fokus**: Anda menulis isi, bukan sibuk mengatur tampilan.

## Contoh singkat

Gunakan tanda pagar untuk judul, tanda bintang untuk cetak tebal, dan tanda hubung untuk daftar. Hanya itu yang dibutuhkan untuk memulai.`,
	},
	{
		Slug: "rutinitas-pagi-produktif-tanpa-menguras-energi", Title: "Rutinitas Pagi Produktif Tanpa Menguras Energi", Category: "Gaya Hidup", Owner: RoleMember, Published: true, DaysAgo: 12,
		Excerpt: "Rutinitas pagi yang sederhana lebih mudah dijaga daripada daftar panjang yang melelahkan.",
		Content: `# Rutinitas Pagi Produktif Tanpa Menguras Energi

Tidak perlu bangun pukul empat pagi untuk produktif. Yang terpenting adalah **konsistensi**.

## Mulai dari tiga langkah

1. Minum segelas air putih setelah bangun.
2. Bergerak ringan selama sepuluh menit.
3. Tulis tiga prioritas hari ini.

Bila terasa berat, kurangi satu langkah. Rutinitas yang bertahan lebih berharga daripada rutinitas yang ambisius.`,
	},
	{
		Slug: "menata-meja-kerja-rumah-yang-nyaman", Title: "Menata Meja Kerja Rumah yang Nyaman", Category: "Gaya Hidup", Owner: RoleAdmin, Published: false, DaysAgo: 3,
		Excerpt: "Draf tips menata pencahayaan, kursi, dan kabel agar bekerja dari rumah terasa nyaman.",
		Content: `# Menata Meja Kerja Rumah yang Nyaman

*Draf — belum terbit.*

- Letakkan meja dekat jendela agar cahaya alami cukup.
- Pilih kursi yang menopang punggung bawah.
- Rapikan kabel supaya area kerja tidak terasa sesak.`,
	},
	{
		Slug: "dasar-dasar-menyusun-laporan-keuangan-umkm", Title: "Dasar-Dasar Menyusun Laporan Keuangan UMKM", Category: "Bisnis", Owner: RoleAdmin, Published: true, DaysAgo: 9,
		Excerpt: "Pencatatan sederhana yang rutin membantu pelaku UMKM memahami kondisi usahanya.",
		Content: `# Dasar-Dasar Menyusun Laporan Keuangan UMKM

Laporan keuangan membantu pemilik usaha mengambil keputusan berdasarkan data, bukan perkiraan.

## Tiga laporan pokok

| Laporan | Fungsi |
|---|---|
| Laba rugi | Menunjukkan untung atau rugi dalam satu periode |
| Neraca | Memperlihatkan harta, utang, dan modal |
| Arus kas | Mencatat uang masuk dan keluar |

## Tips awal

- Pisahkan uang pribadi dan uang usaha.
- Catat setiap transaksi pada hari yang sama.
- Tinjau laporan setiap akhir bulan.`,
	},
	{
		Slug: "apakah-ai-akan-menggantikan-penulis", Title: "Apakah AI Akan Menggantikan Penulis?", Category: "Opini", Owner: RoleMember, Published: true, DaysAgo: 6,
		Excerpt: "AI mempercepat penyusunan draf, tetapi sudut pandang dan tanggung jawab tetap milik penulis.",
		Content: `# Apakah AI Akan Menggantikan Penulis?

Pertanyaan ini muncul setiap kali alat baru hadir. Menurut saya, jawabannya: **tidak sepenuhnya, tetapi cara menulis akan berubah**.

## Yang dapat dibantu AI

- Menyusun kerangka dan draf awal.
- Merangkum bahan bacaan yang panjang.

## Yang tetap milik penulis

- Sudut pandang dan pengalaman pribadi.
- Verifikasi fakta serta tanggung jawab atas isi tulisan.

AI adalah alat bantu. Kualitas akhir tetap ditentukan oleh penulis yang menyuntingnya.`,
	},
	{
		Slug: "catatan-perjalanan-ke-danau-toba", Title: "Catatan Perjalanan ke Danau Toba", Category: "Umum", Owner: RoleMember, Published: false, DaysAgo: 2,
		Excerpt: "Draf catatan perjalanan menyusuri tepian Danau Toba dari Balige.",
		Content: `# Catatan Perjalanan ke Danau Toba

*Draf — foto dan rute masih dikumpulkan.*

Perjalanan dimulai pagi hari dari Balige. Udara sejuk dan permukaan danau tampak tenang.

- Singgah di pasar tradisional.
- Menikmati matahari terbenam di tepi danau.`,
	},
}
