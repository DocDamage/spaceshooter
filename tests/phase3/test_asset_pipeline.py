import argparse
import hashlib
import json
import sys
import tempfile
import unittest
from pathlib import Path


PROJECT_ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(PROJECT_ROOT / "tools" / "asset_catalog"))
import asset_pipeline  # noqa: E402


class AssetPipelineTests(unittest.TestCase):
    def test_weird_names_are_inventoried_without_touching_sources(self):
        with tempfile.TemporaryDirectory() as temporary:
            source = Path(temporary) / "source"
            source.mkdir()
            weird = source / "Enemy Ship (Final!) 01.PNG"
            weird.write_bytes(b"not-a-real-png-but-still-an-inventory-source")
            before = hashlib.sha256(weird.read_bytes()).hexdigest()
            manifest = asset_pipeline.build_manifest(source, {"category_import_profiles": {"ship": "pixel_art"}})
            self.assertEqual(1, manifest["asset_count"])
            self.assertEqual("enemy_ship_final_01.png", manifest["assets"][0]["normalized_filename"])
            self.assertEqual(before, hashlib.sha256(weird.read_bytes()).hexdigest())
            self.assertEqual("blocked_missing_license", manifest["assets"][0]["validation_status"])

    def test_colliding_names_and_hashes_receive_unique_ids(self):
        with tempfile.TemporaryDirectory() as temporary:
            source = Path(temporary) / "source"
            source.mkdir(parents=True)
            (source / "Same Asset.png").write_bytes(b"same")
            (source / "Same-Asset.PNG").write_bytes(b"same")
            manifest = asset_pipeline.build_manifest(source, {"category_import_profiles": {"uncategorized": "pixel_art"}})
            ids = [item["stable_id"] for item in manifest["assets"]]
            self.assertEqual(len(ids), len(set(ids)))
            self.assertEqual(1, sum(bool(item["duplicate_of"]) for item in manifest["assets"]))

    def test_unlicensed_approval_is_blocked(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            source = root / "source"
            runtime = root / "runtime"
            source.mkdir()
            candidate = source / "candidate.png"
            candidate.write_bytes(b"candidate")
            manifest = asset_pipeline.build_manifest(source, {"category_import_profiles": {"uncategorized": "pixel_art"}})
            manifest["assets"][0].update({
                "import_status": "approved",
                "runtime_path": "res://assets_runtime/test/candidate.png",
            })
            manifest_path = root / "manifest.json"
            manifest_path.write_text(json.dumps(manifest), encoding="utf-8")
            result = asset_pipeline.approve(argparse.Namespace(manifest=str(manifest_path), runtime=str(runtime)))
            self.assertEqual(1, result)
            self.assertFalse((runtime / "test" / "candidate.png").exists())

    def test_runtime_copy_never_overwrites_different_bytes(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            source = root / "source.bin"
            destination = root / "destination.bin"
            source.write_bytes(b"new")
            destination.write_bytes(b"preserve")
            with self.assertRaises(FileExistsError):
                asset_pipeline.safe_copy(source, destination)
            self.assertEqual(b"preserve", destination.read_bytes())


if __name__ == "__main__":
    unittest.main()
