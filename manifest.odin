package sleipnir

import "core:encoding/json"
import "core:log"
import "core:os"
import "core:path/filepath"
import "core:testing"
import "core:time"

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

@(private)
try_load_cache :: proc(cache_root: string) -> (m: Manifest, missing: bool) {
	manifest_cache_file := filepath.join({cache_root, "manifest.json"})
	defer delete(manifest_cache_file)

	if !os.exists(manifest_cache_file) {
		return m, false
	}

	handle, err := os.open(manifest_cache_file)
	if err != nil {
		log.warn("Manifest cache exists but cannot be opened: ", err)
		return m, false
	}
	defer os.close(handle)

	info, staterr := os.fstat(handle)
	if staterr != nil {
		log.warn("Manifest cache exists but cannot be stated: ", err)
		return m, false
	}

	if time.duration_seconds(time.since(info.modification_time)) > 3600 {
		log.info("Manifest cache expired")
		return m, false
	}

	contents := os.read_entire_file(handle) or_return
	defer delete(contents)
	merr := json.unmarshal(contents, &m)
	if merr != nil {
		log.error("Manifest cache failed unmarshalling:", merr)
		return m, false
	}

	return m, true
}

write_cache_file :: proc(cache_root: string, contents: string) {
	manifest_cache_file := filepath.join({cache_root, "manifest.json"})
	defer delete(manifest_cache_file)

	if !os.exists(cache_root) {
		err := os.make_directory(cache_root)
		if err != nil {
			log.error("Manifest cache cannot be written:", err)
			return
		}
	}

	if os.write_entire_file(manifest_cache_file, transmute([]u8)contents) {
		log.info("Manifest cache written")
	}
}

load_manifest :: proc(
	url := "https://raw.githubusercontent.com/tgolsson/sleipnir/refs/heads/main/manifest.json",
) -> (
	manifest: Manifest,
	success: bool,
) {
	cache_root, cache_root_found := cache_dir("sleipnir")

	defer if cache_root_found {delete(cache_root)}
	if cache_root_found {
		manifest, success = try_load_cache(cache_root)
		if success {
			log.info("Manifest loaded from cache")
			return manifest, success
		}
	}

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

	if cache_root_found {

		write_cache_file(cache_root, body.(client.Body_Plain))
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
