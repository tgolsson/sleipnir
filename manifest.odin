package sleipnir

import "core:encoding/json"
import "core:os"
import "core:testing"
import "deps:http"

Manifest :: struct {
	versions: map[string]map[string]Version_Detail,
}

Version_Detail :: struct {
	url:  string,
	sha:  string,
	size: int,
	name: string,
}


@(test)
load_local_manifest :: proc(t: ^testing.T) {
	contents, _ := os.read_entire_file_from_filename("manifest.json")
	defer delete(contents)
	manifest: Manifest
	err := json.unmarshal_string(string(contents), &manifest, allocator = context.temp_allocator)
	defer free_all(context.temp_allocator)
	testing.expect_value(t, err, nil)

	testing.expect(t, "dev-2025-03" in manifest.versions)
}
