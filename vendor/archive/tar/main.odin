package tar

import "core:flags"
import "core:fmt"
import "core:os"

main :: proc() {
	args := os.args

	if args[1] == "info" {
		archive := args[2]
		file, _ := os.open(archive)
		t, err := from_handle(file)
		if err != nil {
			fmt.println("Failed reading archive:", err)
			return
		}
		defer destroy_archive(t)

		for entry in t.entries {
			fmt.printfln("%20s    %o    %d bytes", entry.name, entry.mode, entry.size)
		}


	}
}
