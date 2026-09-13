#!/usr/bin/env python3
"""Stream-verify the immutable public OpenC 1.0.0 GitHub release."""
from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path
import shutil
import tempfile
import urllib.request


REPOSITORY = "BoQsc/OpenC-Programming-Language"
TAG = "v1.0.0"
RELEASE_COMMIT = "d0f77f6268154ac06f4206c01cd349b226b53c1b"
RELEASE_RECORD = "OpenC-Core-1.0-release-record.json"
RELEASE_RECORD_SHA256 = (
    "0b7cdd6620bb9155651da8ab0e07f2eeae510295f7e7a40eed8f4a4f835a6467"
)
EXPECTED_ASSET_COUNT = 15
BLOCK_BYTES = 1024 * 1024


def request(url: str) -> urllib.request.Request:
    return urllib.request.Request(
        url,
        headers={
            "Accept": "application/vnd.github+json",
            "User-Agent": "OpenC-SH27-post-release-verifier",
        },
    )


def api_json(path: str) -> dict:
    url = f"https://api.github.com/repos/{REPOSITORY}/{path}"
    with urllib.request.urlopen(request(url), timeout=120) as response:
        return json.load(response)


def stream_download(url: str, output: Path) -> tuple[int, str]:
    digest = hashlib.sha256()
    size = 0
    with urllib.request.urlopen(request(url), timeout=300) as response:
        with output.open("wb") as stream:
            while True:
                block = response.read(BLOCK_BYTES)
                if not block:
                    break
                stream.write(block)
                digest.update(block)
                size += len(block)
    return size, digest.hexdigest()


def write_json(path: Path, value: object) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(
        json.dumps(value, indent=2, sort_keys=True) + "\n",
        encoding="utf-8",
        newline="\n",
    )


def tag_commit() -> str:
    reference = api_json("git/ref/tags/v1.0.0")
    target = reference["object"]
    if target["type"] == "commit":
        return target["sha"]
    if target["type"] != "tag":
        raise SystemExit(f"unexpected Git tag object type: {target['type']}")
    annotated = api_json(f"git/tags/{target['sha']}")
    if annotated["object"]["type"] != "commit":
        raise SystemExit("annotated release tag does not directly name a commit")
    return annotated["object"]["sha"]


def parse_sums(path: Path) -> dict[str, str]:
    values: dict[str, str] = {}
    for line in path.read_text(encoding="utf-8").splitlines():
        digest, separator, name = line.partition("  ")
        if not separator or len(digest) != 64 or name in values:
            raise SystemExit("published SHA256SUMS file is malformed")
        values[name] = digest
    return values


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--output",
        type=Path,
        default=Path("build-output/sh27-public-release-verification.json"),
    )
    args = parser.parse_args()

    release = api_json("releases/tags/v1.0.0")
    if release.get("tag_name") != TAG or release.get("draft") or release.get("prerelease"):
        raise SystemExit("v1.0.0 is not an ordinary published final release")
    resolved_commit = tag_commit()
    if resolved_commit != RELEASE_COMMIT:
        raise SystemExit("public v1.0.0 tag points to an unexpected commit")

    remote = {asset["name"]: asset for asset in release.get("assets", [])}
    if len(remote) != EXPECTED_ASSET_COUNT or RELEASE_RECORD not in remote:
        raise SystemExit("public v1.0.0 release does not contain the exact asset count")

    with tempfile.TemporaryDirectory(prefix="openc-sh27-") as temporary:
        root = Path(temporary)
        record_path = root / RELEASE_RECORD
        record_size, record_hash = stream_download(
            remote[RELEASE_RECORD]["browser_download_url"], record_path
        )
        if record_hash != RELEASE_RECORD_SHA256:
            raise SystemExit("published release record hash differs from SH-26 evidence")
        record = json.loads(record_path.read_text(encoding="utf-8"))
        if (
            record.get("schema") != "openc.release_record.v2"
            or record.get("version") != "1.0.0"
            or record.get("release_commit") != RELEASE_COMMIT
            or record.get("release_scope") != "windows_x86_64_hosted"
            or not record.get("released")
            or record.get("authorization", {}).get("status") != "AUTHORIZED"
        ):
            raise SystemExit("published release record identity or authority is invalid")

        expected = {
            item["path"]: {"bytes": item["bytes"], "sha256": item["sha256"]}
            for item in record.get("artifacts", [])
        }
        expected[RELEASE_RECORD] = {
            "bytes": record_size,
            "sha256": RELEASE_RECORD_SHA256,
        }
        if set(expected) != set(remote) or len(expected) != EXPECTED_ASSET_COUNT:
            raise SystemExit("GitHub asset names differ from the signed-off release set")

        verified: dict[str, dict[str, object]] = {}
        for name in sorted(expected):
            asset = remote[name]
            wanted = expected[name]
            api_digest = asset.get("digest")
            if asset.get("size") != wanted["bytes"]:
                raise SystemExit(f"GitHub reports the wrong size for {name}")
            if api_digest and api_digest != f"sha256:{wanted['sha256']}":
                raise SystemExit(f"GitHub reports the wrong digest for {name}")
            if name == RELEASE_RECORD:
                size, digest = record_size, record_hash
            else:
                size, digest = stream_download(asset["browser_download_url"], root / name)
            if size != wanted["bytes"] or digest != wanted["sha256"]:
                raise SystemExit(f"downloaded public asset differs: {name}")
            verified[name] = {"bytes": size, "sha256": digest}

        sums_name = "OpenC-Core-1.0-SHA256SUMS.txt"
        sums = parse_sums(root / sums_name)
        expected_sums = {
            name: value["sha256"]
            for name, value in expected.items()
            if name not in {RELEASE_RECORD, sums_name}
        }
        if sums != expected_sums:
            raise SystemExit("published SHA256SUMS contents differ from the release record")

        result = {
            "schema": "openc.sh27_public_release_verification.v1",
            "status": "PASS",
            "release": {
                "tag": TAG,
                "commit": resolved_commit,
                "url": release["html_url"],
                "published_at": release["published_at"],
                "record_published_utc": record["published_utc"],
                "draft": False,
                "prerelease": False,
            },
            "checks": {
                "annotated_tag_commit_exact": True,
                "release_record_exact": True,
                "asset_names_exact": True,
                "api_sizes_and_digests_exact": True,
                "downloaded_sizes_and_sha256_exact": True,
                "sha256sums_matches_release_record": True,
                "streaming_download_block_bytes": BLOCK_BYTES,
            },
            "assets_verified": len(verified),
            "total_asset_bytes": sum(item["bytes"] for item in verified.values()),
            "assets": verified,
            "independent_review_claimed": False,
            "linux_or_freestanding_claimed": False,
        }
        write_json(args.output.resolve(), result)
    print(
        "OpenC SH-27 public release verification: PASS "
        f"({EXPECTED_ASSET_COUNT}/{EXPECTED_ASSET_COUNT} streamed assets)"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
