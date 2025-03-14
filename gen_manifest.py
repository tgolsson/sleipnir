import json
import os

import requests


def read_existing_manifest():
    with open("manifest.json") as manifest:
        m = json.load(manifest)

    if "versions" not in m:
        m["versions"] = {}

    return m


def read_releases(url):
    return requests.get(
        url,
        headers={
            "Accept": "application/vnd.github+json",
            "X-GitHub-Api-Version": "2022-11-28",
        },
    )


def _filter_prune_releases(releases):
    filtered = []
    rejected = []
    for release in releases:
        tag = release["tag_name"]
        if "dev" in tag or tag.startswith("v"):
            filtered.append(tag)

        else:
            rejected.append(tag)

    return filtered


def categorize_assets(assets):
    out = {}

    for asset in assets:
        platform = None
        architecture = None

        name = asset["name"]
        if "windows" in name:
            platform = "windows"

        elif "ubuntu" in name or "linux" in name:
            platform = "linux"

        elif "macos" in name or "-mac-" in name:
            platform = "macos"

        if "amd64" in name:
            architecture = "x86_64"

        if "arm64" in name:
            architecture = "aarch64"

        if architecture is None and "2022-03" in name or "2022-02" in name:
            architecture = "x86_64"

        elif name in [
            "odin-v0.12.0.zip",
            "odin-v0.11.1.zip",
            "odin-v0.9.0.zip",
            "odin-v0.8.1.zip",
            "odin-v0.8.0.zip",
            "odin-v0.7.1.zip",
            "odin-v0.7.0.zip",
            "odin-v0.6.2.zip",
            "odin-v0.6.1a.zip",
            "odin-v0.6.1.zip",
            "odin-v0.6.0.zip",
            "odin-v0.5.0.zip",
            "odin-v0.4.0.zip",
            "odin-v0.3.0.zip",
            "odin-v0.2.1.zip",
            "odin-v0.2.0.zip",
            "odin-v0.1.3.zip",
            "odin-v0.1.2.zip",
            "odin-v0.1.1.zip",
            "odin-v0.1.0.zip",
        ]:
            platform = "windows"
            architecture = "x86_64"

        elif name.startswith("odin-v0.0."):
            continue

        assert platform is not None and architecture is not None, (
            name,
            platform,
            architecture,
        )

        out[(platform, architecture)] = name

    return out


def get_sha(url: str, expected_size: int) -> str:
    import hashlib

    headers = {
        "Accept": "application/octet-stream",
    }

    if "GITHUB_TOKEN" in os.environ:
        headers["Authorization"] = f"Bearer {os.environ["GITHUB_TOKEN"]}"

    res = requests.get(
        url,
        headers=headers,
    )

    if (
        int(res.headers["Content-Length"]) != int(expected_size)
        and int(res.headers["Content-Length"]) < 300
    ):
        assert False, f'length mismatch, got {res.headers["Content-Length"]} bytes when expecting {expected_size}'

    return hashlib.sha256(res.content).hexdigest()


def main():
    manifest = read_existing_manifest()

    if os.path.exists("data.json"):
        with open("data.json", "r") as source:
            releases = json.load(source)

    else:
        link = "https://api.github.com/repos/odin-lang/Odin/releases"
        releases = []
        while link:
            response = read_releases(link)
            releases.extend(response.json())
            print(response.headers["X-RateLimit-Remaining"])
            if "Link" in response.headers:
                links = response.headers["Link"].split(",")
                for link in links:
                    if 'rel="next"' in link:
                        link = link.split("; ")[0].strip()[1:-1]
                        break
                else:
                    link = None

        with open("data.json", "w") as out:
            json.dump(releases, out)

    names = [release["name"] for release in releases]
    filtered = _filter_prune_releases(releases)
    releases = {release["tag_name"]: release for release in releases}

    for tag in filtered:
        if "versions" in manifest and tag in manifest["versions"]:
            continue

        print("Handling", tag)
        assets = releases[tag]["assets"]
        categorized = categorize_assets(assets)

        assets = {asset["name"]: asset for asset in assets}
        version_info = {}
        for (platform, arch), asset_name in categorized.items():
            asset = assets[asset_name]

            sha = get_sha(asset["url"], asset["size"])
            version_info[f"{platform}-{arch}"] = {
                "url": asset["url"],
                "sha": sha,
                "name": asset_name,
                "size": asset["size"],
            }

        manifest["versions"][tag] = version_info
        with open("manifest.json", "w") as out:
            json.dump(manifest, out)


if __name__ == "__main__":
    main()
