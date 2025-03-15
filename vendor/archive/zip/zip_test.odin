package zip

import "core:bytes"
import "core:fmt"
import "core:io"
import "core:testing"

@(test)
test_zip_header :: proc(t: ^testing.T) {
	data :: #load("empty.zip", []byte)

	reader: bytes.Reader

	bytes.reader_init(&reader, data)


	rec, err := read_eocd_record(bytes.reader_to_stream(&reader))
	testing.expect_value(t, err, nil)
}


@(test)
test_zip_header_hw :: proc(t: ^testing.T) {
	data :: #load("helloworld.zip", []byte)

	reader: bytes.Reader

	bytes.reader_init(&reader, data)
	rec_, err := read_eocd_record(bytes.reader_to_stream(&reader))
	testing.expect_value(t, err, nil)

	rec := rec_.(Eocd_Record)
	testing.expect_value(t, rec.cd_count_this_disk, 1)
	testing.expect_value(t, rec.cd_count_this_disk, rec.cd_count_total)
}


@(test)
test_zip_header_hw_z64 :: proc(t: ^testing.T) {
	data :: #load("helloworld.zip64", []byte)

	reader: bytes.Reader

	bytes.reader_init(&reader, data)
	rec_, err := read_eocd_record(bytes.reader_to_stream(&reader))
	testing.expect_value(t, err, nil)
	// Zip64 record in a zip file. So we DON'T expect a Eocd_Zip64_Record here.
	rec := rec_.(Eocd_Record)
	testing.expect_value(t, rec.cd_count_this_disk, 1)
	testing.expect_value(t, rec.cd_count_this_disk, rec.cd_count_total)


}
