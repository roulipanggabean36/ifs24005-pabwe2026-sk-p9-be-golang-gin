package database

import (
	"errors"
	"path/filepath"
	"testing"
	"time"

	"app/internal/config"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
	"golang.org/x/crypto/bcrypt"
	"gorm.io/gorm"
)

func testCfg() *config.Config {
	return &config.Config{AdminUsername: "admin", AdminPassword: "admin"}
}

func newDB(t *testing.T) *gorm.DB {
	db, err := ConnectTest()
	require.NoError(t, err)
	return db
}

func TestSQLiteDSN(t *testing.T) {
	assert.Equal(t, "file::memory:?cache=shared&_pragma=foreign_keys(1)", sqliteDSN(""))
	assert.Equal(t, "file::memory:?cache=shared&_pragma=foreign_keys(1)", sqliteDSN(":memory:"))
	assert.Equal(t, "file:a.db?_pragma=foreign_keys(1)", sqliteDSN("a.db"))
	assert.Equal(t, "file:a.db?_pragma=foreign_keys(1)", sqliteDSN("file:a.db"))
	assert.Equal(t, "file:a.db?mode=rw&_pragma=foreign_keys(1)", sqliteDSN("file:a.db?mode=rw"))
}

func TestConnectSQLite(t *testing.T) {
	db, err := Connect(&config.Config{DBConnection: "SQLite", DBDatabase: ":memory:"})
	require.NoError(t, err)
	require.NoError(t, Migrate(db))
	memDB, _ := db.DB()
	t.Cleanup(func() { _ = memDB.Close() })

	file := filepath.Join(t.TempDir(), "blog.db")
	db, err = Connect(&config.Config{DBConnection: "sqlite", DBDatabase: file})
	require.NoError(t, err)
	require.NoError(t, Migrate(db))
	fileDB, _ := db.DB()
	t.Cleanup(func() { _ = fileDB.Close() })
}

func TestConnectSQLiteError(t *testing.T) {
	_, err := Connect(&config.Config{DBConnection: "sqlite", DBDatabase: filepath.Join(t.TempDir(), "tidak", "ada", "x.db")})
	assert.Error(t, err)
}

func TestConnectPostgresError(t *testing.T) {
	_, err := Connect(&config.Config{
		DBConnection: "pgsql", DBHost: "127.0.0.1", DBPort: "1", DBUsername: "u",
		DBPassword: "p", DBDatabase: "d", DBSSLMode: "disable",
	})
	assert.Error(t, err)
}

func TestOpenAndMigrateErrors(t *testing.T) {
	_, err := openAndMigrate("file:" + filepath.Join(t.TempDir(), "tidak", "ada", "x.db"))
	assert.Error(t, err)

	// Basis data read-only: koneksi berhasil, tetapi migrasi gagal.
	file := filepath.Join(t.TempDir(), "ro.db")
	seed, err := Connect(&config.Config{DBConnection: "sqlite", DBDatabase: file})
	require.NoError(t, err)
	seedDB, _ := seed.DB()
	t.Cleanup(func() { _ = seedDB.Close() })
	require.NoError(t, seed.Exec("CREATE TABLE kosong (id integer)").Error)
	_, err = openAndMigrate("file:" + file + "?mode=ro")
	assert.Error(t, err)
}

func TestConnectTestIsolated(t *testing.T) {
	a, b := newDB(t), newDB(t)
	require.NoError(t, a.Create(&User{Username: "u", Email: "u@x.id", Password: "p"}).Error)
	var n int64
	require.NoError(t, b.Model(&User{}).Count(&n).Error)
	assert.Zero(t, n)
}

func TestSeedCreatesAccountsAndArticles(t *testing.T) {
	db := newDB(t)
	require.NoError(t, Seed(db, &config.Config{AdminUsername: "Root", AdminPassword: "rahasia"}))

	var admin, member User
	require.NoError(t, db.Where("role = ?", RoleAdmin).First(&admin).Error)
	require.NoError(t, db.Where("username = ?", "member").First(&member).Error)
	assert.Equal(t, "Root", admin.Username)
	assert.Equal(t, "root@delcom.org", admin.Email)
	assert.NoError(t, bcrypt.CompareHashAndPassword([]byte(admin.Password), []byte("rahasia")))
	assert.NoError(t, bcrypt.CompareHashAndPassword([]byte(member.Password), []byte("member")))
	assert.Equal(t, RoleMember, member.Role)

	var posts []Post
	require.NoError(t, db.Find(&posts).Error)
	assert.Len(t, posts, len(seedArticles))

	categories := map[string]bool{}
	owners := map[uint]bool{}
	published, drafts := 0, 0
	for _, p := range posts {
		categories[p.Category] = true
		owners[p.UserID] = true
		if p.IsPublished {
			published++
			assert.NotNil(t, p.PublishedAt)
		} else {
			drafts++
			assert.Nil(t, p.PublishedAt)
		}
	}
	assert.Len(t, categories, 6)
	assert.Len(t, owners, 2)
	assert.Positive(t, published)
	assert.Positive(t, drafts)
}

func TestSeedIsIdempotent(t *testing.T) {
	db := newDB(t)
	require.NoError(t, Seed(db, testCfg()))
	require.NoError(t, Seed(db, testCfg()))

	var users, posts int64
	require.NoError(t, db.Model(&User{}).Count(&users).Error)
	require.NoError(t, db.Model(&Post{}).Count(&posts).Error)
	assert.EqualValues(t, 2, users)
	assert.EqualValues(t, len(seedArticles), posts)
}

func TestSeedUsesClock(t *testing.T) {
	fixed := time.Date(2026, 1, 10, 0, 0, 0, 0, time.UTC)
	old := nowFunc
	nowFunc = func() time.Time { return fixed }
	t.Cleanup(func() { nowFunc = old })

	db := newDB(t)
	require.NoError(t, Seed(db, testCfg()))
	var p Post
	require.NoError(t, db.Where("slug = ?", "selamat-datang-di-delcom-blog").First(&p).Error)
	assert.True(t, p.CreatedAt.Before(fixed))
}

func TestSeedAdminLookupError(t *testing.T) {
	db := newDB(t)
	require.NoError(t, db.Migrator().DropTable(&Post{}, &User{}))
	assert.Error(t, Seed(db, testCfg()))
}

func TestSeedMemberCreateError(t *testing.T) {
	db := newDB(t)
	// Email milik "member" sudah dipakai akun lain sehingga pembuatan akun member gagal.
	require.NoError(t, db.Create(&User{Username: "lain", Email: "member@delcom.org", Password: "x"}).Error)
	assert.Error(t, Seed(db, testCfg()))
}

func TestEnsureUserHashError(t *testing.T) {
	old := hashPassword
	hashPassword = func([]byte, int) ([]byte, error) { return nil, errors.New("hash gagal") }
	t.Cleanup(func() { hashPassword = old })

	_, err := ensureUser(newDB(t), "x", "x@x.id", "pw", RoleMember)
	assert.EqualError(t, err, "hash gagal")
}

func TestEnsureUserReturnsExisting(t *testing.T) {
	db := newDB(t)
	first, err := ensureUser(db, "x", "x@x.id", "pw", RoleMember)
	require.NoError(t, err)
	second, err := ensureUser(db, "x", "lain@x.id", "pw2", RoleAdmin)
	require.NoError(t, err)
	assert.Equal(t, first.ID, second.ID)
	assert.Equal(t, RoleMember, second.Role)
}

func TestSeedPostsCountError(t *testing.T) {
	db := newDB(t)
	require.NoError(t, db.Migrator().DropTable(&Post{}))
	assert.Error(t, seedPosts(db, map[string]uint{}))
}

func TestSeedPostsCreateError(t *testing.T) {
	db := newDB(t)
	require.NoError(t, db.Callback().Create().Before("gorm:create").Register("gagal_posts", func(tx *gorm.DB) {
		if tx.Statement.Table == "posts" {
			_ = tx.AddError(errors.New("insert gagal"))
		}
	}))
	assert.Error(t, Seed(db, testCfg()))
}

func TestDeleteUserCascadesPosts(t *testing.T) {
	db := newDB(t)
	require.NoError(t, Seed(db, testCfg()))

	var member User
	require.NoError(t, db.Where("username = ?", "member").First(&member).Error)
	require.NoError(t, db.Delete(&member).Error)

	var left int64
	require.NoError(t, db.Model(&Post{}).Where("user_id = ?", member.ID).Count(&left).Error)
	assert.Zero(t, left)
	require.NoError(t, db.Model(&Post{}).Count(&left).Error)
	assert.Positive(t, left)
}

func TestPostSlugIsUnique(t *testing.T) {
	db := newDB(t)
	u := User{Username: "u", Email: "u@x.id", Password: "p"}
	require.NoError(t, db.Create(&u).Error)
	require.NoError(t, db.Create(&Post{UserID: u.ID, Title: "A", Slug: "a", Content: "x"}).Error)
	assert.Error(t, db.Create(&Post{UserID: u.ID, Title: "B", Slug: "a", Content: "x"}).Error)
}
