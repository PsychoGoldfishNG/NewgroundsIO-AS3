/**
 * LiveNoSessionSuite
 *
 * Everything the gateway will do for a client that has NO session at all.
 *
 * WHY IT IS WORTH HAVING. Sixteen of the twenty-five components never touch a
 * session, and games use them that way - a medal list or a high score table
 * shown on a title screen, before anyone has signed in. Nothing else in the
 * suite proves those calls work with no session_id in the envelope, because
 * every other live suite runs after the session exists.
 *
 * THIS SUITE MAKES ITS OWN WINDOW, so it runs on every machine in every login
 * state. setUp() parks whatever session AppState restored during construction
 * and tearDown() puts it back.
 *
 * That is honest rather than a shortcut: the request envelope is built from
 * appState.session.id (Core.sendRequest), so clearing it locally reproduces
 * exactly the wire condition being tested - a request with no session_id. No
 * session is ended, nothing is sent, and the tester's login is untouched.
 *
 * It used to rely on finding a naturally session-free window between init() and
 * the first checkSession(). That window does not exist for either common case -
 * a developer with a remembered login, or a game embedded on Newgrounds where
 * the page URL supplies ngio_session_id - so on exactly the machines people test
 * on the whole suite reported permanent skips, and the only way to run it was to
 * clear stored session state and start again.
 *
 * MUST RUN BEFORE anything loads medals while signed in. Its unlock test asserts
 * the medal is not flagged unlocked, which only holds while the cache reflects a
 * sessionless read.
 */
package ngiotest.suites {

    import io.newgrounds.models.objects.Medal;
    import io.newgrounds.models.objects.ScoreBoard;

    import ngiotest.LiveSuite;
    import ngiotest.TestConfig;
    import ngiotest.TestContext;

    public class LiveNoSessionSuite extends LiveSuite {

        override public function get suiteName():String {
            return "Live / No session";
        }

        override public function setUp(done:Function):void {
            var self:LiveNoSessionSuite = this;

            // super.setUp performs the one-time NGIO.init(), so the session only
            // exists to be parked after it has run.
            super.setUp(function():void {
                self.stashSession();
                done.call(null);
            });
        }

        override public function tearDown(done:Function):void {
            restoreSession();
            super.tearDown(done);
        }

        override public function build():void {

            var self:LiveNoSessionSuite = this;

            add("holds no session at all", function(t:TestContext):void {
                // The precondition for everything below. After setUp this is
                // true on every machine, whether or not one was restored.
                t.assertFalse(NGIO.hasSession(), "no session is held");
                t.assertFalse(NGIO.hasUser(), "and no user");
                t.assertNull(core.sessionId, "no session id on Core");

                t.note(self.hasStashedSession
                     ? "a restored session was parked for the duration of this suite, and is put " +
                       "back in tearDown - nothing was ended server-side"
                     : "nothing had opened a session yet, so this window was already open");
                t.done();
            });

            add("loads medals and scoreboards without a session", function(t:TestContext):void {
                if (self.skipUnlessSessionFree(t)) {
                    return;
                }

                // One batched request for both, to keep the cost of this suite
                // down.
                //
                // "scoreBoards", capital B - AppState.dataProperties spells it
                // that way, matching NGIO.getScoreBoards(). loadData throws on
                // an unknown name rather than ignoring it.
                NGIO.loadAppData(["medals", "scoreBoards"], function(error:*):void {
                    if (!self.assertNoError(t, error, "loadAppData succeeded with no session")) {
                        t.done();
                        return;
                    }

                    var medals:Array = NGIO.getMedals();
                    var boards:Array = NGIO.getScoreBoards();

                    if (t.assertNotNull(medals, "medals came back")) {
                        t.assertEquals(TestConfig.EXPECTED_MEDAL_COUNT, medals.length,
                            "all medals are visible to a client with no session");
                    }
                    if (t.assertNotNull(boards, "scoreboards came back")) {
                        t.assertEquals(TestConfig.EXPECTED_SCOREBOARD_COUNT, boards.length,
                            "all scoreboards are visible too");
                    }

                    t.assertFalse(NGIO.hasSession(), "and reading them did not open a session");
                    t.done();
                });
            });

            add("reads scores without a session", function(t:TestContext):void {
                if (self.skipUnlessSessionFree(t)) {
                    return;
                }

                var boards:Array = NGIO.getScoreBoards();
                if (boards == null || boards.length == 0) {
                    t.skip("no scoreboards loaded");
                    return;
                }

                var board:ScoreBoard = boards[0] as ScoreBoard;
                board.getScores({ period: "A", limit: 3 }, function(scores:Array, error:*):void {
                    if (!self.assertNoError(t, error, "getScores succeeded with no session")) {
                        t.done();
                        return;
                    }

                    // An empty board is a valid answer - this is about whether
                    // the call is permitted, not about what is on the board.
                    t.assertNotNull(scores, "a score list came back");
                    t.note("board '" + board.name + "' returned " + scores.length + " score(s) to a sessionless client");
                    t.assertFalse(NGIO.hasSession(), "still no session");
                    t.done();
                });
            });

            add("resolves a loader url without a session", function(t:TestContext):void {
                if (self.skipUnlessSessionFree(t)) {
                    return;
                }

                NGIO.loadOfficialUrl(false, function(url:String, error:*):void {
                    if (self.assertNoError(t, error, "loadOfficialUrl succeeded with no session")) {
                        if (t.assertNotNull(url, "a url came back")) {
                            t.assertTrue(url.indexOf("http") == 0, "and it is absolute");
                            t.note("official url with no session: " + url);
                        }
                    }
                    t.done();
                });
            });

            //==================== THE SESSION-GATED HALF ====================

            add("an unlock with no session is refused BEFORE it is sent", function(t:TestContext):void {
                if (self.skipUnlessSessionFree(t)) {
                    return;
                }

                var medals:Array = NGIO.getMedals();
                if (medals == null || medals.length == 0) {
                    t.skip("no medals loaded");
                    return;
                }

                // THIS TEST CHANGED SIDES, and the history is worth keeping.
                //
                // It used to be named "and by the SERVER", because
                // BaseComponent.hasValidProperties() checked requiresSession and
                // NOTHING IN build/ EVER CALLED IT - so the request went out,
                // over the network, to be refused by the gateway.
                //
                // Core now consults it (as getPreflightError()) before sending,
                // so with no session id this never leaves the machine. The
                // ASSERTIONS below are unchanged and still pass, because the
                // local refusal is deliberately shaped like the server's and
                // carries the same code. That is the contract being pinned here:
                // the caller cannot tell the difference.
                //
                // Note the request count for a full run drops accordingly. If
                // this test ever starts costing a request again, something has
                // stopped consulting the preflight check.
                var medal:Medal = medals[0] as Medal;
                medal.unlock(function(unlockedMedal:Medal, error:*):void {
                    if (t.assertNotNull(error, "the unlock was refused")) {
                        t.note("refused with: " + self.describeError(error));
                    }
                    t.assertFalse(unlockedMedal.unlocked, "and the medal is not flagged unlocked");
                    t.assertFalse(NGIO.hasSession(), "a refused call did not open a session either");
                    t.done();
                });
            });

            add("cloud saves are refused with no session", function(t:TestContext):void {
                if (self.skipUnlessSessionFree(t)) {
                    return;
                }

                // Same shape as the unlock above: refused before sending.
                //
                // THE CODE IS THE POINT, and it is why the local refusal can
                // stand in for the server's here. With no session the gateway
                // answers 102, "Missing required parameter" - there is no
                // session_id in the envelope to check, which is a judgement the
                // client can make for itself. With a guest session it answers
                // 110, "User is not logged in" - the id is there and belongs to
                // nobody, which is a judgement only the SERVER can make. Same
                // call, same component, two genuinely different refusals, and
                // only one of them is knowable locally.
                //
                // That asymmetry is exactly why the preflight check stops at the
                // session id: see BaseComponent.getPreflightError().
                //
                // That is the empirical case for LiveNoSessionSuite and
                // LiveGuestSuite being separate suites rather than one: they are
                // not the same test run twice. LiveGuestSuite asserts the
                // matching 110.
                NGIO.loadSaveSlots(function(slots:Array, error:*):void {
                    if (t.assertNotNull(error, "loading save slots was refused")) {
                        t.assertEquals(102, error.code,
                            "refused for a MISSING session, not for being logged out");
                        t.assertNotEquals(110, error.code,
                            "and specifically not the guest-session code");
                        t.note("server said: " + self.describeError(error));
                    }
                    t.done();
                });
            });
        }

        //==================== HELPERS ====================

        /**
         * Safety net: nothing in this suite opens a session, and setUp
         * guarantees there is none, so this should never fire. It stays because
         * a pass recorded against the wrong state is worse than a skip - if some
         * future change starts a session mid-suite, this says so rather than
         * quietly reporting green.
         */
        public function skipUnlessSessionFree(t:TestContext):Boolean {
            if (NGIO.hasSession()) {
                t.skip("a session appeared during this suite, so this is no longer a no-session test");
                return true;
            }
            return false;
        }
    }
}
