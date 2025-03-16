package zip

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
#assert(size_of(Eocd_Record) == 22)

EOCD_Z64_LOCATOR_SIGNATURE :: 0x07064b50
Eocd_Zip64_Locator :: struct #packed {
	signature:            u32le,
	eocd_start_disk:      u32le,
	eocd_relative_offset: u64le,
	total_disk_count:     u32le,
}

#assert(size_of(Eocd_Zip64_Locator) == 20)

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
