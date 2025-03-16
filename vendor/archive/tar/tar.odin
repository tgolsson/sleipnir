package tar

import "base:runtime"
import "core:io"
import "core:mem"
import "core:os"
import "core:strings"

Octal_Ascii :: struct($N: int) {
	data: [N - 1]u8,
	nul:  u8,
}

// Everything from v7 except link information
Tar_V7_Header :: struct #packed {
	file_path: [100]u8,
	// octal mode, ascii
	file_mode: Octal_Ascii(8),
	uid:       Octal_Ascii(8),
	gid:       Octal_Ascii(8),
	file_size: Octal_Ascii(12),
	mtime:     Octal_Ascii(12),
	checksum:  Octal_Ascii(8),
	type:      byte,
	linkname:  [100]u8,
}

#assert(size_of(Tar_V7_Header) == 257)

Tar_UStar_Header :: struct #packed {
	using _:      Tar_V7_Header,
	magic:        [6]byte,
	version:      [2]byte,
	user:         [32]byte,
	group:        [32]byte,
	device_major: [8]byte,
	device_minor: [8]byte,
	prefix:       [155]byte,
	pad:          [12]u8,
}

#assert(size_of(Tar_UStar_Header) == 512)

Tar_Entry_Type :: enum {
	Normal,
	Hard_Link,
	Symbolic_Link,
	Character_Special,
	Block_Special,
	Directory,
	FIFO,
	Contiguous,
	Global_Meta,
	Local_Meta,
	Vendor_Extension,
}

Tar_Entry :: struct {
	file_path:    string,
	// octal mode, ascii
	file_mode:    u32,
	uid:          u32,
	gid:          u32,
	file_size:    u64,
	mtime:        u64,
	checksum:     u32,
	type:         byte,
	linkname:     string,
	magic:        [6]byte,
	version:      [2]byte,
	user:         string,
	group:        string,
	device_major: u64,
	device_minor: u64,
	prefix:       string,
	offset:       i64,
}

Tar_File :: struct {
	handle:    os.Handle,
	stream:    io.Stream,
	entries:   [dynamic]Tar_Entry,
	allocator: runtime.Allocator,
}

from_handle :: proc(
	h: os.Handle,
	ignore_contents := false,
	allocator := context.allocator,
) -> (
	tar: Tar_File,
	err: io.Error,
) {
	tar.handle = h
	tar.stream = os.stream_from_handle(h)
	tar.entries = make([dynamic]Tar_Entry, allocator)

	if ignore_contents {
		return tar, err
	}


	for true {
		if !read_entry(&tar) {
			break
		}
	}

	return tar, err
}

buf_to_string :: proc(buf: []u8) -> string {
	first_nul :=
}

entry_from_header :: proc(
	header: ^Tar_UStar_Header,
	allocator: runtime.Allocator,
	offset: i64,
) -> (
	entry: Tar_Entry,
) {
	context.allocator = allocator
	entry.file_path = header.file_path
	entry.file_mode = header.file_mode
	entry.uid = header.uid
	entry.gid = header.gid
	entry.file_size = header.file_size
	entry.mtime = header.mtime
	entry.checksum = header.checksum
	entry.type = header.type
	entry.linkname = header.linkname
	entry.magic = header.magic
	entry.version = header.version
	entry.user = header.user
	entry.group = header.group
	entry.device_major = header.device_major
	entry.device_minor = header.device_minor
	entry.prefix = strings.clone_from_cstring_boundedh(eader.prefix)
	entry.offset = offset

	return entry
}

read_entry :: proc(tar: ^Tar_File) -> bool {
	offset, err := os.seek(tar.handle, 0, os.SEEK_CUR)
	if err != nil {
		return false
	}

	header: Tar_UStar_Header
	_, read_err := io.read_full(tar.stream, mem.any_to_bytes(header))
	if err != nil {
		return false
	}


}
