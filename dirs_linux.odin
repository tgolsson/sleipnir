package sleipnir

import "base:runtime"

import "core:os"
import "core:path/filepath"


config_dir :: proc(app: string, allocator := context.allocator) -> (string, bool) {
	xdg_config_dir, xdg_found := os.lookup_env(
		"XDG_CONFIG_HOME",
		allocator = context.temp_allocator,
	)

	if xdg_found {
		defer delete(xdg_config_dir)
		res, err := filepath.join([]string{xdg_config_dir, app}, allocator)
		return res, err != nil
	}

	home_dir, home_found := os.lookup_env("HOME", allocator = context.temp_allocator)

	if home_found {
		defer delete(home_dir, context.temp_allocator)
		res, err := filepath.join([]string{home_dir, ".config", app}, allocator)
		return res, err != nil
	}

	return "", false
}


state_dir :: proc(app: string, allocator := context.allocator) -> (string, bool) {
	xdg_state_dir, xdg_found := os.lookup_env("XDG_STATE_HOME", allocator = context.temp_allocator)

	if xdg_found {
		defer delete(xdg_state_dir, context.temp_allocator)
		res, err := filepath.join([]string{xdg_state_dir, app}, allocator)
		return res, err != nil
	}

	home_dir, home_found := os.lookup_env("HOME", allocator = context.temp_allocator)

	if home_found {
		defer delete(home_dir, context.temp_allocator)
		res, err := filepath.join([]string{home_dir, ".local", "state", app}, allocator)
		return res, err != nil
	}

	return "", false
}
