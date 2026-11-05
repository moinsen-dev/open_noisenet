"""Android backup rules exclude both app-owned recording directories."""
from pathlib import Path
import unittest
import xml.etree.ElementTree as ET


ROOT = Path(__file__).resolve().parents[1] / "mobile/android/app/src/main"
ANDROID = "{http://schemas.android.com/apk/res/android}"
EXPECTED = {
    ("root", "app_flutter/recordings/"),
    ("root", "app_flutter/continuous_recordings/"),
}


class AudioBackupRulesTest(unittest.TestCase):
    def test_manifest_references_both_rules(self):
        app = ET.parse(ROOT / "AndroidManifest.xml").getroot().find("application")
        self.assertEqual(app.get(ANDROID + "fullBackupContent"), "@xml/backup_rules")
        self.assertEqual(app.get(ANDROID + "dataExtractionRules"), "@xml/data_extraction_rules")

    def test_audio_excluded_from_each_backup_mode(self):
        old = ET.parse(ROOT / "res/xml/backup_rules.xml").getroot()
        new = ET.parse(ROOT / "res/xml/data_extraction_rules.xml").getroot()
        for section in [old, new.find("cloud-backup"), new.find("device-transfer")]:
            self.assertIsNotNone(section)
            exclusions = {(item.get("domain"), item.get("path"))
                          for item in section.findall("exclude")}
            self.assertTrue(EXPECTED.issubset(exclusions))


if __name__ == "__main__":
    unittest.main()
