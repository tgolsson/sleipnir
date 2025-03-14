package sleipnir
import "deps:toml"

extract_required_field :: proc(
	target_field: ^$T,
	local: ^toml.Table,
	global: ^toml.Table,
	field_path: ..string,
) -> bool {
	when T == bool {
		local_value, in_local := toml.get_bool(local, ..field_path)
		global_value, in_global := toml.get_bool(global, ..field_path)
	}

	when T == string {
		local_value, in_local := toml.get_string(local, ..field_path)
		global_value, in_global := toml.get_string(global, ..field_path)
	}

	if in_local {
		target_field^ = local_value
	} else if in_global {
		target_field^ = global_value
	}

	return in_local || in_global
}

extract_field :: proc(
	target_field: ^$T,
	local: ^toml.Table,
	global: ^toml.Table,
	default: T,
	field_path: ..string,
) {
	when T == bool {
		local_value, in_local := toml.get_bool(local, ..field_path)
		global_value, in_global := toml.get_bool(global, ..field_path)
	}

	if in_local {
		target_field^ = local_value
	} else if in_global {
		target_field^ = global_value
	} else {
		target_field^ = default
	}
}

extract_optional_field :: proc(
	target_field: ^Maybe($T),
	local: ^toml.Table,
	global: ^toml.Table,
	field_path: ..string,
) {
	when T == bool {
		local_value, in_local := toml.get_bool(local, ..field_path)
		global_value, in_global := toml.get_bool(global, ..field_path)
	}

	when T == string {
		local_value, in_local := toml.get_string(local, ..field_path)
		global_value, in_global := toml.get_string(global, ..field_path)
	}

	if in_local {
		target_field^ = local_value
	} else if in_global {
		target_field^ = global_value
	}
}
