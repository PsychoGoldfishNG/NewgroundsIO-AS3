/**
 * OfflineModelSuite
 *
 * Behaviour hand-written onto individual models: string formatting, session
 * clearing, and the argument validation ScoreBoard.getScores does before it
 * ever touches the network.
 */
package ngiotest.suites {

    import io.newgrounds.AppState;
    import io.newgrounds.Core;
    import io.newgrounds.Errors;
    import io.newgrounds.SessionStatus;
    import io.newgrounds.models.objects.Medal;
    import io.newgrounds.models.objects.NgioError;
    import io.newgrounds.models.objects.SaveSlot;
    import io.newgrounds.models.objects.Score;
    import io.newgrounds.models.objects.ScoreBoard;
    import io.newgrounds.models.objects.Session;
    import io.newgrounds.models.objects.User;

    import ngiotest.TestConfig;
    import ngiotest.TestContext;
    import ngiotest.TestSuite;

    public class OfflineModelSuite extends TestSuite {

        override public function get suiteName():String {
            return "Offline / Models";
        }

        override public function build():void {

            //==================== toString ====================

            add("models describe themselves usefully", function(t:TestContext):void {
                var medal:Medal = new Medal();
                medal.id = 12;
                medal.name = "Winner";
                t.assertEquals("Medal #12 - Winner", medal.toString(), "populated medal");
                t.assertEquals("Medal #0 - null", new Medal().toString(), "empty medal");

                var user:User = new User();
                user.name = "Tester";
                t.assertEquals("Tester", user.toString(), "populated user");
                t.assertEquals("null", new User().toString(), "empty user");

                var score:Score = new Score();
                score.value = 500;
                t.assertEquals("Score Value: 500", score.toString(), "populated score");

                var error:NgioError = new NgioError();
                error.message = "Something broke";
                t.assertEquals("Something broke", error.toString(), "populated error");
                t.assertEquals("null", new NgioError().toString(), "empty error");
                t.done();
            });

            //==================== SESSION ====================

            add("Session.clearSessionData() resets every field", function(t:TestContext):void {
                var session:Session = new Session();
                session.id = "sess-1";
                session.user = new User();
                session.passport_url = "https://example.com/passport";
                session.expired = true;
                session.remember = true;
                session.verified = true;
                session.preauthenticatedId = "sess-1";

                session.clearSessionData();

                t.assertNull(session.id, "id cleared");
                t.assertNull(session.user, "user cleared");
                t.assertNull(session.passport_url, "passport url cleared");
                t.assertFalse(session.expired, "expired reset");
                t.assertFalse(session.remember, "remember reset");
                t.assertFalse(session.verified, "verified reset");
                t.assertEquals("", session.preauthenticatedId, "preauthenticated id cleared");
                t.done();
            });

            add("Session.isPreauthenticated() only matches the same id", function(t:TestContext):void {
                var session:Session = new Session();
                t.assertFalse(session.isPreauthenticated(), "empty session is not preauthenticated");

                session.preauthenticatedId = "from-url";
                session.id = "different";
                t.assertFalse(session.isPreauthenticated(), "different id is not preauthenticated");

                session.id = "from-url";
                t.assertTrue(session.isPreauthenticated(), "matching id is preauthenticated");
                t.done();
            });

            add("Medal.clearSessionData() only clears the unlocked flag", function(t:TestContext):void {
                // Medal metadata is app-scoped and survives logout; only the
                // per-user unlock state is session-scoped.
                var medal:Medal = new Medal();
                medal.id = 5;
                medal.name = "Keep me";
                medal.value = 25;
                medal.unlocked = true;

                medal.clearSessionData();

                t.assertFalse(medal.unlocked, "unlocked reset");
                t.assertEquals(5, medal.id, "id retained");
                t.assertEquals("Keep me", medal.name, "name retained");
                t.assertEquals(25, medal.value, "value retained");
                t.done();
            });

            //==================== SAVESLOT ====================

            add("SaveSlot.hasData() keys off the url", function(t:TestContext):void {
                var slot:SaveSlot = new SaveSlot();
                t.assertFalse(slot.hasData(), "fresh slot has no data");

                slot.url = "//example.com/save";
                t.assertTrue(slot.hasData(), "slot with a url has data");

                slot.url = null;
                t.assertFalse(slot.hasData(), "cleared slot has no data");
                t.done();
            });

            add("SaveSlot.loadDataRaw() short-circuits on an empty slot", function(t:TestContext):void {
                // Must call back rather than hang, and must not attempt a request.
                var slot:SaveSlot = new SaveSlot();
                slot.id = 1;

                slot.loadDataRaw(function(data:String, error:*):void {
                    t.assertNull(data, "no data returned");
                    t.assertNull(error, "and it is not treated as an error");
                    t.done();
                });
            });

            //==================== SCOREBOARD ARGUMENT VALIDATION ====================

            add("ScoreBoard.getScores() rejects an out-of-range limit", function(t:TestContext):void {
                var board:ScoreBoard = new ScoreBoard();
                board.id = 1;

                t.assertThrows(function():void {
                    board.getScores({ limit: 0 });
                }, "limit 0 should throw");

                t.assertThrows(function():void {
                    board.getScores({ limit: 101 });
                }, "limit 101 should throw");

                t.assertThrows(function():void {
                    board.getScores({ limit: -5 });
                }, "negative limit should throw");
                t.done();
            });

            add("ScoreBoard.getScores() rejects mistyped user filters", function(t:TestContext):void {
                var board:ScoreBoard = new ScoreBoard();
                board.id = 1;

                t.assertThrows(function():void {
                    board.getScores({ user_id: "not-a-number" });
                }, "string user_id should throw");

                t.assertThrows(function():void {
                    board.getScores({ user_name: 12345 });
                }, "numeric user_name should throw");

                t.assertThrows(function():void {
                    board.getScores({ user: "not-a-user" });
                }, "string user should throw");
                t.done();
            });

            add("ScoreBoard.getScores() accepts the documented limits", function(t:TestContext):void {
                // core is null, so these stop after validation without any request.
                var board:ScoreBoard = new ScoreBoard();
                board.id = 1;

                try {
                    board.getScores({ limit: 1 });
                    board.getScores({ limit: 100 });
                    board.getScores({ period: "A", skip: 20 });
                    board.getScores({ user_id: 42 });
                    board.getScores({ user_name: "Tester" });
                    board.getScores();
                    t.assert(true, "valid filters accepted");
                } catch (e:Error) {
                    t.fail("valid filters should not throw, got: " + e.message);
                }
                t.done();
            });

            //==================== ERRORS ====================

            add("Errors maps codes to messages", function(t:TestContext):void {
                t.assertEquals("Your session has expired.", Errors.getDefaultMessage(Errors.EXPIRED_SESSION), "104");
                t.assertEquals("You must be logged in to do that.", Errors.getDefaultMessage(Errors.LOGIN_REQUIRED), "110");
                t.assertEquals("An unknown error has occurred.", Errors.getDefaultMessage(Errors.UNKNOWN), "0");
                t.assertEquals("An unknown error has occurred.", Errors.getDefaultMessage(99999), "unmapped code falls back");
                t.done();
            });

            add("Errors.getError() builds an NgioError", function(t:TestContext):void {
                var fallback:* = Errors.getError();
                t.assertIsType(fallback, NgioError, "default is an NgioError");
                t.assertEquals(0, fallback.code, "default code is UNKNOWN");
                t.assertEquals("An unknown error has occurred.", fallback.message, "default message");

                var coded:* = Errors.getError(Errors.INVALID_MEDAL_ID);
                t.assertEquals(202, coded.code, "code retained");
                t.assertEquals(Errors.getDefaultMessage(202), coded.message, "default message for the code");

                var custom:* = Errors.getError(Errors.INVALID_MEDAL_ID, "Medal 5 is not ours");
                t.assertEquals("Medal 5 is not ours", custom.message, "custom message replaces the default");

                var appended:* = Errors.getError(Errors.INVALID_MEDAL_ID, "Medal 5 is not ours", true);
                t.assertEquals(Errors.getDefaultMessage(202) + " Medal 5 is not ours", appended.message,
                    "appended message follows the default");

                var emptyCustom:* = Errors.getError(Errors.INVALID_MEDAL_ID, "", true);
                t.assertEquals(Errors.getDefaultMessage(202), emptyCustom.message,
                    "an empty custom message does not produce a trailing space");
                t.done();
            });

            //==================== APPSTATE ====================

            add("AppState guards its property names", function(t:TestContext):void {
                var state:AppState = freshAppState();

                t.assertThrows(function():void {
                    state.hasLoaded("nonsense");
                }, "hasLoaded rejects an unknown name");

                t.assertThrows(function():void {
                    state.markLoaded("nonsense");
                }, "markLoaded rejects an unknown name");

                t.assertThrows(function():void {
                    state.loadData(["meddles"]);
                }, "loadData rejects a misspelled name");

                t.assertThrows(function():void {
                    state.loadData([]);
                }, "loadData rejects an empty list");
                t.done();
            });

            add("AppState tracks what has been loaded", function(t:TestContext):void {
                var state:AppState = freshAppState();

                for each (var name:String in AppState.dataProperties) {
                    t.assertFalse(state.hasLoaded(name), name + " starts unloaded");
                }

                state.markLoaded("medals");
                t.assertTrue(state.hasLoaded("medals"), "medals marked as loaded");
                t.assertFalse(state.hasLoaded("scoreBoards"), "other properties unaffected");

                // Marking twice must not corrupt the list
                state.markLoaded("medals");
                t.assertTrue(state.hasLoaded("medals"), "still loaded after a duplicate mark");
                t.done();
            });

            add("AppState exposes the documented data properties", function(t:TestContext):void {
                var expected:Array = ["gatewayVersion", "currentVersion", "hostApproved",
                                      "saveSlots", "scoreBoards", "medals", "medalScore"];

                t.assertEquals(expected.length, AppState.dataProperties.length, "property count");
                for each (var name:String in expected) {
                    t.assertTrue(AppState.dataProperties.indexOf(name) >= 0, name + " is a data property");
                }
                t.done();
            });

            add("AppState derives session status from session state", function(t:TestContext):void {
                var state:AppState = freshAppState();

                state.session.id = null;
                t.assertEquals(SessionStatus.UNINITIALIZED, state.getSessionStatus().status, "no session id");

                state.session.id = "sess-1";
                t.assertEquals(SessionStatus.UNVERIFIED, state.getSessionStatus().status, "id but no passport url");

                state.session.passport_url = "https://example.com/passport";
                t.assertEquals(SessionStatus.NOT_LOGGED_IN, state.getSessionStatus().status, "guest session");

                state.passportIsOpen = true;
                t.assertEquals(SessionStatus.WAITING_FOR_PASSPORT, state.getSessionStatus().status, "passport open");

                state.session.user = new User();
                var loggedIn:SessionStatus = state.getSessionStatus();
                t.assertEquals(SessionStatus.LOGGED_IN, loggedIn.status, "user attached");
                t.assertNotNull(loggedIn.user, "status carries the user");
                t.done();
            });

            add("AppState reports an expired session as EXPIRED", function(t:TestContext):void {
                var state:AppState = freshAppState();
                state.session.id = "sess-1";
                state.session.expired = true;

                t.assertEquals(SessionStatus.EXPIRED, state.getSessionStatus().status, "expired flag");
                t.done();
            });

            add("AppState maps session error codes to statuses", function(t:TestContext):void {
                var expired:AppState = freshAppState();
                expired.session.id = "sess-1";
                expired.session.error = Errors.getError(Errors.EXPIRED_SESSION);
                t.assertEquals(SessionStatus.EXPIRED, expired.getSessionStatus().status, "104 maps to EXPIRED");

                var cancelled:AppState = freshAppState();
                cancelled.session.id = "sess-1";
                cancelled.session.error = Errors.getError(Errors.CANCELLED_SESSION);
                t.assertEquals(SessionStatus.LOGIN_CANCELLED, cancelled.getSessionStatus().status, "111 maps to LOGIN_CANCELLED");

                var other:AppState = freshAppState();
                other.session.id = "sess-1";
                other.session.error = Errors.getError(Errors.SERVER_ERROR);
                var status:SessionStatus = other.getSessionStatus();
                t.assertEquals(SessionStatus.ERROR, status.status, "500 maps to ERROR");
                t.assertNotNull(status.error, "and carries the error through");
                t.done();
            });

            add("AppState reports a URL-supplied session id", function(t:TestContext):void {
                var state:AppState = freshAppState();
                state.session.id = "from-url";
                state.session.preauthenticatedId = "from-url";

                t.assertEquals(SessionStatus.SESSION_ID_PROVIDED, state.getSessionStatus().status,
                    "preauthenticated id is reported distinctly");
                t.done();
            });
        }

        //==================== HELPERS ====================

        /**
         * An AppState with a known-empty session.
         *
         * The AppState constructor restores any session id previously saved to
         * local storage, so a run that had logged in would otherwise leak state
         * into these offline assertions. Clearing the session here makes the
         * suite independent of run order and of whatever is on disk.
         */
        private function freshAppState():AppState {
            var core:Core = new Core("unit-test:appstate", TestConfig.ENCRYPTION_KEY);
            var state:AppState = core.appState;

            state.session = new Session();
            state.session.id = null;
            state.passportIsOpen = false;
            state.medals = null;
            state.scoreBoards = null;
            state.saveSlots = null;

            return state;
        }
    }
}
