/**
 * LiveScoreBoardSuite
 *
 * Covers the second encrypted component (ScoreBoard.postScore) plus the
 * filtering options on ScoreBoard.getScores.
 *
 * The test app has two boards - one standard, one incremental - and the suite
 * posts to whichever comes back first. In debug mode nothing is committed.
 */
package ngiotest.suites {

    import io.newgrounds.models.objects.Score;
    import io.newgrounds.models.objects.ScoreBoard;
    import io.newgrounds.models.objects.User;

    import ngiotest.LiveSuite;
    import ngiotest.TestContext;

    public class LiveScoreBoardSuite extends LiveSuite {

        override public function get suiteName():String {
            return "Live / ScoreBoards";
        }

        override public function build():void {

            add("loads scores from a board", function(t:TestContext):void {
                var board:ScoreBoard = firstBoard();
                if (board == null) {
                    t.skip("no scoreboards loaded");
                    return;
                }

                board.getScores({ period: "A", limit: 10 }, function(scores:Array, error:*):void {
                    if (!assertNoError(t, error, "getScores returned")) {
                        t.done();
                        return;
                    }

                    if (!t.assertNotNull(scores, "scores array returned")) {
                        t.done();
                        return;
                    }

                    t.assertTrue(scores.length <= 10, "respects the requested limit");
                    t.note("board '" + board.name + "' returned " + scores.length + " all-time scores");

                    for each (var score:Score in scores) {
                        t.assertIsType(score, Score, "entry is a Score model");
                        t.assertNotNull(score.formatted_value, "score carries a formatted value");
                        // A board score always belongs to somebody; a null user
                        // here means the nested cast silently dropped it.
                        if (t.assertNotNull(score.user, "score carries a user")) {
                            t.assertIsType(score.user, User, "user is a User model");
                        }
                    }
                    t.done();
                });
            });

            add("honours the limit filter", function(t:TestContext):void {
                var board:ScoreBoard = firstBoard();
                if (board == null) {
                    t.skip("no scoreboards loaded");
                    return;
                }

                board.getScores({ period: "A", limit: 1 }, function(scores:Array, error:*):void {
                    if (assertNoError(t, error, "limited getScores returned")) {
                        if (t.assertNotNull(scores, "scores returned")) {
                            t.assertTrue(scores.length <= 1, "returned at most one score");
                        }
                    }
                    t.done();
                });
            });

            add("accepts every documented period", function(t:TestContext):void {
                // D/W/M/Y/A are the documented values. A rejected period would
                // mean the parameter is not reaching the server correctly.
                var board:ScoreBoard = firstBoard();
                if (board == null) {
                    t.skip("no scoreboards loaded");
                    return;
                }

                var periods:Array = ["D", "W", "M", "Y", "A"];
                var remaining:int = periods.length;

                for each (var period:String in periods) {
                    (function(currentPeriod:String):void {
                        board.getScores({ period: currentPeriod, limit: 1 }, function(scores:Array, error:*):void {
                            assertNoError(t, error, "period '" + currentPeriod + "' accepted");
                            remaining--;
                            if (remaining == 0) {
                                t.done();
                            }
                        });
                    })(period);
                }
            });

            add("posts a score", function(t:TestContext):void {
                if (skipUnlessSignedIn(t)) {
                    return;
                }

                var board:ScoreBoard = firstBoard();
                if (board == null) {
                    t.skip("no scoreboards loaded");
                    return;
                }

                var value:Number = 1000 + Math.floor(Math.random() * 9000);
                t.status("Posting a score of " + value + " to " + board.name + "...");

                board.postScore(value, null, function(score:Score, error:*):void {
                    if (!assertNoError(t, error, "postScore accepted")) {
                        t.done();
                        return;
                    }

                    if (t.assertNotNull(score, "server echoed the posted score")) {
                        t.assertIsType(score, Score, "is a Score model");
                        t.assertNotNull(score.formatted_value, "carries a formatted value");
                        t.note("posted " + value + ", server returned " + score.value +
                               " (" + score.formatted_value + ")");
                    }
                    t.done();
                });
            });

            add("posts a tagged score", function(t:TestContext):void {
                if (skipUnlessSignedIn(t)) {
                    return;
                }

                var board:ScoreBoard = firstBoard();
                if (board == null) {
                    t.skip("no scoreboards loaded");
                    return;
                }

                board.postScore(4242, "unit-test", function(score:Score, error:*):void {
                    if (assertNoError(t, error, "tagged postScore accepted")) {
                        if (t.assertNotNull(score, "server echoed the score")) {
                            t.assertEquals("unit-test", score.tag, "tag round-tripped");
                        }
                    }
                    t.done();
                });
            });

            add("filters scores by tag", function(t:TestContext):void {
                var board:ScoreBoard = firstBoard();
                if (board == null) {
                    t.skip("no scoreboards loaded");
                    return;
                }

                board.getScores({ period: "A", limit: 10, tag: "unit-test" }, function(scores:Array, error:*):void {
                    if (assertNoError(t, error, "tag-filtered getScores returned")) {
                        if (t.assertNotNull(scores, "scores returned")) {
                            for each (var score:Score in scores) {
                                t.assertEquals("unit-test", score.tag, "every result carries the requested tag");
                            }
                            t.note(scores.length + " score(s) tagged 'unit-test'");
                        }
                    }
                    t.done();
                });
            });

            add("filters scores by user", function(t:TestContext):void {
                if (skipUnlessSignedIn(t)) {
                    return;
                }

                var board:ScoreBoard = firstBoard();
                if (board == null) {
                    t.skip("no scoreboards loaded");
                    return;
                }

                board.getScores({ period: "A", limit: 10, user_id: user.id }, function(scores:Array, error:*):void {
                    if (assertNoError(t, error, "user-filtered getScores returned")) {
                        if (t.assertNotNull(scores, "scores returned")) {
                            for each (var score:Score in scores) {
                                if (score.user != null) {
                                    t.assertEquals(user.id, score.user.id, "every result belongs to the requested user");
                                }
                            }
                        }
                    }
                    t.done();
                });
            });

            add("rejects an unknown board id", function(t:TestContext):void {
                var bogus:ScoreBoard = new ScoreBoard();
                bogus.core = core;
                bogus.id = 99999999;

                bogus.getScores({ period: "A", limit: 1 }, function(scores:Array, error:*):void {
                    t.assertNotNull(error, "server rejected the unknown board id");
                    if (error != null) {
                        t.note("server said: " + describeError(error));
                    }
                    t.done();
                });
            });
        }

        //==================== HELPERS ====================

        private function firstBoard():ScoreBoard {
            var boards:Array = NGIO.getScoreBoards();
            if (boards == null || boards.length == 0) {
                return null;
            }
            return boards[0] as ScoreBoard;
        }
    }
}
