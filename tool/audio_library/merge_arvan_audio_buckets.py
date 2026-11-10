#!/usr/bin/env python3
"""Merge several ArvanCloud S3 buckets into one, then prove the copy is sound.

The audio library resolves every track against a single base URL, so the three
per-category buckets have to end up under one root. Buckets are never modified:
objects are copied, the source is left untouched, and the destination is verified
before anything is called done.

Why verification is not optional: the yaqeen bucket already had two objects that
listed fine but answered 403, and the first sampler missed them because it only
probed five files. A copy that "reports success" can still land objects the app
cannot stream, so every destination object is re-fetched with a Range request and
compared against the source listing's size. ETag is compared too; for a
single-part upload S3 sets it to the object's MD5, which catches a truncated
transfer that a size check alone would miss on the odd collision.

Credentials are read from the environment only (ARVAN_ACCESS_KEY /
ARVAN_SECRET_KEY / ARVAN_ENDPOINT). Nothing is read from a file and nothing is
printed, so a key cannot leak into a shell transcript or a log.

    # dry run: lists what would be copied, touches nothing
    python merge_audio_buckets.py --dest audio

    # real run
    python merge_audio_buckets.py --dest audio --execute

Requires boto3 for the upload path; the dry run works without it.
"""

import argparse
import os
import ssl
import sys
import urllib.parse
import urllib.request
import xml.etree.ElementTree as ET

S3_NS = "{http://s3.amazonaws.com/doc/2006-03-01/}"
REGION = "ir-thr-at1"
PUBLIC_HOST = "{bucket}.s3.{region}.arvanstorage.ir"

# Buckets to merge. Key prefixes are preserved exactly as they are today, so no
# object is renamed: the manifest carries full keys, and a rename would be a
# chance to break a link that currently works.
#
# There is deliberately no separate "misc" bucket. The Behzad Faghihi lecture
# already lives in t-sokhanrani, and every candidate misc bucket this account can
# reach is a dead end: "misc" and "audio" both answer AccessDenied because they
# belong to a different account. Filing the track by manifest category is what
# actually decides whether it reads as misc or as a Ziaei lecture, so grouping
# it there is sufficient and moving bytes around is not.
#
# "t.audio" is the destination: ArvanCloud's S3 API rejects dots in bucket names,
# but the panel accepts them, so a dotted bucket can be made from the panel
# only. It is addressed path-style -- see public_base().
SOURCES = [
    "yaqeen",
    "nasheed",
    "t-sokhanrani",
]


def make_client(endpoint, region=REGION):
    """A boto3 S3 client from the environment, or None if boto3/keys are absent."""
    try:
        import boto3
    except ImportError:
        return None
    access = os.environ.get("ARVAN_ACCESS_KEY")
    secret = os.environ.get("ARVAN_SECRET_KEY")
    if not access or not secret:
        return None
    return boto3.client(
        "s3", endpoint_url=endpoint, region_name=region,
        aws_access_key_id=access, aws_secret_access_key=secret,
    )


def list_objects(bucket, region=REGION, s3=None):
    """Return {key: (size, etag)} for a bucket.

    Tries the unsigned public listing first because it needs no credentials and
    proves the bucket really is publicly readable. A private bucket answers 403
    instead, so fall back to a signed listing rather than failing outright --
    otherwise a freshly created, still-private destination bucket would look
    like an error and block the dry run.
    """
    ctx = ssl.create_default_context()
    ctx.check_hostname = False
    ctx.verify_mode = ssl.CERT_NONE
    host = PUBLIC_HOST.format(bucket=bucket, region=region)
    base = public_base(bucket, region)
    listing_root = base + "/"
    out, token = {}, None
    while True:
        url = f"{listing_root}?list-type=2&max-keys=1000"
        if token:
            url += "&continuation-token=" + urllib.parse.quote(token)
        try:
            with urllib.request.urlopen(url, context=ctx, timeout=60) as resp:
                root = ET.fromstring(resp.read())
        except urllib.error.HTTPError as e:
            if e.code in (403, 401) and s3 is not None:
                return _list_objects_signed(s3, bucket)
            if e.code == 404:
                raise RuntimeError(
                    f"bucket {bucket!r} does not exist on {host}") from e
            raise RuntimeError(
                f"cannot list {bucket!r} at {listing_root}: HTTP {e.code}. The "
                f"bucket is private and no credentials were supplied - set "
                f"ARVAN_ACCESS_KEY and ARVAN_SECRET_KEY, or make the bucket "
                f"public.") from e
        for obj in root.findall(S3_NS + "Contents"):
            key = obj.find(S3_NS + "Key").text
            if key.endswith("/"):
                continue
            etag = (obj.find(S3_NS + "ETag").text or "").strip('"')
            out[key] = (int(obj.find(S3_NS + "Size").text), etag)
        nxt = root.find(S3_NS + "NextContinuationToken")
        if nxt is None:
            return out
        token = nxt.text


def _list_objects_signed(s3, bucket):
    """Same mapping as list_objects, via an authenticated ListObjectsV2."""
    out, token = {}, None
    while True:
        kwargs = {"Bucket": bucket, "MaxKeys": 1000}
        if token:
            kwargs["ContinuationToken"] = token
        resp = s3.list_objects_v2(**kwargs)
        for obj in resp.get("Contents", []):
            key = obj["Key"]
            if key.endswith("/"):
                continue
            out[key] = (obj["Size"], obj["ETag"].strip('"'))
        if not resp.get("IsTruncated"):
            return out
        token = resp.get("NextContinuationToken")


def public_base(bucket, region=REGION):
    """Public base URL for a bucket, choosing a working addressing style.

    The obvious form, https://<bucket>.s3.<region>.arvanstorage.ir, only works
    for names that are a single DNS label. ArvanCloud's certificate is
    *.s3.<region>.arvanstorage.ir, which matches exactly one label, so a dotted
    name like t.audio -- which lands two labels ahead of s3 -- answers 503.

    Path style keeps the hostname single-label and the bucket in the path, which
    verifies against the certificate normally. It is also exactly what
    AudioLibraryConfig.objectUrl() produces from a base of
    https://s3.<region>.arvanstorage.ir/<bucket>, so the app needs no change.
    """
    if "." in bucket:
        return f"https://s3.{region}.arvanstorage.ir/{bucket}"
    return f"https://{PUBLIC_HOST.format(bucket=bucket, region=region)}"


def probe_public(bucket, key, region=REGION, probe=1024):
    """(status, bytes) for a ranged GET against the public endpoint."""
    url = "{}/{}".format(
        public_base(bucket, region),
        "/".join(urllib.parse.quote(s) for s in key.split("/"))
    )
    ctx = ssl.create_default_context()
    ctx.check_hostname = False
    ctx.verify_mode = ssl.CERT_NONE
    req = urllib.request.Request(url)
    req.add_header("Range", f"bytes=0-{probe - 1}")
    try:
        with urllib.request.urlopen(req, context=ctx, timeout=45) as resp:
            return resp.status, len(resp.read())
    except urllib.error.HTTPError as e:
        return e.code, 0
    except Exception:
        return 0, 0


def plan(sources, dest, s3=None):
    """Build the copy plan and refuse to proceed on any key collision."""
    moves, seen, collisions = [], {}, []
    total = 0
    for src in sources:
        for key, (size, etag) in sorted(list_objects(src, s3=s3).items()):
            if src == dest:
                continue
            if key in seen:
                collisions.append((key, seen[key], src))
                continue
            seen[key] = src
            moves.append((src, dest, key, size, etag))
            total += size
    return moves, collisions, total


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--dest", required=True, help="destination bucket name")
    ap.add_argument("--execute", action="store_true",
                    help="actually copy (default is a dry run)")
    ap.add_argument("--skip-existing", action="store_true", default=True)
    ap.add_argument("--endpoint",
                    default=os.environ.get(
                        "ARVAN_ENDPOINT", f"https://s3.{REGION}.arvanstorage.ir"))
    args = ap.parse_args()

    # Build the client up front so a private source bucket can be listed during
    # the dry run, not just during the upload.
    s3 = make_client(args.endpoint)

    print(f"destination bucket: {args.dest}   region: {REGION}")
    print(f"credentials       : {'loaded' if s3 is not None else 'none (public buckets only)'}")
    try:
        moves, collisions, total = plan(SOURCES, args.dest, s3)
    except RuntimeError as e:
        print(f"\nERROR: {e}", file=sys.stderr)
        return 2

    print(f"\nsources: {', '.join(SOURCES)}")
    print(f"objects to copy: {len(moves)}")
    print(f"total size     : {total:,} bytes ({total / 1048576:.1f} MiB)")

    by_src = {}
    for src, _, key, size, _ in moves:
        by_src.setdefault(src, [0, 0])
        by_src[src][0] += 1
        by_src[src][1] += size
    print("\nper source:")
    for src, (n, b) in sorted(by_src.items()):
        print(f"  {src:<16} {n:>4} objects  {b:>13,} bytes  ({b / 1048576:.1f} MiB)")

    if collisions:
        print("\nKEY COLLISIONS - refusing to continue:", file=sys.stderr)
        for key, a, b in collisions:
            print(f"  {key!r} exists in both {a} and {b}", file=sys.stderr)
        return 2

    # Report what is already in the destination so a re-run is cheap.
    try:
        existing = list_objects(args.dest, s3=s3)
        already = sum(1 for _, _, k, size, _ in moves
                      if k in existing and existing[k][0] == size)
        print(f"\nalready present in {args.dest}: {already}/{len(moves)}")
    except Exception as e:
        existing = {}
        already = 0
        print(f"\n(destination not listable yet: {e})")

    todo = [m for m in moves if m[2] not in existing or existing[m[2]][0] != m[3]]
    print(f"would copy now    : {len(todo)}")

    if not args.execute:
        print("\nDRY RUN - nothing was changed. Re-run with --execute to copy.")
        print("\nfirst 5 moves:")
        for src, _, key, size, _ in todo[:5]:
            print(f"  {src:<16} -> {args.dest}/{key}  ({size:,} bytes)")
        return 0

    # ---- real run ----------------------------------------------------------
    if s3 is None:
        try:
            import boto3  # noqa: F401
        except ImportError:
            print("\nboto3 is required for the upload path: pip install boto3",
                  file=sys.stderr)
            return 3
        print("\nSet ARVAN_ACCESS_KEY and ARVAN_SECRET_KEY in the environment.",
              file=sys.stderr)
        return 3

    copied = failed = 0
    for src, dst, key, size, _ in todo:
        # Server-side copy: the bytes never travel through this machine, which
        # turns a 500 MiB job into a metadata operation. It also reads the
        # source with the credentials rather than the public URL, so objects
        # that are private at the source (yaqeen/11 and yaqeen/13 answer 403)
        # still copy. Uploading them with public-read fixes them on the way in.
        try:
            s3.copy_object(
                Bucket=dst, Key=key,
                CopySource={"Bucket": src, "Key": key},
                ACL="public-read",
                ContentType="audio/ogg",
                MetadataDirective="REPLACE",
            )
            copied += 1
            print(f"  ok   {dst}/{key} ({size:,})")
        except Exception as e:
            print(f"  FAIL {dst}/{key}: {e}", file=sys.stderr)
            failed += 1
    print(f"\ncopied {copied}, failed {failed}")

    # ---- verify the destination, not the source ----------------------------
    print("\nverifying destination (public ranged GET + size + ETag)...")
    try:
        # Signed: the objects are public-read, but the bucket itself may still
        # refuse anonymous listings, and that must not be read as a bad copy.
        dest_listing = list_objects(args.dest, s3=s3)
    except Exception as e:
        print(f"  cannot list destination: {e}", file=sys.stderr)
        return 1

    bad_size, bad_etag, not_public = [], [], []
    for src, dst, key, size, etag in moves:
        got = dest_listing.get(key)
        if got is None:
            bad_size.append((key, "missing"))
            continue
        if got[0] != size:
            bad_size.append((key, f"{got[0]} != {size}"))
            continue
        if etag and got[1] and got[1] != etag:
            bad_etag.append((key, f"{got[1]} != {etag}"))

    for key in [m[2] for m in moves]:
        status, got_bytes = probe_public(args.dest, key)
        if status != 206 or got_bytes != min(1024, dest_listing[key][0]):
            not_public.append((key, f"HTTP {status}, {got_bytes} bytes"))

    print(f"  size mismatches : {len(bad_size)}")
    print(f"  etag mismatches : {len(bad_etag)}")
    print(f"  not public/206  : {len(not_public)}")
    for key, why in (bad_size + bad_etag + not_public)[:20]:
        print(f"    {why:<28} {key}")
    if bad_size or bad_etag or not_public:
        print("\nVERDICT: destination is not yet correct.", file=sys.stderr)
        return 1
    print("\nVERDICT: every object is present, size- and etag-identical, and "
          "publicly seekable.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
