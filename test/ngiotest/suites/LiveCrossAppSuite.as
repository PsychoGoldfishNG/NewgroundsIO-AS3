/**
 * LiveCrossAppSuite
 *
 * Exercises NGIO's loadExternal* methods - read-only access to another app's
 * medals, scores and cloud saves via the gateway's app_id parameter.
 *
 * Two things are being tested here, and the second matters more:
 *
 *  1. that a permitted cross-app read returns the other app's data
 *  2. that this app's own AppState is completely untouched by it
 *
 * AppState models exactly one app. A foreign medal list merged into it would
 * replace the local list wholesale and mark it loaded, so NGIO.getMedals()
 * would start handing the game another app's medals. Every test below
 * re-checks the local caches afterwards.
 */
package ngiotest.suites {

    import io.newgrounds.BaseObject;
    import io.newgrounds.models.objects.Medal;
    import io.newgrounds.models.objects.Response;
    import io.newgrounds.models.objects.SaveSlot;
    import io.newgrounds.models.objects.Score;
    import io.newgrounds.models.objects.ScoreBoard;

    import ngiotest.LiveSuite;
    import ngiotest.TestConfig;
    import ngiotest.TestContext;

    public class LiveCrossAppSuite extends LiveSuite {

        /** Snapshot of the local caches, taken before any cross-app call */
        private var localMedals:Array;
        private var localSaveSlots:Array;
        private var localMedalCount:int;
        private var localSlotCount:int;

        override public function get suiteName():String {
            return "Live / Cross-app access";
        }

        override public function setUp(done:Function):void {
            var self:LiveCrossAppSuite = this;

            super.setUp(function():void {
                // Runs after LiveAppDataSuite, so these are populated. Held by
                // reference AND by count: the guard has to stop both a wholesale
                // replacement and an in-place merge.
                self.localMedals = NGIO.getMedals();
                self.localSaveSlots = NGIO.getSaveSlots();
                self.localMedalCount = (self.localMedals != null) ? self.localMedals.length : -1;
                self.localSlotCount = (self.localSaveSlots != null) ? self.localSaveSlots.length : -1;
                done.call(null);
            });
        }

        override public function build():void {

            //==================== ARGUMENT VALIDATION ====================

            add("rejects an empty external app id", function(t:TestContext):void {
                t.assertThrows(function():void {
                    NGIO.loadExternalMedals(null);
                }, "null app id should throw");

                t.assertThrows(function():void {
                    NGIO.loadExternalMedals("");
                }, "empty app id should throw");
                t.done();
            });

            add("rejects this app's own id", function(t:TestContext):void {
                // Passing your own id is a programming error, not a cross-app
                // read: it would behave like loadMedals() except uncached, which
                // is a miserable thing to debug later.
                var thrown:Error = t.assertThrows(function():void {
                    NGIO.loadExternalMedals(TestConfig.APP_ID);
                }, "own app id should throw");

                if (thrown != null) {
                    t.assertTrue(thrown.message.indexOf("own ID") >= 0,
                        "and the message explains why: " + thrown.message);
                }
                t.done();
            });

            //==================== MEDALS ====================

            add("loads medals from an app that granted access", function(t:TestContext):void {
                NGIO.loadExternalMedals(TestConfig.READABLE_FOREIGN_APP_ID,
                    function(medals:Array, error:*):void {

                        if (!assertNoError(t, error, "loadExternalMedals succeeded")) {
                            t.done();
                            return;
                        }

                        if (t.assertNotNull(medals, "foreign medal list returned")) {
                            t.assertTrue(medals.length > 0, "and it is not empty");
                            for each (var medal:Medal in medals) {
                                t.assertIsType(medal, Medal, "entry is a typed Medal");
                                t.assertEquals(TestConfig.READABLE_FOREIGN_APP_ID, medal.foreignAppId,
                                    "medal " + medal.id + " is stamped with its source app");
                            }
                            t.note("app " + TestConfig.READABLE_FOREIGN_APP_ID + " returned " +
                                   medals.length + " medal(s)");
                        }

                        assertLocalCachesIntact(t);
                        t.done();
                    });
            });

            add("foreign medals never enter the local cache", function(t:TestContext):void {
                // The important one. Asserts identity, not just count: a merge
                // would have kept the array but rewritten the Medal objects in it.
                if (localMedals == null) {
                    t.skip("local medals were not loaded, nothing to protect");
                    return;
                }

                var namesBefore:String = describeMedals(localMedals);

                NGIO.loadExternalMedals(TestConfig.READABLE_FOREIGN_APP_ID,
                    function(medals:Array, error:*):void {

                        t.assertStrictEquals(localMedals, NGIO.getMedals(),
                            "getMedals() still returns the original local array");
                        t.assertEquals(localMedalCount, NGIO.getMedals().length,
                            "local medal count unchanged");
                        t.assertEquals(namesBefore, describeMedals(NGIO.getMedals()),
                            "local medal ids, names and values all unchanged");

                        // Every local medal must still be findable by its own id
                        for each (var medal:Medal in localMedals) {
                            t.assertStrictEquals(medal, NGIO.getMedal(medal.id),
                                "local medal " + medal.id + " still resolves to the same instance");
                            t.assertNull(medal.foreignAppId,
                                "local medal " + medal.id + " was not stamped as foreign");
                        }
                        t.done();
                    });
            });

            //==================== SCORES ====================

            add("loads scores from an app that granted access", function(t:TestContext):void {
                NGIO.loadExternalScores(
                    TestConfig.READABLE_FOREIGN_APP_ID,
                    TestConfig.READABLE_FOREIGN_SCOREBOARD_ID,
                    { period: "A", limit: 10 },
                    function(scores:Array, error:*):void {

                        if (!assertNoError(t, error, "loadExternalScores succeeded")) {
                            t.done();
                            return;
                        }

                        if (t.assertNotNull(scores, "foreign score list returned")) {
                            t.assertTrue(scores.length <= 10, "respects the requested limit");

                            for each (var score:Score in scores) {
                                t.assertIsType(score, Score, "entry is a typed Score");
                                t.assertEquals(TestConfig.READABLE_FOREIGN_APP_ID, score.foreignAppId,
                                    "score is stamped with its source app");

                                // Nested models must be stamped too - a caller can
                                // easily end up holding just the User
                                if (score.user != null) {
                                    t.assertEquals(TestConfig.READABLE_FOREIGN_APP_ID, score.user.foreignAppId,
                                        "nested user is stamped as well");
                                }
                            }
                            t.note("board " + TestConfig.READABLE_FOREIGN_SCOREBOARD_ID + " on app " +
                                   TestConfig.READABLE_FOREIGN_APP_ID + " returned " +
                                   scores.length + " all-time score(s)");
                        }

                        assertLocalCachesIntact(t);
                        t.done();
                    });
            });

            add("applies score filters to a cross-app read", function(t:TestContext):void {
                NGIO.loadExternalScores(
                    TestConfig.READABLE_FOREIGN_APP_ID,
                    TestConfig.READABLE_FOREIGN_SCOREBOARD_ID,
                    { period: "A", limit: 1 },
                    function(scores:Array, error:*):void {
                        if (assertNoError(t, error, "limited cross-app read succeeded")) {
                            if (t.assertNotNull(scores, "scores returned")) {
                                t.assertTrue(scores.length <= 1, "returned at most one score");
                            }
                        }
                        t.done();
                    });
            });

            add("validates score filters the same way local reads do", function(t:TestContext):void {
                t.assertThrows(function():void {
                    NGIO.loadExternalScores(TestConfig.READABLE_FOREIGN_APP_ID,
                        TestConfig.READABLE_FOREIGN_SCOREBOARD_ID, { limit: 0 });
                }, "limit 0 should throw");

                t.assertThrows(function():void {
                    NGIO.loadExternalScores(TestConfig.READABLE_FOREIGN_APP_ID,
                        TestConfig.READABLE_FOREIGN_SCOREBOARD_ID, { limit: 101 });
                }, "limit 101 should throw");

                t.assertThrows(function():void {
                    NGIO.loadExternalScores(TestConfig.READABLE_FOREIGN_APP_ID,
                        TestConfig.READABLE_FOREIGN_SCOREBOARD_ID, { user_id: "not-a-number" });
                }, "mistyped user_id should throw");
                t.done();
            });

            add("a foreign scoreboard never enters the local board cache", function(t:TestContext):void {
                var boardsBefore:Array = NGIO.getScoreBoards();
                if (boardsBefore == null) {
                    t.skip("local scoreboards were not loaded, nothing to protect");
                    return;
                }

                var fingerprint:String = describeBoards(boardsBefore);

                NGIO.loadExternalScores(
                    TestConfig.READABLE_FOREIGN_APP_ID,
                    TestConfig.READABLE_FOREIGN_SCOREBOARD_ID,
                    { period: "A", limit: 1 },
                    function(scores:Array, error:*):void {

                        t.assertStrictEquals(boardsBefore, NGIO.getScoreBoards(),
                            "getScoreBoards() still returns the original local array");
                        t.assertEquals(fingerprint, describeBoards(NGIO.getScoreBoards()),
                            "local board ids and names unchanged");
                        t.assertNull(NGIO.getScoreBoard(TestConfig.READABLE_FOREIGN_SCOREBOARD_ID),
                            "the foreign board did not become locally addressable");
                        t.done();
                    });
            });

            //==================== FOREIGN OBJECT BEHAVIOUR ====================
            //
            // A stamped ScoreBoard forwards its app_id on reads and refuses
            // writes. Only the gateway can confirm the parameter actually went
            // out, so the read half is asserted here rather than offline.

            add("a stamped board reads from the app it came from", function(t:TestContext):void {
                var board:ScoreBoard = new ScoreBoard();
                board.core = core;
                board.id = TestConfig.READABLE_FOREIGN_SCOREBOARD_ID;
                board.foreignAppId = TestConfig.READABLE_FOREIGN_APP_ID;

                board.getScores({ period: "A", limit: 5 }, function(scores:Array, error:*):void {
                    // This board id belongs to the other app. Getting real scores
                    // back is proof the app_id was forwarded - without it the
                    // gateway looks the id up against THIS app and returns 203.
                    if (assertNoError(t, error, "foreign board getScores() succeeded")) {
                        t.assertNotNull(scores, "and returned a score list");
                    }
                    assertLocalCachesIntact(t);
                    t.done();
                });
            });

            add("the same board without the stamp is rejected", function(t:TestContext):void {
                // The negative control for the test above. If this ALSO passed,
                // the board id would simply be valid locally and the previous
                // test would prove nothing.
                var board:ScoreBoard = new ScoreBoard();
                board.core = core;
                board.id = TestConfig.READABLE_FOREIGN_SCOREBOARD_ID;

                board.getScores({ period: "A", limit: 5 }, function(scores:Array, error:*):void {
                    t.assertNotNull(error, "an unstamped foreign board id is refused");
                    if (error != null) {
                        t.note("gateway said: " + error);
                    }
                    t.done();
                });
            });

            add("a cross-app read accepts the social filter", function(t:TestContext):void {
                // 'social' is site-wide, not per-app: the friends list is a
                // relation between users, so "me and my friends" means the same
                // thing on another app's board. A social leaderboard shared
                // across a series of games is the main reason to want this.
                if (skipUnlessSignedIn(t)) {
                    return;
                }

                NGIO.loadExternalScores(
                    TestConfig.READABLE_FOREIGN_APP_ID,
                    TestConfig.READABLE_FOREIGN_SCOREBOARD_ID,
                    { period: "A", limit: 10, social: true },
                    function(scores:Array, error:*):void {

                        // An empty list is a legitimate pass - the user and their
                        // friends may simply not have played that game. What is
                        // being asserted is that the gateway ACCEPTS the filter on
                        // a cross-app read, not that anyone scored.
                        if (assertNoError(t, error, "social cross-app read succeeded")) {
                            if (t.assertNotNull(scores, "scores returned")) {
                                t.note("social read of board " + TestConfig.READABLE_FOREIGN_SCOREBOARD_ID +
                                       " on app " + TestConfig.READABLE_FOREIGN_APP_ID +
                                       " returned " + scores.length + " score(s)");
                            }
                        }
                        assertLocalCachesIntact(t);
                        t.done();
                    });
            });

            add("a stamped board accepts the social filter too", function(t:TestContext):void {
                // Same thing through the model rather than the NGIO helper -
                // ScoreBoard.getScores must not gate 'social' on isForeign().
                if (skipUnlessSignedIn(t)) {
                    return;
                }

                var board:ScoreBoard = new ScoreBoard();
                board.core = core;
                board.id = TestConfig.READABLE_FOREIGN_SCOREBOARD_ID;
                board.foreignAppId = TestConfig.READABLE_FOREIGN_APP_ID;

                board.getScores({ period: "A", limit: 10, social: true }, function(scores:Array, error:*):void {
                    if (assertNoError(t, error, "foreign board social read succeeded")) {
                        t.assertNotNull(scores, "scores returned");
                    }
                    t.done();
                });
            });

            add("a foreign medal from the gateway refuses to unlock", function(t:TestContext):void {
                // The offline suite proves the guard on a hand-stamped model.
                // This proves the stamp is really applied end to end, so the
                // guard fires on an object the gateway actually produced.
                NGIO.loadExternalMedals(TestConfig.READABLE_FOREIGN_APP_ID,
                    function(medals:Array, error:*):void {

                        if (!assertNoError(t, error, "foreign medals loaded")) {
                            t.done();
                            return;
                        }

                        if (medals == null || medals.length == 0) {
                            t.skip("that app returned no medals to test against");
                            return;
                        }

                        var medal:Medal = medals[0] as Medal;
                        t.assertTrue(medal.isForeign(), "the returned medal knows it is foreign");

                        var thrown:Error = t.assertThrows(function():void {
                            medal.unlock();
                        }, "and refuses to unlock");

                        if (thrown != null) {
                            t.note(thrown.message);
                        }
                        t.done();
                    });
            });

            //==================== CLOUD SAVES ====================

            add("loads save slots from an app that granted access", function(t:TestContext):void {
                if (skipUnlessSignedIn(t)) {
                    return;
                }

                NGIO.loadExternalSaveSlots(TestConfig.READABLE_FOREIGN_APP_ID,
                    function(slots:Array, error:*):void {

                        if (!assertNoError(t, error, "loadExternalSaveSlots succeeded")) {
                            t.done();
                            return;
                        }

                        if (t.assertNotNull(slots, "foreign slot list returned")) {
                            for each (var slot:SaveSlot in slots) {
                                t.assertIsType(slot, SaveSlot, "entry is a typed SaveSlot");
                                t.assertEquals(TestConfig.READABLE_FOREIGN_APP_ID, slot.foreignAppId,
                                    "slot " + slot.id + " is stamped with its source app");
                            }
                            t.note("app " + TestConfig.READABLE_FOREIGN_APP_ID + " returned " +
                                   slots.length + " save slot(s)");
                        }

                        assertLocalCachesIntact(t);
                        t.done();
                    });
            });

            add("foreign save slots never enter the local cache", function(t:TestContext):void {
                if (skipUnlessSignedIn(t)) {
                    return;
                }
                if (localSaveSlots == null) {
                    t.skip("local save slots were not loaded, nothing to protect");
                    return;
                }

                var slotsBefore:String = describeSlots(localSaveSlots);

                NGIO.loadExternalSaveSlots(TestConfig.READABLE_FOREIGN_APP_ID,
                    function(slots:Array, error:*):void {

                        t.assertStrictEquals(localSaveSlots, NGIO.getSaveSlots(),
                            "getSaveSlots() still returns the original local array");
                        t.assertEquals(slotsBefore, describeSlots(NGIO.getSaveSlots()),
                            "local slot ids, sizes and urls all unchanged");

                        for each (var slot:SaveSlot in localSaveSlots) {
                            t.assertNull(slot.foreignAppId,
                                "local slot " + slot.id + " was not stamped as foreign");
                        }
                        t.done();
                    });
            });

            add("loads a single save slot from another app", function(t:TestContext):void {
                if (skipUnlessSignedIn(t)) {
                    return;
                }

                NGIO.loadExternalSaveSlot(TestConfig.READABLE_FOREIGN_APP_ID, 1,
                    function(slot:SaveSlot, error:*):void {

                        if (!assertNoError(t, error, "loadExternalSaveSlot succeeded")) {
                            t.done();
                            return;
                        }

                        if (t.assertNotNull(slot, "a slot was returned")) {
                            t.assertIsType(slot, SaveSlot, "it is a typed SaveSlot");
                            t.assertEquals(1, slot.id, "and it is the slot we asked for");
                            t.assertEquals(TestConfig.READABLE_FOREIGN_APP_ID, slot.foreignAppId,
                                "stamped with its source app");
                        }

                        assertLocalCachesIntact(t);
                        t.done();
                    });
            });

            //==================== REFUSAL ====================

            add("refuses an app that has not granted access", function(t:TestContext):void {
                NGIO.loadExternalMedals(TestConfig.UNREADABLE_FOREIGN_APP_ID,
                    function(medals:Array, error:*):void {

                        var refused:Boolean = (error != null) || (medals == null);

                        if (error != null) {
                            t.note("refused: " + describeError(error));
                        } else if (medals == null) {
                            t.note("no error, but no medals returned either");
                        } else {
                            t.note("WARNING: app " + TestConfig.UNREADABLE_FOREIGN_APP_ID +
                                   " returned " + medals.length + " medal(s) to an app it has not authorised");
                        }

                        t.assertTrue(refused, "unauthorised cross-app read is refused");
                        assertLocalCachesIntact(t);
                        t.done();
                    });
            });

            //==================== NON-INTERFERENCE ====================

            add("local calls still cache normally afterwards", function(t:TestContext):void {
                // Guards against over-correcting: the AppState guard keys off "is
                // this a different app", not "does the result mention an app_id at
                // all". If it were the latter, ordinary loads would stop caching.
                NGIO.loadMedals(function(medals:Array, error:*):void {
                    if (!assertNoError(t, error, "local medal reload succeeded")) {
                        t.done();
                        return;
                    }

                    t.assertNotNull(NGIO.getMedals(), "local medals still cached");
                    t.assertTrue(core.appState.hasLoaded("medals"), "still marked loaded");
                    if (localMedalCount >= 0) {
                        t.assertEquals(localMedalCount, NGIO.getMedals().length,
                            "and the count is the local app's, not the foreign one's");
                    }
                    t.done();
                });
            });
        }

        //==================== HELPERS ====================

        /**
         * Assert the local caches still look exactly as they did at setUp.
         */
        private function assertLocalCachesIntact(t:TestContext):void {
            if (localMedals != null) {
                t.assertStrictEquals(localMedals, NGIO.getMedals(), "local medal array untouched");
                t.assertEquals(localMedalCount, NGIO.getMedals().length, "local medal count untouched");
            }
            if (localSaveSlots != null) {
                t.assertStrictEquals(localSaveSlots, NGIO.getSaveSlots(), "local save slot array untouched");
                t.assertEquals(localSlotCount, NGIO.getSaveSlots().length, "local slot count untouched");
            }
        }

        /**
         * A stable fingerprint of a medal list, so an in-place merge is detected
         * even when the array identity and length survive.
         */
        private function describeMedals(medals:Array):String {
            var parts:Array = [];
            for each (var medal:Medal in medals) {
                parts.push(medal.id + ":" + medal.name + ":" + medal.value);
            }
            return parts.join("|");
        }

        private function describeSlots(slots:Array):String {
            var parts:Array = [];
            for each (var slot:SaveSlot in slots) {
                parts.push(slot.id + ":" + slot.size + ":" + slot.url);
            }
            return parts.join("|");
        }

        private function describeBoards(boards:Array):String {
            var parts:Array = [];
            for each (var board:ScoreBoard in boards) {
                parts.push(board.id + ":" + board.name);
            }
            return parts.join("|");
        }
    }
}
