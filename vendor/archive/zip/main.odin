package zip

import "core:bytes"
import "core:fmt"
import "core:io"
import "core:testing"

main :: proc() {
	data :: #load("helloworld.zip", []byte)

	reader: bytes.Reader

	bytes.reader_init(&reader, data)
	zip_file, err := read(bytes.reader_to_stream(&reader))
	fmt.printfln("%#v", zip_file)

	error := unpack_to(zip_file, "foobar")
	fmt.println(error)
}
