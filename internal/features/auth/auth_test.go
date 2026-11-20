package auth

import (
	"bytes"
	"encoding/json"
	"errors"
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
	u, err := svc.Register(RegisterRequest{Username: username, Email: email, Password: password})
	require.NoError(t, err)
	return u
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
	u, err := svc.Register(RegisterRequest{Username: "  Siti  ", Email: " Siti@Contoh.ID ", Password: "rahasia1"})
	require.NoError(t, err)
	assert.Equal(t, "Siti", u.Username)
	assert.Equal(t, "siti@contoh.id", u.Email)
	assert.Equal(t, "member", u.Role)

	var stored database.User
	require.NoError(t, db.First(&stored, u.ID).Error)
	assert.NotEqual(t, "rahasia1", stored.Password)
	assert.NoError(t, bcrypt.CompareHashAndPassword([]byte(stored.Password), []byte("rahasia1")))
}

func TestRegisterValidation(t *testing.T) {
	svc, _, _ := newSvc(t)
	long := strings.Repeat("a", 251) + "@x.id"
	cases := []struct {
		name string
		req  RegisterRequest
		msg  string
	}{
		{"username kosong", RegisterRequest{"", "a@b.id", "123456"}, "Username wajib diisi"},
		{"username pendek", RegisterRequest{"ab", "a@b.id", "123456"}, "Username harus 3-50 karakter"},
		{"username panjang", RegisterRequest{strings.Repeat("a", 51), "a@b.id", "123456"}, "Username harus 3-50 karakter"},
		{"username simbol", RegisterRequest{"bud i", "a@b.id", "123456"}, "Username hanya boleh berisi huruf, angka, titik, garis bawah, dan strip"},
		{"email kosong", RegisterRequest{"budi", "  ", "123456"}, "Email wajib diisi"},
		{"email salah", RegisterRequest{"budi", "bukan-email", "123456"}, "Format email tidak valid"},
		{"email panjang", RegisterRequest{"budi", long, "123456"}, "Format email tidak valid"},
		{"password pendek", RegisterRequest{"budi", "a@b.id", "12345"}, "Password minimal 6 karakter"},
		{"password terlalu panjang", RegisterRequest{"budi", "a@b.id", strings.Repeat("x", 73)}, "Password maksimal 72 byte"},
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

	// Tanpa mengganti password; username/email milik sendiri tidak dianggap bentrok.
	got, err := svc.UpdateProfile(u.ID, UpdateProfileRequest{Username: "budi", Email: "baru@x.id"})
	require.NoError(t, err)
	assert.Equal(t, "baru@x.id", got.Email)

	// Mengganti password.
	_, err = svc.UpdateProfile(u.ID, UpdateProfileRequest{Username: "budi2", Email: "baru@x.id", Password: "passwordbaru"})
	require.NoError(t, err)
	var stored database.User
	require.NoError(t, db.First(&stored, u.ID).Error)
	assert.Equal(t, "budi2", stored.Username)
	assert.NoError(t, bcrypt.CompareHashAndPassword([]byte(stored.Password), []byte("passwordbaru")))

	var ve *ValidationError
	var ce *ConflictError
	_, err = svc.UpdateProfile(u.ID, UpdateProfileRequest{Username: "", Email: "a@b.id"})
	require.ErrorAs(t, err, &ve)
	_, err = svc.UpdateProfile(u.ID, UpdateProfileRequest{Username: "budi2", Email: "baru@x.id", Password: "123"})
	require.ErrorAs(t, err, &ve)
	_, err = svc.UpdateProfile(u.ID, UpdateProfileRequest{Username: "siti", Email: "baru@x.id"})
	require.ErrorAs(t, err, &ce)
	_, err = svc.UpdateProfile(999, UpdateProfileRequest{Username: "x1x", Email: "a@b.id"})
	assert.ErrorIs(t, err, ErrUserNotFound)

	req := UpdateProfileRequest{Username: "budi3", Email: "b3@x.id", Password: "passwordbaru"}
	for _, f := range []string{"FindByID", "ExistsByUsername", "Update"} {
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
	assert.Equal(t, "member", data["role"], "role dari payload harus diabaikan")
	assert.NotContains(t, data, "password")

	code, body = call(r, "POST", "/register", "", gin.H{"username": "budi", "email": "lain@x.id", "password": "123456"})
	assert.Equal(t, 409, code)
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

	code, body = call(r, "PUT", "/profile", token, gin.H{"username": "budi", "email": "ganti@x.id"})
	assert.Equal(t, 200, code)
	assert.Equal(t, "ganti@x.id", body["data"].(map[string]any)["email"])
	code, _ = call(r, "PUT", "/profile", token, "{rusak")
	assert.Equal(t, 400, code)

	_, _ = call(r, "POST", "/register", "", gin.H{"username": "siti", "email": "siti@x.id", "password": "123456"})
	code, _ = call(r, "PUT", "/profile", token, gin.H{"username": "siti", "email": "ganti@x.id"})
	assert.Equal(t, 409, code)
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
