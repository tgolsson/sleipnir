package sleipnir


import "core:log"
import "core:os"
import "core:path/filepath"

import "deps:http"
import "deps:http/client"

is_toolchain_installed :: proc(state_root: string, version: string) -> bool {
	toolchain_path := filepath.join({state_root, version})
	defer delete(toolchain_path)
	exists := os.exists(toolchain_path)
	log.info("Checking toolchain destination: %v = %v", toolchain_path, exists)
	return exists
}

toolchain_entrypoint :: proc(state_root: string, version: string) -> (bin: string, ok: bool) {
	toolchain_path := filepath.join({state_root, version})
	defer delete(toolchain_path)

	return "", false
}


install_toolchain :: proc(state_root: string, version: string, detail: Version_Detail) -> bool {
	if !is_toolchain_installed(state_root, version) {

		do_install_toolchain(state_root, version, detail)
	}
	return false
}

@(private)
do_install_toolchain :: proc(state_root: string, version: string, detail: Version_Detail) -> bool {
	log.info("Starting toolchain install %v", version)
	toolchain_path := filepath.join({state_root, version})
	defer delete(toolchain_path)

	archive, downloaded := do_download_toolchain(detail)
	if !downloaded {
		log.fatal("Unable to install toolchain, download failed")
		return false
	}

	log.infof("Downloaded toolchain %v -> %v", version, archive)

	if !os.exists(toolchain_path) {
		mkdir_err := os.make_directory(toolchain_path)
		if mkdir_err != nil {
			log.fatal("Failed creating toolchain directory: %v", toolchain_path)
			return false
		}
	}

	return true
}

@(private)
do_download_toolchain :: proc(version: Version_Detail) -> (archive: string, success: bool) {
	cache_root, cache_root_found := cache_dir("sleipnir")
	if !cache_root_found {
		log.fatal("failed locating cache dir for download destination")
		return archive, false
	}

	r: client.Request
	client.request_init(&r, .Get)
	defer client.request_destroy(&r)

	http.headers_set_unsafe(&r.headers, "accept", "application/octet-stream")

	res, err := client.request(&r, version.url)
	if err != nil {
		log.fatalf("Failed retrieving toolchain: %s", err)
		return archive, false
	}
	defer client.response_destroy(&res)

	body, allocation, berr := client.response_body(&res)
	defer client.body_destroy(body, allocation)
	if berr != nil {
		log.fatalf("Failed retrieving toolchain: %s", berr)
		return archive, false
	}
	output_filename := filepath.join({cache_root, version.name})

	os.write_entire_file(output_filename, transmute([]u8)(body.(client.Body_Plain)))
	return output_filename, true
}
