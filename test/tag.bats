#!/usr/bin/env bats -t
# umoci: Umoci Modifies Open Containers' Images
# Copyright (C) 2016 SUSE LLC.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#   http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

load helpers

function setup() {
	setup_image
}

function teardown() {
	teardown_image
}

@test "umoci tag list" {
	# Get list of tags.
	umoci tag --image "$IMAGE" ls
	[ "$status" -eq 0 ]
	[ "${#lines[@]}" -gt 0 ]

	# Get list of tags.
	umoci tag --image "$IMAGE" list
	[ "$status" -eq 0 ]
	[ "${#lines[@]}" -gt 0 ]
	nrefs="${#lines[@]}"

	# Check how many refs there actually are.
	sane_run find "$IMAGE/refs" -type f
	[ "$status" -eq 0 ]
	[ "${#lines[@]}" -eq "$nrefs" ]
}

@test "umoci tag add" {
	# Get blob and mediatype that a tag references.
	umoci tag --image "$IMAGE" list
	[ "$status" -eq 0 ]

	for tag in "${lines[@]}"; do
		umoci tag --image "$IMAGE" stat --tag "$tag"
		[ "$status" -eq 0 ]
		mediatype="$(echo $output | jq -SMr '.mediatype')"
		blob="$(echo $output | jq -SMr '.blob')"
		[[ "$tag" != "$TAG" ]] || break
	done
	[[ "$tag" == "$TAG" ]]

	# Add a new tag.
	umoci tag --image "$IMAGE" add --tag "${TAG}-newtag" --blob "$blob" --media-type "$mediatype"
	[ "$status" -eq 0 ]

	# Make sure that the new tag is the same.
	umoci tag --image "$IMAGE" list
	[ "$status" -eq 0 ]

	for _tag in "${lines[@]}"; do
		umoci tag --image "$IMAGE" stat --tag "$tag"
		[ "$status" -eq 0 ]
		_mediatype="$(echo $output | jq -SMr '.mediatype')"
		_blob="$(echo $output | jq -SMr '.blob')"
		[[ "$_tag" != "${TAG}-newtag" ]] || break
	done
	[[ "$_tag" == "${TAG}-newtag" ]]
	[[ "$_mediatype" == "$mediatype" ]]
	[[ "$_blob" == "$blob" ]]
}

@test "umoci tag rm" {
	# How many tags?
	umoci tag --image "$IMAGE" list
	[ "$status" -eq 0 ]
	[ "${#lines[@]}" -gt 0 ]
	nrefs="${#lines[@]}"

	# Remove the default tag.
	umoci tag --image "$IMAGE" rm --tag "${TAG}"
	[ "$status" -eq 0 ]

	# Make sure the tag is no longer there.
	umoci tag --image "$IMAGE" list
	[ "$status" -eq 0 ]
	[ "${#lines[@]}" -eq "$(($nrefs - 1))" ]

	# Check that the lines don't contain that tag.
	for tag in "${lines[@]}"; do
		[[ "$tag" != "$TAG" ]]
	done

	# Make sure it's truly gone.
	umoci unpack --image "$IMAGE" --from "${TAG}" --bundle "$BATS_TMPDIR/notused"
	[ "$status" -ne 0 ]
}

@test "umoci tag stat" {
	# How many tags?
	umoci tag --image "$IMAGE" list
	[ "$status" -eq 0 ]

	# Just run stat on each of those tags.
	for tag in "${lines[@]}"; do
		umoci tag --image "$IMAGE" stat --tag "$tag"
		[ "$status" -eq 0 ]

		echo "$output" > "$BATS_TMPDIR/tag-stat.$tag"

		sane_run jq -SMr '.mediatype' "$BATS_TMPDIR/tag-stat.$tag"
		[ "$status" -eq 0 ]
		[[ "$output" == "application/vnd.oci.image.manifest.v1+json" ]]

		sane_run jq -SMr '.blob' "$BATS_TMPDIR/tag-stat.$tag"
		[ "$status" -eq 0 ]
		[[ "$output" =~ "sha256:"* ]]

		sane_run jq -SMr '.size' "$BATS_TMPDIR/tag-stat.$tag"
		[ "$status" -eq 0 ]
		[ "$output" -gt 0 ]

		rm -f "$BATS_TMPDIR/tag-stat.$tag"
	done
}