package zip

import "core:bytes"
import "core:fmt"
import "core:io"
import "core:testing"
import "core:thread"
import "core:time"
main :: proc() {
	// data :: #load("helloworld_deflate.zip", []byte)

	// reader: bytes.Reader

	// bytes.reader_init(&reader, data)
	// zip_file, err := read(bytes.reader_to_stream(&reader))
	// fmt.printfln("%#v", zip_file)

	// error := unpack_to(zip_file, "foobar")
	// fmt.println(error)

	for _ in 0 ..< 60 {

		t := time.now()
		fmt.println("\nNOW", t)

		c, d := time_to_msdos_date_time(t)
		fmt.println(c, d)
		t2 := msdos_date_time_to_time(c, d)
		fmt.println(t2)
		time.sleep(time.Second)
	}
}
