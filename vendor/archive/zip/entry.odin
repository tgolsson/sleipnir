package zip

import "base:runtime"
import "core:slice"
import "core:strings"

Zip_Entry :: struct {
	local:     Local_File,
	data:      []u8,
	allocator: runtime.Allocator,
}

entry_destroy :: proc(entry: ^Zip_Entry) {
	if entry.local.file_name_length > 0 {
		delete(entry.local.filename, entry.allocator)
		entry.local.filename = ""
		entry.local.file_name_length = 0
	}

	if entry.local.extra_field_length > 0 {
		delete(entry.local.extra_fields, entry.allocator)
		entry.local.extra_fields = ""
		entry.local.extra_field_length = 0
	}

	delete(entry.data, entry.allocator)
	entry.data = {}
}

entry_create :: proc(
	name: string,
	data: []u8,
	allocator := context.allocator,
) -> (
	entry: Zip_Entry,
) {

	entry.local = {
		signature          = LOCAL_FILE_HEADER_SIGNATURE,
		extract_version    = 0x0A,
		bit_flags          = 0,
		compression_method = 0,
		filename           = strings.clone(name),
		file_name_length   = u16le(len(name)),
	}

	return entry

}
