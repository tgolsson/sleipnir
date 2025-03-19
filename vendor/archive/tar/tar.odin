package tar

import "base:runtime"
import "core:fmt"
import "core:io"
import "core:math"
import "core:mem"
import "core:os"
import "core:slice"
import "core:strconv"
import "core:strings"
import "core:time"

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
	device_major: Octal_Ascii(8),
	device_minor: Octal_Ascii(8),
	prefix:       [155]byte,
	pad:          [12]u8,
}

#assert(size_of(Tar_UStar_Header) == 512)

Tar_File :: struct {
	handle:    os.Handle,
	stream:    io.Stream,
	entries:   [dynamic]Tar_Entry,
	allocator: runtime.Allocator,
	offset:    i64,
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
	tar.offset = 0

	if ignore_contents {
		return tar, err
	}

	for true {
		got_entry, err := read_next_entry(&tar)
		if !got_entry {
			break
		}

		if err != nil {
			fmt.println("Error in archive read", err)
			break
		}
	}

	return tar, err
}

buf_to_string :: proc(buf: []u8) -> string {
	str := string(buf)
	return strings.clone(strings.truncate_to_byte(str, 0))
}

octal_to_num :: proc(input: Octal_Ascii($N), $Out: typeid) -> Out {
	input := input
	stringified := buf_to_string(input.data[:])
	defer delete(stringified)
	// TODO[TS]: handle the error
	value, _ := strconv.parse_i64_of_base(stringified, 8)
	return Out(value)
}

entry_from_header :: proc(
	header: ^Tar_UStar_Header,
	allocator: runtime.Allocator,
	offset: i64,
) -> (
	entry: Tar_Entry,
) {
	timestamp := octal_to_num(header.mtime, i64)

	context.allocator = allocator
	// entry.file_path = buf_to_string(header.file_path[:])
	// entry.file_mode = octal_to_num(header.file_mode, u32)
	// entry.uid = octal_to_num(header.uid, u32)
	// entry.gid = octal_to_num(header.gid, u32)
	// entry.file_size = octal_to_num(header.file_size, u64)
	// entry.mtime = time.unix(timestamp, 0)
	// entry.checksum = octal_to_num(header.checksum, u32)
	// entry.type = header.type
	// entry.linkname = buf_to_string(header.linkname[:])
	// entry.magic = header.magic
	// entry.version = header.version
	// entry.user = buf_to_string(header.user[:])
	// entry.group = buf_to_string(header.group[:])
	// entry.device_major = octal_to_num(header.device_major, u64)
	// entry.device_minor = octal_to_num(header.device_minor, u64)
	// entry.prefix = buf_to_string(header.prefix[:])
	// entry.offset = offset

	return entry
}

Tar_Entry :: enum {}

Invalid_Checksum :: struct {}
Empty_Block :: struct {}
Tar_Error :: union {
	io.Error,
	Invalid_Checksum,
	Empty_Block,
}

ipow :: proc(base: int, exponent: int) -> int {
	exponent := exponent
	base := base
	result := 1

	for true {
		if (exponent & 1) == 1 {
			result *= base
		}
		exponent >>= 1
		if exponent == 0 {
			break
		}

		base *= base
	}

	return result
}

parse_number :: proc(bytes: []u8) -> i64 {
	if bytes[0] == 0o200 || bytes[0] == 0o377 {
		v := 0
		for b in bytes[1:len(bytes) - 1] {
			v <<= 8
			v += int(b)
		}

		if bytes[0] == 0o377 {
			v = -(ipow(256, len(bytes) - 1) - v)
		}
		return i64(v)
	} else {
		s := buf_to_string(bytes)
		defer delete(s)

		trimmed := strings.trim_space(s)
		if trimmed == "" {
			return 0
		}


		res, _ := strconv.parse_i64_of_base(trimmed, 8)
		return res
	}
}

compute_checksums :: proc(bytes: []u8) -> (u64, i64) {
	unsigned: u64 = 256
	signed: i64 = 256

	ibytes := transmute([]i8)bytes
	for i in 0 ..< 148 {
		unsigned += u64(bytes[i])
		signed += i64(ibytes[i])
	}

	for i in 156 ..< 512 {
		unsigned += u64(bytes[i])
		signed += i64(ibytes[i])
	}

	return unsigned, signed
}

read_tar_entry :: proc(tar: ^Tar_File) -> (entry: Tar_Entry, err: Tar_Error) {
	block: [512]u8
	io.read_full(tar.stream, block[:]) or_return

	if slice.count(block[:], 0) == 512 {
		return entry, Empty_Block{}
	}

	unsigned, signed := compute_checksums(block[:])
	checksum := parse_number(block[148:156])

	if checksum != i64(unsigned) && checksum != signed {
		return entry, Invalid_Checksum{}
	}

	data := transmute(Tar_UStar_Header)block
	fmt.println(transmute(string)(data.file_path[:]))
	return
}

read_next_entry :: proc(tar: ^Tar_File) -> (ok: bool, err: io.Error) {

	offset := io.seek(tar.stream, 0, .Current) or_return
	if offset != tar.offset {
		// seek and force a single read
		io.seek(tar.stream, tar.offset - 1, .Start) or_return
		io.read_byte(tar.stream) or_return
	}

	header: Maybe(Tar_Entry)
	for true {
		header_, err := read_tar_entry(tar)

		switch v in err {
		case io.Error:
			return false, v

		case Invalid_Checksum:
			if tar.offset == 0 {
				return false, nil
			}

			tar.offset += 512

		case Empty_Block:
			tar.offset += 512
		}
		header = header_
		break
	}

	h, was_set := header.?
	if was_set {
		append(&tar.entries, h)
	}

	return true, nil

}
