package config

import (
	"fmt"

	"github.com/spf13/viper"
)

// Config là struct chứa các giá trị cấu hình
type Config struct {
	PORT              string `mapstructure:"PORT"`
	CONTRACT_ADDRESS  string `mapstructure:"CONTRACT_ADDRESS"`
	CONTRACT_ABI      string `mapstructure:"CONTRACT_ABI"`
	PRIVATE_KEY       string `mapstructure:"PRIVATE_KEY"`
	NETWORK_URL       string `mapstructure:"NETWORK_URL"`
	SOL_BUILD_FILE    string `mapstructure:"SOL_BUILD_FILE"`
	CONTRACT_CREATION string `mapstructure:"CONTRACT_CREATION"`
}

var Env Config

// LoadConfig là hàm dùng để load file cấu hình và lưu các giá trị vào Config
func InitConfig() {
	var config Config

	viper.SetConfigFile(".env") // Đặt tên file cấu hình là .env
	viper.AllowEmptyEnv(true)   // Cho phép biến môi trường rỗng
	viper.AutomaticEnv()        // Tự động đọc biến môi trường

	err := viper.ReadInConfig()
	if err != nil {
		panic(fmt.Errorf("fatal error config file: %s ", err))
	}

	// Map các giá trị từ file config vào struct Config
	err = viper.Unmarshal(&config)
	if err != nil {
		panic(fmt.Errorf("unable to decode into struct: %s ", err))
	}
	Env = config
}
