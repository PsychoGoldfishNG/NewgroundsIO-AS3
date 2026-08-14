/**
 * OfflineForeignGuardSuite
 *
 * The write guards on objects loaded from another app.
 *
 * Cross-app access is read-only - no component that writes accepts an app_id -
 * so every write method refuses to run on an object carrying foreignAppId.
 * These tests need no network: the guard fires before anything is sent, which
 * is the whole point of it.
 */
package ngiotest.suites {

    import io.newgrounds.models.objects.Medal;
    import io.newgrounds.models.objects.SaveSlot;
    import io.newgrounds.models.objects.Score;
    import io.newgrounds.models.objects.ScoreBoard;

    import ngiotest.TestContext;
    import ngiotest.TestSuite;

    public class OfflineForeignGuardSuite extends TestSuite {

        /** Any app id that is not ours. Nothing is sent, so it need not exist. */
        private static const OTHER_APP:String = "39685:NJ1KkPGb";

        override public function get suiteName():String {
            return "Offline / Foreign object guards";
        }

        override public function build():void {

            //==================== isForeign ====================

            add("isForeign reflects the stamp", function(t:TestContext):void {
                var medal:Medal = new Medal();
                t.assertFalse(medal.isForeign(), "an unstamped model is local");

                medal.foreignAppId = OTHER_APP;
                t.assertTrue(medal.isForeign(), "a stamped model is foreign");
                t.done();
            });

            add("an empty stamp is not a foreign object", function(t:TestContext):void {
                // A stamp that never took must read as local, or a bug in the
                // stamping path would start blocking ordinary local writes -
                // turning a cross-app nicety into a broken game.
                var medal:Medal = new Medal();
                medal.foreignAppId = "";

                t.assertFalse(medal.isForeign(), "empty string is not a foreign app id");
                t.assertDoesNotThrow(function():void {
                    medal.unlock();
                }, "so unlock() is not blocked");
                t.done();
            });

            //==================== Medal ====================

            add("a foreign medal refuses to unlock", function(t:TestContext):void {
                var medal:Medal = new Medal();
                medal.id = 88366;
                medal.name = "Skull Punk";
                medal.foreignAppId = OTHER_APP;

                var thrown:Error = t.assertThrows(function():void {
                    medal.unlock();
                }, "unlock() on a foreign medal throws");

                if (thrown != null) {
                    t.assertTrue(thrown.message.indexOf(OTHER_APP) >= 0,
                        "the message names the app it came from");
                    t.assertTrue(thrown.message.indexOf("unlock()") >= 0,
                        "and the method that was refused");
                    t.note(thrown.message);
                }
                t.done();
            });

            add("a local medal is not blocked", function(t:TestContext):void {
                // With no core attached, unlock() is a no-op rather than a
                // network call - so reaching the end without throwing is
                // exactly the assertion we want.
                var medal:Medal = new Medal();
                medal.id = 88366;

                t.assertDoesNotThrow(function():void {
                    medal.unlock();
                }, "unlock() on a local medal is allowed");
                t.done();
            });

            //==================== ScoreBoard ====================

            add("a foreign scoreboard refuses to post", function(t:TestContext):void {
                var board:ScoreBoard = new ScoreBoard();
                board.id = 5853;
                board.name = "Cross-app board";
                board.foreignAppId = OTHER_APP;

                var thrown:Error = t.assertThrows(function():void {
                    board.postScore(100);
                }, "postScore() on a foreign board throws");

                if (thrown != null) {
                    t.assertTrue(thrown.message.indexOf("postScore()") >= 0,
                        "the message names the refused method: " + thrown.message);
                }
                t.done();
            });

            add("a foreign scoreboard still allows reads", function(t:TestContext):void {
                // Reading is the one thing cross-app access does allow, so
                // getScores() must not be caught by the guard. It forwards the
                // app_id the board was loaded with - asserted live, since only
                // the gateway can confirm the parameter went out.
                var board:ScoreBoard = new ScoreBoard();
                board.id = 5853;
                board.foreignAppId = OTHER_APP;

                t.assertDoesNotThrow(function():void {
                    board.getScores();
                }, "getScores() on a foreign board is allowed");
                t.done();
            });

            //==================== SaveSlot ====================
            //
            // The important ones. Medal and scoreboard ids are globally unique,
            // so a misdirected write is rejected by the gateway - confusing, but
            // harmless. SaveSlot.id is a per-app SLOT NUMBER and every app has a
            // slot 1, so an unguarded write through a foreign slot SUCCEEDS,
            // silently destroying the player's own save.

            add("a foreign save slot refuses saveData", function(t:TestContext):void {
                var slot:SaveSlot = foreignSlot();

                var thrown:Error = t.assertThrows(function():void {
                    slot.saveData({ score: 1 });
                }, "saveData() on a foreign slot throws");

                if (thrown != null) {
                    t.assertTrue(thrown.message.indexOf("slot 1") >= 0,
                        "and warns which of OUR slots it would have hit");
                    t.note(thrown.message);
                }
                t.done();
            });

            add("a foreign save slot refuses saveDataRaw", function(t:TestContext):void {
                var slot:SaveSlot = foreignSlot();

                var thrown:Error = t.assertThrows(function():void {
                    slot.saveDataRaw("payload");
                }, "saveDataRaw() on a foreign slot throws");

                if (thrown != null) {
                    t.assertTrue(thrown.message.indexOf("saveDataRaw()") >= 0,
                        "naming the low-level method, not the wrapper: " + thrown.message);
                }
                t.done();
            });

            add("a foreign save slot refuses clearData", function(t:TestContext):void {
                var slot:SaveSlot = foreignSlot();

                t.assertThrows(function():void {
                    slot.clearData();
                }, "clearData() on a foreign slot throws");
                t.done();
            });

            add("a foreign save slot still allows loading", function(t:TestContext):void {
                // loadDataRaw reads the absolute URL the server returned with the
                // slot. It needs no app context, so it works cross-app unchanged -
                // and being able to read another app's saves is the reason
                // loadExternalSaveSlots exists at all.
                var slot:SaveSlot = foreignSlot();
                slot.url = null;

                var called:Boolean = false;
                slot.loadDataRaw(function(data:String, error:*):void {
                    called = true;
                    t.assertNull(data, "an empty slot loads as null rather than throwing");
                });

                t.assertTrue(called, "and the callback ran");
                t.done();
            });

            //==================== the guard is per-object ====================

            add("stamping one object does not block its siblings", function(t:TestContext):void {
                // stampForeign walks a whole result, so a bug there could mark
                // more than it should. Confirm the flag is read per-object.
                var foreign:Medal = new Medal();
                foreign.id = 1;
                foreign.foreignAppId = OTHER_APP;

                var local:Medal = new Medal();
                local.id = 2;

                t.assertThrows(function():void {
                    foreign.unlock();
                }, "the stamped medal is blocked");

                t.assertDoesNotThrow(function():void {
                    local.unlock();
                }, "the unstamped one beside it is not");
                t.done();
            });
        }

        //==================== HELPERS ====================

        /** Slot 1 of another app - the case that would otherwise eat our own slot 1. */
        private function foreignSlot():SaveSlot {
            var slot:SaveSlot = new SaveSlot();
            slot.id = 1;
            slot.url = "//uploads.ungrounded.net/example.sav";
            slot.foreignAppId = OTHER_APP;
            return slot;
        }
    }
}
