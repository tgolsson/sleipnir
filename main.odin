package sleipnir

import "core:log"
import "core:os"
import "core:strings"
// import "deps:toml"

main :: proc() {
	log_level := log.Level.Warning
	if level_string, found := os.lookup_env("SLEIPNIR_LOG"); found {
		switch strings.to_lower(level_string) {
		case "debug":
			log_level = .Debug
		case "info":
			log_level = .Info
		case "warn", "warning":
			log_level = .Warning
		case "error":
			log_level = .Error
		case "fatal":
			log_level = .Fatal
		}
	}

	logger := log.create_console_logger(log_level)

	context.logger = logger
	log.info("Found dirs:", config_dir("sleipnir"), state_dir("sleipnir"))
}
