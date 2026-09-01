"""Unit tests for the browser runtime contract verifier."""

from __future__ import annotations

import json
import sys
import unittest
from pathlib import Path
from tempfile import TemporaryDirectory

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "scripts"))

import verify_bowser_contract  # noqa: E402


class VerifyBowserContractTests(unittest.TestCase):
    """Reject contract drift and incomplete capability envelopes."""

    def test_matching_capabilities_pass(self) -> None:
        contract = self.contract()
        verify_bowser_contract.verify_capabilities(contract, self.capabilities())

    def test_version_and_feature_drift_fail(self) -> None:
        contract = self.contract()
        wrong_version = self.capabilities()
        wrong_version["result"]["version"] = "0.2.0"
        with self.assertRaisesRegex(ValueError, "version"):
            verify_bowser_contract.verify_capabilities(contract, wrong_version)

        missing_feature = self.capabilities()
        missing_feature["result"]["features"]["history"] = False
        with self.assertRaisesRegex(ValueError, "history"):
            verify_bowser_contract.verify_capabilities(contract, missing_feature)

    def test_contract_schema_rejects_duplicate_or_unknown_requirements(self) -> None:
        with TemporaryDirectory() as temporary_directory:
            contract_path = Path(temporary_directory) / "contract.json"
            document = {
                "schema_version": 1,
                "bowser_version": "0.3.0",
                "envelope_version": 1,
                "required_features": ["history", "history"],
            }
            contract_path.write_text(json.dumps(document), encoding="utf-8")

            with self.assertRaisesRegex(ValueError, "unique"):
                verify_bowser_contract.load_contract(contract_path)

    @staticmethod
    def contract() -> object:
        return verify_bowser_contract.RuntimeContract(
            bowser_version="0.3.0",
            envelope_version=1,
            required_features=("history", "kiosk_launch", "live_inventory"),
        )

    @staticmethod
    def capabilities() -> dict[str, object]:
        return {
            "envelope": 1,
            "ok": True,
            "result": {
                "version": "0.3.0",
                "features": {
                    "history": True,
                    "kiosk_launch": True,
                    "live_inventory": True,
                },
            },
        }


if __name__ == "__main__":
    unittest.main()
