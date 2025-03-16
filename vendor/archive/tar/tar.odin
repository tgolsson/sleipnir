package tar


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
