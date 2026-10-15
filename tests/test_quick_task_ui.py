from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[1]
QML = ROOT / "qml" / "components" / "QuickTaskPopup.qml"


class QuickTaskUiTests(unittest.TestCase):
    def setUp(self):
        self.qml = QML.read_text(encoding="utf-8")

    def test_no_radial_orbit_or_hidden_swapped_layout(self):
        for removed in ("Math.sin", "Math.cos", "wheel.orbit", "root.categoryIndex < 0"):
            self.assertNotIn(removed, self.qml)

    def test_stable_category_and_task_lists(self):
        for required in (
            "id: categoryList", "id: templateList", "Layout.fillHeight: true",
            "model: root.categories", "model: root.templates", "clip: true",
        ):
            self.assertIn(required, self.qml)
        self.assertGreaterEqual(self.qml.count("ListView {"), 2)
        self.assertIn("orientation: ListView.Horizontal", self.qml)

    def test_reopens_on_favorites_and_does_not_close_after_add(self):
        self.assertIn("categoryId = 0", self.qml)
        self.assertIn('"name": "Najcz\\u0119stsze"', self.qml)
        self.assertIn("backend.addFromQuickTemplate(id, targetDate, person)", self.qml)
        self.assertIn("++addedCount", self.qml)
        action = self.qml.split("function addPreset(id, title)", 1)[1].split("contentItem: ColumnLayout", 1)[0]
        self.assertNotIn("root.close()", action)

    def test_assignee_selection_kept(self):
        self.assertIn("model: root.assigneeOptions", self.qml)
        self.assertIn("assigneeOptions = backend.assignees", self.qml)
        self.assertIn("selectedMemberId", self.qml)
        self.assertIn("quickAssignee.currentIndex = index", self.qml)
        self.assertIn('"Gotowe (" + root.addedCount', self.qml)

    def test_refresh_when_favorites_change(self):
        self.assertIn("function onDataChanged()", self.qml)
        self.assertIn("root.templates = backend.quickTemplates(root.categoryId)", self.qml)
        self.assertIn("onCategoryIdChanged:", self.qml)


if __name__ == "__main__":
    unittest.main()
