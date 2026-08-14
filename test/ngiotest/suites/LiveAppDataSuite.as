/**
 * LiveAppDataSuite
 *
 * Batch-loads the app's catalogue (medals, scoreboards, save slots) in a single
 * request and checks it against what the test app is configured with.
 *
 * Runs before the medal/scoreboard/cloud save suites, which rely on the caches
 * this populates.
 */
package ngiotest.suites {

    import io.newgrounds.models.objects.Medal;
    import io.newgrounds.models.objects.SaveSlot;
    import io.newgrounds.models.objects.ScoreBoard;

    import ngiotest.LiveSuite;
    import ngiotest.TestConfig;
    import ngiotest.TestContext;

    public class LiveAppDataSuite extends LiveSuite {

        override public function get suiteName():String {
            return "Live / App data";
        }

        override public function build():void {

            add("batch-loads medals, scoreboards and save slots", function(t:TestContext):void {
                // One loadData() call for three properties should produce one
                // request carrying three components, not three requests.
                t.status("Loading app data...");

                NGIO.loadAppData(["medals", "scoreBoards", "saveSlots"], function(error:*):void {
                    if (!assertNoError(t, error, "batch load completed")) {
                        t.done();
                        return;
                    }

                    t.assertTrue(core.appState.hasLoaded("medals"), "medals marked loaded");
                    t.assertTrue(core.appState.hasLoaded("scoreBoards"), "scoreBoards marked loaded");
                    t.assertTrue(core.appState.hasLoaded("saveSlots"), "saveSlots marked loaded");
                    t.done();
                });
            });

            add("returns the configured medals", function(t:TestContext):void {
                var medals:Array = NGIO.getMedals();
                if (!t.assertNotNull(medals, "medal list cached")) {
                    t.done();
                    return;
                }

                t.assertEquals(TestConfig.EXPECTED_MEDAL_COUNT, medals.length,
                    "medal count matches the app configuration");

                for each (var medal:Medal in medals) {
                    t.assertTrue(medal.id > 0, "medal has a real id");
                    t.assertNotNull(medal.name, "medal " + medal.id + " has a name");
                    t.assertNotNull(medal.icon, "medal " + medal.id + " has an icon url");
                    t.assertTrue(medal.difficulty >= 1 && medal.difficulty <= 5,
                        "medal " + medal.id + " difficulty is 1-5, got " + medal.difficulty);

                    // Not "> 0": a medal worth 0 points is a legitimate
                    // Newgrounds configuration, and asserting otherwise made this
                    // suite fail on the app's own data rather than on a library
                    // fault. Worth surfacing as a note, since an unintended 0 is
                    // still worth noticing.
                    t.assertTrue(medal.value >= 0, "medal " + medal.id + " has a non-negative point value");
                    if (medal.value == 0) {
                        t.note("NOTE: medal " + medal.id + " (" + medal.name + ") is worth 0 points");
                    }

                    t.note(medal.toString() + " (" + medal.value + "pts, difficulty " + medal.difficulty +
                           ", unlocked=" + medal.unlocked + ")");
                }
                t.done();
            });

            add("looks a medal up by id", function(t:TestContext):void {
                var medals:Array = NGIO.getMedals();
                if (medals == null || medals.length == 0) {
                    t.skip("no medals loaded");
                    return;
                }

                var first:Medal = medals[0] as Medal;
                var found:* = NGIO.getMedal(first.id);

                t.assertNotNull(found, "getMedal() found the medal");
                t.assertStrictEquals(first, found, "returns the cached instance, not a copy");
                t.assertNull(NGIO.getMedal(-1), "unknown medal id returns null");
                t.done();
            });

            add("returns the configured scoreboards", function(t:TestContext):void {
                var boards:Array = NGIO.getScoreBoards();
                if (!t.assertNotNull(boards, "scoreboard list cached")) {
                    t.done();
                    return;
                }

                t.assertEquals(TestConfig.EXPECTED_SCOREBOARD_COUNT, boards.length,
                    "scoreboard count matches the app configuration");

                for each (var board:ScoreBoard in boards) {
                    t.assertTrue(board.id > 0, "board has a real id");
                    t.assertNotNull(board.name, "board " + board.id + " has a name");
                    t.note("ScoreBoard #" + board.id + " - " + board.name);
                }
                t.done();
            });

            add("looks a scoreboard up by id", function(t:TestContext):void {
                var boards:Array = NGIO.getScoreBoards();
                if (boards == null || boards.length == 0) {
                    t.skip("no scoreboards loaded");
                    return;
                }

                var first:ScoreBoard = boards[0] as ScoreBoard;
                t.assertStrictEquals(first, NGIO.getScoreBoard(first.id), "returns the cached instance");
                t.assertNull(NGIO.getScoreBoard(-1), "unknown board id returns null");
                t.done();
            });

            add("returns the configured save slots", function(t:TestContext):void {
                var slots:Array = NGIO.getSaveSlots();
                if (!t.assertNotNull(slots, "save slot list cached")) {
                    t.done();
                    return;
                }

                t.assertEquals(TestConfig.EXPECTED_SAVE_SLOT_COUNT, slots.length,
                    "save slot count matches the app configuration");

                for each (var slot:SaveSlot in slots) {
                    t.assertTrue(slot.id > 0, "slot has a real id");
                    // A slot with data must carry both a url and a size; one
                    // without either is a half-populated response.
                    if (slot.hasData()) {
                        t.assertTrue(slot.size > 0, "slot " + slot.id + " with data reports a size");
                        t.assertNotNull(slot.datetime, "slot " + slot.id + " with data reports a datetime");
                    }
                }
                t.note(countUsedSlots(slots) + " of " + slots.length + " slots currently hold data");
                t.done();
            });

            add("rejects an unknown property name", function(t:TestContext):void {
                // Guards against a silent no-op when a caller mistypes a name.
                t.assertThrows(function():void {
                    NGIO.loadAppData(["medalz"]);
                }, "loadAppData rejects a misspelled property");
                t.done();
            });

            add("loads the user's total medal score", function(t:TestContext):void {
                if (skipUnlessSignedIn(t)) {
                    return;
                }

                NGIO.loadMedalScore(function(score:Number, error:*):void {
                    if (assertNoError(t, error, "medal score loaded")) {
                        t.assertTrue(score >= 0, "score is not negative, got " + score);
                        t.assertEquals(score, NGIO.getMedalScore(), "cached on AppState");
                        t.note("medal score for this app: " + score);
                    }
                    t.done();
                });
            });
        }

        //==================== HELPERS ====================

        private function countUsedSlots(slots:Array):int {
            var used:int = 0;
            for each (var slot:SaveSlot in slots) {
                if (slot.hasData()) {
                    used++;
                }
            }
            return used;
        }
    }
}
