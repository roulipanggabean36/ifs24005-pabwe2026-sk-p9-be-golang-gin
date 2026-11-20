package response

import "github.com/gin-gonic/gin"

// Success mengirim respons 2xx dengan status "success". Kunci "data" hanya
// disertakan bila data diberikan dan tidak nil.
func Success(c *gin.Context, httpStatus int, message string, data ...any) {
	res := gin.H{"status": "success", "message": message}
	if len(data) > 0 && data[0] != nil {
		res["data"] = data[0]
	}
	c.JSON(httpStatus, res)
}

// Fail mengirim respons 4xx dengan status "fail".
func Fail(c *gin.Context, httpStatus int, message string) {
	c.JSON(httpStatus, gin.H{"status": "fail", "message": message})
}

// Error mengirim respons 5xx dengan status "error".
func Error(c *gin.Context, httpStatus int, message string) {
	c.JSON(httpStatus, gin.H{"status": "error", "message": message})
}

// AbortFail menghentikan rantai handler dengan respons 4xx.
func AbortFail(c *gin.Context, httpStatus int, message string) {
	c.AbortWithStatusJSON(httpStatus, gin.H{"status": "fail", "message": message})
}

// AbortError menghentikan rantai handler dengan respons 5xx.
func AbortError(c *gin.Context, httpStatus int, message string) {
	c.AbortWithStatusJSON(httpStatus, gin.H{"status": "error", "message": message})
}
