package sleipnir

import "core:encoding/json"
import "core:log"
import "core:os"
import "core:testing"

import "deps:http"
import "deps:http/client"

Manifest :: struct {
	versions: map[string]map[string]Version_Detail,
}

Version_Detail :: struct {
	url:  string,
	sha:  string,
	size: int,
	name: string,
}

destroy_manifest :: proc(m: Manifest, allocator := context.allocator) {
	for tag, variants in m.versions {
		for variant, detail in variants {
			delete(detail.url, allocator)
			delete(detail.sha, allocator)
			delete(detail.name, allocator)

			delete(variant, allocator)
		}

		delete(variants)
		delete(tag, allocator)
	}

	delete(m.versions)
}

load_manifest :: proc(
	url := "https://raw.githubusercontent.com/tgolsson/sleipnir/refs/heads/main/manifest.json",
) -> (
	manifest: Manifest,
	success: bool,
) {

	r: client.Request
	client.request_init(&r, .Get)
	defer client.request_destroy(&r)

	http.headers_set_unsafe(&r.headers, "accept", "application/vnd.github.v3.raw")

	res, err := client.request(&r, url)
	if err != nil {
		log.fatalf("Request failed: %s", err)
		return manifest, false
	}
	defer client.response_destroy(&res)

	body, allocation, berr := client.response_body(&res)
	if berr != nil {
		log.fatalf("Error retrieving response body: %s", berr)
		return manifest, false
	}
	defer client.body_destroy(body, allocation)

	jsonerr := json.unmarshal_string(body.(client.Body_Plain), &manifest)
	if jsonerr != nil {
		log.info(body.(client.Body_Plain))
		log.fatalf("Error parsing manifest: %s", jsonerr)
		return manifest, false
	}

	return manifest, true
}

@(test)
load_local_manifest :: proc(t: ^testing.T) {
	contents, _ := os.read_entire_file_from_filename("manifest.json")
	defer delete(contents)
	manifest: Manifest
	err := json.unmarshal_string(string(contents), &manifest, allocator = context.temp_allocator)
	defer destroy_manifest(manifest, context.temp_allocator)
	testing.expect_value(t, err, nil)
	testing.expect(t, "dev-2025-03" in manifest.versions)
}
