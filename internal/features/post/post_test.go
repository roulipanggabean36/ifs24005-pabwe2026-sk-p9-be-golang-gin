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

func TestOwnershipReturnsNotFound(t *testing.T) {
	e := newEnv(t)
	p := e.create(t, e.alice.ID, "Milik Alice", "x", false)

	_, err := e.svc.Get(e.bob.ID, p.ID)
	assert.ErrorIs(t, err, ErrPostNotFound)
	_, err = e.svc.Update(e.bob.ID, p.ID, PostRequest{Title: "Curian", Content: "x"})
	assert.ErrorIs(t, err, ErrPostNotFound)
	_, err = e.svc.TogglePublish(e.bob.ID, p.ID)
	assert.ErrorIs(t, err, ErrPostNotFound)
	assert.ErrorIs(t, e.svc.Delete(e.bob.ID, p.ID), ErrPostNotFound)

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
	_, err = e.svc.AdminUserPosts(4242)
	assert.ErrorIs(t, err, ErrUserNotFound)
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
		"FindUser:adminposts":     func(s Service) error { _, err := s.AdminUserPosts(e.alice.ID); return err },
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
	assert.Contains(t, string(res.Data), `"author":{"id":`)
	code, _ = send(r, "GET", "/public/posts/tidak-ada", nil)
	assert.Equal(t, 404, code)

	path := fmt.Sprintf("/posts/%d", created.ID)
	code, _ = send(r, "GET", "/posts", nil)
	assert.Equal(t, 200, code)
	code, res = send(r, "GET", "/posts/stats", nil)
	assert.Equal(t, 200, code)
	assert.JSONEq(t, `{"total":1,"total_terbit":1,"total_draf":0,"total_selesai":1,"belum_selesai":0}`, string(res.Data))
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
	assert.Contains(t, string(res.Data), `"total_posts":1`)
	assert.Contains(t, string(res.Data), `"total_published":1`)
	code, _ = send(r, "GET", "/admin/posts", nil)
	assert.Equal(t, 200, code)
	code, _ = send(r, "GET", fmt.Sprintf("/admin/users/%d/posts", e.alice.ID), nil)
	assert.Equal(t, 200, code)
	code, res = send(r, "GET", "/admin/users/4242/posts", nil)
	assert.Equal(t, 404, code)
	assert.Equal(t, "Pengguna tidak ditemukan", res.Message)
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
		{"GET", "/admin/users/1/posts", "FindUser"},
	}
	for _, tc := range cases {
		r := engine(e.failing(tc.fail), e.alice.ID)
		code, res := send(r, tc.method, tc.path, gin.H{"title": "Ada", "content": "x"})
		assert.Equal(t, http.StatusInternalServerError, code, tc.path)
		assert.Equal(t, "error", res.Status, tc.path)
		assert.Equal(t, "Terjadi kesalahan pada server", res.Message, tc.path)
	}
}
