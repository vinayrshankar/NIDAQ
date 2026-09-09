from pathlib import Path
import base64
import hashlib

EXPECTED_SIZE = 51916
EXPECTED_SHA256 = "272a66274c2eb5bed0eae2f2dac6f2e0fd533e6b81e1fb2a2edd63720f676670"
CHUNK_DIR = Path("tools/v4_03_chunks")
OUT = Path("NI_MultiChannel_Recorder_v4_03.m")

parts = sorted(CHUNK_DIR.glob("part_*.b64"))
if len(parts) != 9:
    raise SystemExit(f"Expected 9 source chunks, found {len(parts)}")

encoded = "".join(p.read_text(encoding="ascii").strip() for p in parts)
raw = base64.b64decode(encoded, validate=True)
sha = hashlib.sha256(raw).hexdigest()

if len(raw) != EXPECTED_SIZE:
    raise SystemExit(f"Size mismatch: expected {EXPECTED_SIZE}, got {len(raw)}")
if sha != EXPECTED_SHA256:
    raise SystemExit(f"SHA-256 mismatch: expected {EXPECTED_SHA256}, got {sha}")

OUT.write_bytes(raw)
print(f"Verified and wrote {OUT}: {len(raw)} bytes, SHA-256 {sha}")
