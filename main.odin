package sleipnir

import "core:fmt"
import "core:log"
import "core:os"
import "core:path/filepath"
import "core:strings"
import "core:time"
import "deps:toml"

log_file_name :: proc(state_root: string) -> string {
	date_buf: [time.MIN_YYYY_DATE_LEN]u8
	log_timestamp := time.to_string_yyyy_mm_dd(time.now(), date_buf[:])
	log_filename := fmt.tprintf("log-%s.txt", log_timestamp)
	log_file_path := filepath.join({state_root, log_filename})

	return log_file_path
}

locate_sleipnir_toml :: proc() -> (string, bool) {
	cwd := os.get_current_directory()

	for true {
		query := filepath.join({cwd, "sleipnir.toml"}, context.temp_allocator)
		if os.exists(query) {
			res := strings.clone(query)
			free_all(context.temp_allocator)
			return res, true
		}

		next := filepath.dir(cwd, context.temp_allocator)
		if next == cwd {
			break
		}

		cwd = next
	}

	return "", false
}

Configuration :: struct {
	log_level: log.Level,
}


resolve_configuration :: proc(configuration: ^Configuration) -> bool {
	config_root, config_found := config_dir("sleipnir")
	defer delete(config_root)

	base_config: toml.Table
	if config_found {
		config_path := filepath.join({config_root, "sleipnir.toml"})

		if os.exists(config_path) {
			log.info("Loading global configuration:", config_path)
			table, err := toml.parse_file(config_path)
			if err.type != .None {
				message, _ := toml.format_error(err)
				defer delete(message, context.temp_allocator)

				log.fatalf("failed loading '%v': ", config_path, message)
				return false
			}
		} else {
			log.info("No global configuration found:", config_path)
		}
	}

	dominating_toml, found_toml := locate_sleipnir_toml()
	if !found_toml {
		log.fatalf("Failed locating 'sleipnir.toml', exiting")
		return false
	} else {
		log.info("Loading local configuration:", dominating_toml)
	}
	defer delete(dominating_toml)

	res, err := toml.parse_file(dominating_toml)
	toml.print_table(res)
	return false
}
main :: proc() {
	log_level := log.Level.Info
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

	console_logger := log.create_console_logger(log_level)
	defer log.destroy_console_logger(console_logger)
	context.logger = console_logger
	state_root, state_found := state_dir("sleipnir")
	log_file_handle := os.INVALID_HANDLE

	if !state_found {
		log.fatal("failed locating state directory, cannot continue")
		os.exit(1)
	}

	log_file_path := log_file_name(state_root)
	if !os.exists(state_root) {
		os.make_directory(state_root)
	}

	when ODIN_OS == .Linux {
		handle, err := os.open(
			log_file_path,
			os.O_CREATE | os.O_APPEND | os.O_WRONLY,
			mode = 0o755,
		)
	}

	if err != nil {
		log.fatalf("failed opening log file: %v", err)
		os.exit(1)
	}

	file_logger := log.create_file_logger(handle)
	defer log.destroy_file_logger(file_logger)

	multi_logger := log.create_multi_logger(console_logger, file_logger)
	context.logger = multi_logger
	log.debug("started file logger to", log_file_path)


	defer {
		context.logger = log.nil_logger()
		log.destroy_multi_logger(multi_logger)
	}

	configuration: Configuration
	resolve_configuration(&configuration)

}
