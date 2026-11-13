import contextlib
import copy
import importlib.util
import io
import json
from pathlib import Path
import stat
import tempfile
import unittest

spec = importlib.util.spec_from_file_location("recovery", Path(__file__).with_name("recover-personal-state.py"))
recovery = importlib.util.module_from_spec(spec)
spec.loader.exec_module(recovery)
ACCOUNT = "172346499417"
REGION = "us-east-2"
PASSWORD = "fictional-test-password-12345"


def resource(kind, **attrs):
    return {"mode": "managed", "type": kind, "instances": [{"attributes": attrs}]}


def state():
    return {"resources": [
        resource("aws_eks_cluster", arn=f"arn:aws:eks:{REGION}:{ACCOUNT}:cluster/toggle-cluster", version="1.36"),
        resource("aws_db_instance", password=PASSWORD, engine_version="16.10"),
        resource("aws_db_instance", password=PASSWORD, engine_version="16.10"),
    ]}


class RecoveryTests(unittest.TestCase):
    def test_recover_private_files_without_output_or_rotation(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            output = io.StringIO()
            with contextlib.redirect_stdout(output):
                self.assertTrue(recovery.recover(state(), root, ACCOUNT, REGION))
                self.assertTrue(recovery.recover(state(), root, ACCOUNT, REGION))
            self.assertEqual(output.getvalue(), "")
            self.assertEqual((root / "rds-password").read_text(), PASSWORD)
            self.assertEqual(json.loads((root / "versions.json").read_text()), {"eks": "1.36", "postgres": "16.10"})
            self.assertEqual(stat.S_IMODE((root / "rds-password").stat().st_mode), 0o600)

    def test_existing_password_mismatch_is_not_overwritten(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            (root / "rds-password").write_text("different-local-password")
            with self.assertRaises(ValueError):
                recovery.recover(state(), root, ACCOUNT, REGION)
            self.assertEqual((root / "rds-password").read_text(), "different-local-password")
            self.assertFalse((root / "versions.json").exists())

    def test_wrong_account_rejected_before_writing(self):
        with tempfile.TemporaryDirectory() as directory:
            with self.assertRaises(ValueError):
                recovery.recover(state(), Path(directory), "111122223333", REGION)
            self.assertEqual(list(Path(directory).iterdir()), [])

    def test_missing_remote_password_never_generates_replacement(self):
        broken = copy.deepcopy(state())
        del broken["resources"][1]["instances"][0]["attributes"]["password"]
        with tempfile.TemporaryDirectory() as directory:
            with self.assertRaises(ValueError):
                recovery.recover(broken, Path(directory), ACCOUNT, REGION)
            self.assertFalse((Path(directory) / "rds-password").exists())

    def test_empty_state_allows_initial_setup(self):
        with tempfile.TemporaryDirectory() as directory:
            self.assertFalse(recovery.recover({"resources": []}, Path(directory), ACCOUNT, REGION))
            self.assertEqual(list(Path(directory).iterdir()), [])


if __name__ == "__main__":
    unittest.main()
