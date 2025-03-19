package tar

import "core:flags"
import "core:fmt"
import "core:os"

main :: proc() {
	args := os.args

	if args[1] == "read" {
		archive := args[2]
		file, _ := os.open(archive)
		t, err := from_handle(file)
		fmt.println(t, err)
	}

}
