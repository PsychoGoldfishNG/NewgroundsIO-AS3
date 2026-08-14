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

    import io.newgrounds.models.objects.Response;
    import io.newgrounds.models.objects.Score;
    import io.newgrounds.models.objects.ScoreBoard;
    import io.newgrounds.models.objects.User;
    import io.newgrounds.models.results.ScoreBoard.getScoresResult;

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

            //==================== SERVER-SIDE CLAMPING ====================
            //
            // These go through core.callComponent rather than ScoreBoard.getScores,
            // deliberately. The model THROWS on a limit outside 1-100 before
            // anything is sent, so the server's own clamping is unreachable from
            // the normal API - which means the behaviour the library's validation
            // is designed around has never actually been checked.
            //
            // No need to seed a board with 100+ scores: the result echoes the
            // EFFECTIVE limit and skip back, so the clamp is observable from the
            // echo alone on a board holding two rows.

            add("server clamps an oversized limit to 100", function(t:TestContext):void {
                var board:ScoreBoard = firstBoard();
                if (board == null) {
                    t.skip("no scoreboards loaded");
                    return;
                }

                requestScores(t, board.id, { period: "A", limit: 500 }, function(result:getScoresResult):void {
                    // If this ever comes back as 500, the library is throwing on
                    // values the server would have accepted, and the 1-100 rule
                    // in the guide is wrong.
                    t.assertEquals(100, result.limit, "limit 500 clamped to 100");
                    if (result.scores != null) {
                        t.assertTrue(result.scores.length <= 100, "and no more than 100 rows came back");
                    }
                    t.note("sent limit 500, server used " + result.limit);
                    t.done();
                });
            });

            add("server clamps a zero limit up to 1", function(t:TestContext):void {
                // The floor matters as much as the ceiling: a caller who means
                // "none" silently gets one score. That is why the library rejects
                // 0 rather than passing it through.
                var board:ScoreBoard = firstBoard();
                if (board == null) {
                    t.skip("no scoreboards loaded");
                    return;
                }

                requestScores(t, board.id, { period: "A", limit: 0 }, function(result:getScoresResult):void {
                    t.assertEquals(1, result.limit, "limit 0 clamped up to 1");
                    t.note("sent limit 0, server used " + result.limit);
                    t.done();
                });
            });

            add("server does not bound skip", function(t:TestContext):void {
                // Paging depth is not capped - the 1-100 rule is about page SIZE
                // only. If skip comes back altered, the guide is wrong to tell
                // ports to pass it through untouched.
                var board:ScoreBoard = firstBoard();
                if (board == null) {
                    t.skip("no scoreboards loaded");
                    return;
                }

                requestScores(t, board.id, { period: "A", limit: 10, skip: 500 }, function(result:getScoresResult):void {
                    t.assertEquals(500, result.skip, "skip 500 passed through unchanged");
                    t.note("sent skip 500, server used " + result.skip);
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

        /**
         * Calls ScoreBoard.getScores through Core, skipping the model's own
         * argument validation.
         *
         * ScoreBoard.getScores() throws on a limit outside 1-100, which is
         * correct for game code but makes the server's clamping impossible to
         * observe. Going through callComponent sends exactly what we ask, so the
         * server can answer for itself.
         *
         * Fails the test and finishes it on any error, so callers only handle
         * the success case.
         */
        private function requestScores(t:TestContext, boardId:Number, params:Object, onResult:Function):void {
            params.id = boardId;

            core.callComponent("ScoreBoard.getScores", params, function(response:Response, callbackParams:*):void {

                if (response == null || response.success !== true) {
                    assertNoError(t, (response != null) ? response.error : null, "raw getScores request succeeded");
                    t.done();
                    return;
                }

                var result:getScoresResult = response.getResult() as getScoresResult;

                if (result == null) {
                    t.fail("response did not carry a getScores result");
                    t.done();
                    return;
                }

                if (result.success !== true) {
                    assertNoError(t, result.error, "getScores component succeeded");
                    t.done();
                    return;
                }

                onResult(result);
            }, null);
        }
    }
}
