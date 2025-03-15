package zip

import "base:intrinsics"
import "base:runtime"

import "core:fmt"
import "core:io"
import "core:mem"
import "core:os"
import "core:path/filepath"
import "core:time"

// TODO:
// - [ ] Stop caring about endianness.
EOCD_SIGNATURE :: 0x06054b50
Eocd_Record :: struct #packed {
	signature:          u32le,
	this_disk:          u16le,
	cd_start_disk:      u16le,
	cd_count_this_disk: u16le,
	cd_count_total:     u16le,
	cd_size:            u32le,
	cd_start_offset:    u32le,
	comment_length:     u16le,
	comment:            [0]u8,
}

EOCD_Z64_LOCATOR_SIGNATURE :: 0x07064b50
Eocd_Zip64_Locator :: struct #packed {
	signature:            u32le,
	eocd_start_disk:      u32le,
	eocd_relative_offset: u64le,
	total_disk_count:     u32le,
}

EOCD_ZIP64_SIGNATURE :: 0x06064b50
Eocd_Zip64_Record :: struct #packed {
	signature:                u32le,
	record_size:              u64le,
	source_version:           u16le,
	min_version:              u16le,
	this_disk:                u32le,
	cd_start_disk:            u32le,
	cd_entry_count_this_disk: u64le,
	cd_entry_count_total:     u64le,
	cd_size:                  u64le,
	cd_reloff:                u64le,
}


#assert(size_of(Eocd_Zip64_Record) == 56)
#assert(size_of(Eocd_Record) == 22)

Eocd :: union {
	Eocd_Record,
	Eocd_Zip64_Record,
}

read_eocd_zip64_record :: proc(
	reader: io.Reader,
	offset: i64,
	eocd: Eocd_Record,
) -> (
	rec: Eocd,
	err: io.Error,
) {
	rec = eocd
	_, err = io.seek(reader, offset - size_of(Eocd_Zip64_Locator), .End)
	if err != nil {
		return rec, nil
	}

	locator: Eocd_Zip64_Locator
	io.read_full(reader, mem.any_to_bytes(locator)) or_return

	if locator.signature != EOCD_Z64_LOCATOR_SIGNATURE {
		return rec, err
	}

	if locator.total_disk_count != 1 || locator.eocd_start_disk != 0 {
		// TODO[TSolberg]: Error handling
		panic("no support for multi-disk ZIP")
	}

	io.seek(
		reader,
		offset - size_of(Eocd_Zip64_Locator) - size_of(Eocd_Zip64_Locator),
		.End,
	) or_return

	eocd_z64: Eocd_Zip64_Record
	io.read_full(reader, mem.any_to_bytes(eocd_z64)) or_return

	if eocd_z64.signature != EOCD_ZIP64_SIGNATURE {
		return rec, err
	}

	rec = eocd_z64
	return rec, err
}

read_eocd_record :: proc(reader: io.Reader) -> (rec: Eocd, err: io.Error) {
	filesize := io.seek(reader, 0, .End) or_return

	if filesize < size_of(Eocd_Record) {
		return rec, io.Error.Short_Buffer
	}

	eocd: Eocd_Record
	io.seek(reader, -size_of(Eocd_Record), .End)
	io.read_full(reader, mem.any_to_bytes(eocd)) or_return

	if eocd.signature == EOCD_SIGNATURE && eocd.comment_length == 0 {
		return read_eocd_zip64_record(reader, -size_of(Eocd_Record), eocd)
	}

	panic("zip comments not supported!")
}

Zip_File_Eocd :: struct {
	signature:                u32,
	record_size:              u64,
	source_version:           u16,
	min_version:              u16,
	this_disk:                u32,
	cd_start_disk:            u32,
	cd_entry_count_this_disk: u64,
	cd_entry_count_total:     u64,
	cd_size:                  u64,
	cd_reloff:                u64,
	is_zip64:                 bool,
}

Central_Directory_Header :: struct #packed {
	signature:          u32le,
	made_by:            u16le,
	needed:             u16le,
	flags:              u16le,
	compression:        u16le,
	mtime:              u16le,
	mdate:              u16le,
	crc32:              u32le,
	csize:              u32le,
	usize:              u32le,
	file_name_length:   u16le,
	extra_field_length: u16le,
	comment_length:     u16le,
	disk_number_start:  u16le,
	internal_attrs:     u16le,
	external_attrs:     u32le,
	local_reloff:       u32le,
}


Central_Directory :: struct {
	using _:      Central_Directory_Header,
	file_name:    string,
	extra_field:  string,
	file_comment: string,
	timestamp:    time.Time,
}

@(private)
extract_eocd :: proc(eocd: Eocd) -> (generic: Zip_File_Eocd) {
	switch variant in eocd {
	case Eocd_Record:
		generic.signature = u32(variant.signature)
		generic.record_size = 0 // TODO
		generic.source_version = 0 // TODO
		generic.min_version = 0 // TODO
		generic.this_disk = u32(variant.this_disk)
		generic.cd_start_disk = u32(variant.cd_start_disk)
		generic.cd_entry_count_this_disk = u64(variant.cd_count_this_disk)
		generic.cd_entry_count_total = u64(variant.cd_count_total)
		generic.cd_size = u64(variant.cd_size)
		generic.cd_reloff = u64(variant.cd_start_offset)
	case Eocd_Zip64_Record:
		generic.signature = u32(variant.signature)
		generic.record_size = u64(variant.record_size)
		generic.source_version = u16(variant.source_version)
		generic.min_version = u16(variant.min_version)
		generic.this_disk = u32(variant.this_disk)
		generic.cd_start_disk = u32(variant.cd_start_disk)
		generic.cd_entry_count_this_disk = u64(variant.cd_entry_count_this_disk)
		generic.cd_entry_count_total = u64(variant.cd_entry_count_total)
		generic.cd_size = u64(variant.cd_size)
		generic.cd_reloff = u64(variant.cd_reloff)
		generic.is_zip64 = true
	}

	return generic
}

Zip_File :: struct {
	reader: io.Stream,
	eocd:   Zip_File_Eocd,
	start:  u64,
	files:  [dynamic]Central_Directory,
}

LOCAL_FILE_HEADER_SIGNATURE :: 0x04034b50
Local_File_Header :: struct #packed {
	signature:          u32le,
	extract_version:    u16le,
	bit_flags:          u16le,
	compression_method: u16le,
	mtime:              u16le,
	mdate:              u16le,
	crc:                u32le,
	csize:              u32le,
	usize:              u32le,
	file_name_length:   u16le,
	extra_field_length: u16le,
}

Local_File :: struct {
	using _:      Local_File_Header,
	filename:     string,
	extra_fields: string,
	time:         time.Time,
}

@(private)
ensure_dirs :: proc(root: string, sub: string, temp_allocator: runtime.Allocator) {
	dir := filepath.dir(sub, temp_allocator)
	defer delete(dir, temp_allocator)

	components := filepath.split_list(dir, temp_allocator)
	defer delete(components, temp_allocator)

	total_path := root
	for piece in components {
		subpath := filepath.join({total_path, piece}, temp_allocator)
		if !os.exists(subpath) {
			os.make_directory(subpath)
		}

		if total_path != root {
			delete(total_path, temp_allocator)
		}

		total_path = subpath
	}

	if total_path != root {
		delete(total_path, temp_allocator)
	}
}

read_local :: proc(zip: Zip_File, cd: Central_Directory) -> (local: Local_File, err: io.Error) {
	fmt.println("Seeking to ", i64(cd.local_reloff))
	io.seek(zip.reader, i64(cd.local_reloff), .Start)

	header: Local_File_Header

	io.read_full(zip.reader, mem.any_to_bytes(header)) or_return
	fmt.printfln("%#v", header)
	assert(header.signature == LOCAL_FILE_HEADER_SIGNATURE)
	(^Local_File_Header)(&local)^ = header

	if local.file_name_length > 0 {
		bytes := make([]byte, local.file_name_length)
		io.read_full(zip.reader, bytes[:]) or_return
		local.filename = string(bytes)
	}

	if local.extra_field_length > 0 {
		bytes := make([]byte, local.extra_field_length)
		io.read_full(zip.reader, bytes[:]) or_return
		local.extra_fields = string(bytes)
	}

	local.time = msdos_date_time_to_time(local.mtime, local.mdate)
	return local, err
}

destroy_local :: proc(local: Local_File) {
	delete(local.filename)
	delete(local.extra_fields)
}
// Unpacks all the files rooted out_directory.
unpack_to :: proc(
	zip: Zip_File,
	out_directory: string,
	temp_allocator := context.temp_allocator,
) -> (
	err: io.Error,
) {
	for file in zip.files {
		ensure_dirs(out_directory, file.file_name, temp_allocator)

		local := read_local(zip, file) or_return
		defer destroy_local(local)

		full_path := filepath.join({out_directory, file.file_name}, temp_allocator)
		defer delete(full_path, temp_allocator)
		handle, ok := os.open(full_path, os.O_CREATE | os.O_WRONLY | os.O_TRUNC, 0o644)
		defer os.close(handle)
		writer := os.stream_from_handle(handle)
		io.copy_n(writer, zip.reader, i64(local.usize))

	}
	return nil
}
read :: proc(reader: io.Reader) -> (zip: Zip_File, err: io.Error) {
	eocd := read_eocd_record(reader) or_return
	generic := extract_eocd(eocd)


	filesize := io.seek(reader, 0, .End) or_return
	prefix_length := u64(filesize) - size_of(Eocd_Record) - generic.cd_size - generic.cd_reloff
	if generic.is_zip64 {
		prefix_length -= size_of(Eocd_Zip64_Record) + size_of(Eocd_Zip64_Locator)
	}

	zip.start = prefix_length + generic.cd_reloff
	fmt.printfln("%#v", generic)
	fmt.println(zip.start, prefix_length)
	io.seek(reader, i64(zip.start), .Start) or_return

	bytes_read: int = 0
	fmt.println(generic)
	for u64(bytes_read) < generic.cd_size {
		header: Central_Directory_Header
		bytes_read += io.read_full(reader, mem.any_to_bytes(header)) or_return

		directory: Central_Directory
		(^Central_Directory_Header)(&directory)^ = header


		if directory.file_name_length > 0 {
			bytes := make([]byte, directory.file_name_length)
			bytes_read += io.read_full(reader, bytes[:]) or_return
			directory.file_name = string(bytes)
		}

		if directory.extra_field_length > 0 {
			bytes := make([]byte, directory.extra_field_length)
			bytes_read += io.read_full(reader, bytes[:]) or_return
			directory.extra_field = string(bytes)
		}

		if directory.comment_length > 0 {
			bytes := make([]byte, directory.comment_length)
			bytes_read += io.read_full(reader, bytes[:]) or_return
			directory.file_comment = string(bytes)
		}

		directory.timestamp = msdos_date_time_to_time(directory.mtime, directory.mdate)
		directory.local_reloff += u32le(prefix_length)
		fmt.printfln("%#v", directory)
		append(&zip.files, directory)
	}

	zip.reader = reader
	zip.eocd = generic
	zip.start = prefix_length
	return zip, err
}

msdos_date_time_to_time :: proc(clock: u16le, date: u16le) -> time.Time {
	clock := u16(clock)
	date := u16(date)

	second := clock & 0b11111
	minute := (clock >> 5) & 0b111111
	hour := (clock >> 11) & 0b11111

	day := date & 0b11111
	month := (date >> 5) & 0b1111
	year := 1980 + (date >> 9) & 0b1111111

	t, _ := time.components_to_time(year, month, day, hour, minute, second)
	return t
}
