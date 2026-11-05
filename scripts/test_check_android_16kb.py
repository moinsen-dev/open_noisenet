import unittest

from check_android_16kb import segment_issues


class SegmentChecks(unittest.TestCase):
    def test_rejects_small_load_alignment(self):
        segments = "LOAD 0x0 0x0 0x0 0x1000 0x1000 R E 0x1000"
        self.assertIn("LOAD alignment below 16 KB", segment_issues(segments))

    def test_rejects_writable_data_on_relro_page(self):
        segments = """
          LOAD 0x4000 0x4000 0x4000 0x3000 0x3000 RW 0x4000
          GNU_RELRO 0x4000 0x4000 0x4000 0x1000 0x1000 R 0x1
        """
        self.assertIn("writable LOAD shares the final RELRO page", segment_issues(segments))

    def test_accepts_separate_writable_page(self):
        segments = """
          LOAD 0x0 0x0 0x0 0x1000 0x1000 R 0x4000
          LOAD 0x4000 0x4000 0x4000 0x1000 0x1000 RW 0x4000
          GNU_RELRO 0x0 0x0 0x0 0x1000 0x1000 R 0x1
        """
        self.assertEqual([], segment_issues(segments))

    def test_accepts_page_aligned_relro_end(self):
        segments = """
          LOAD 0x0 0x0 0x0 0x5000 0x5000 RW 0x4000
          GNU_RELRO 0x0 0x0 0x0 0x4000 0x4000 R 0x1
        """
        self.assertEqual([], segment_issues(segments))

    def test_rejects_unreadable_segments(self):
        self.assertIn("no LOAD segments", segment_issues("garbled output"))


if __name__ == "__main__":
    unittest.main()
