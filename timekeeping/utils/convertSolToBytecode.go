package utils

import (
	"os"
	"strings"
)

func GetOutputFileName(outputFileName string, ext string) string {
	bytecodeFile := outputFileName + ext
	return "build/" + bytecodeFile
}

func ConvertSolToByteCode(outputFileName string) (*string, error) {
	// Lấy mã bytecode từ kết quả đầu ra
	bytecodePath := GetOutputFileName(outputFileName, ".bin")

	// Đọc nội dung của tệp mã bytecode
	bytecodeContent, err := os.ReadFile(bytecodePath)
	if err != nil {
		return nil, err
	}

	bytecode := strings.TrimSpace(string(bytecodeContent))
	return &bytecode, nil
}
