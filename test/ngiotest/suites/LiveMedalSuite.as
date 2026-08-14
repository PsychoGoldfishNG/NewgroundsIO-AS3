/**
 * LiveMedalSuite
 *
 * Exercises the secure (encrypted) Medal.unlock path end to end.
 *
 * With TestConfig.USE_DEBUG_MODE on - the default - the gateway validates and
 * answers normally without committing the unlock, so this suite is repeatable
 * and nothing has to be re-locked between runs. Switch debug mode off only when
 * deliberately verifying persistence, and expect to re-lock afterwards.
 */
package ngiotest.suites {

    import io.newgrounds.Errors;
    import io.newgrounds.models.objects.Medal;

    import ngiotest.LiveSuite;
    import ngiotest.TestConfig;
    import ngiotest.TestContext;

    public class LiveMedalSuite extends LiveSuite {

        override public function get suiteName():String {
            return "Live / Medals";
        }

        override public function build():void {

            add("unlocks a medal", function(t:TestContext):void {
                if (skipUnlessSignedIn(t)) {
                    return;
                }

                var medal:Medal = pickMedal();
                if (medal == null) {
                    t.skip("no medals available to unlock");
                    return;
                }

                var scoreBefore:Number = NGIO.getMedalScore();
                t.note("unlocking " + medal.toString() + " (was unlocked=" + medal.unlocked + ")");
                t.status("Unlocking " + medal.name + "...");

                medal.unlock(function(unlockedMedal:Medal, error:*):void {
                    if (!assertNoError(t, error, "unlock accepted by the server")) {
                        t.done();
                        return;
                    }

                    t.assertStrictEquals(medal, unlockedMedal, "callback receives the same Medal instance");
                    t.assertTrue(unlockedMedal.unlocked, "medal is flagged unlocked");
                    t.note("medal score now " + NGIO.getMedalScore() + " (was " + scoreBefore + ")");
                    t.done();
                });
            });

            add("unlocking again is not an error", function(t:TestContext):void {
                // Games unlock medals opportunistically and will re-send an
                // unlock the player already has. That has to be a no-op, not a
                // failure the game surfaces to the player.
                if (skipUnlessSignedIn(t)) {
                    return;
                }

                var medal:Medal = pickMedal();
                if (medal == null) {
                    t.skip("no medals available to unlock");
                    return;
                }

                medal.unlock(function(unlockedMedal:Medal, error:*):void {
                    if (assertNoError(t, error, "repeat unlock accepted")) {
                        t.assertTrue(unlockedMedal.unlocked, "medal remains unlocked");
                    }
                    t.done();
                });
            });

            add("rejects an unknown medal id", function(t:TestContext):void {
                // The encrypted payload still has to reach the server intact for
                // it to be able to tell us the id is wrong - so a 202 here is
                // also evidence the encryption round-tripped correctly.
                if (skipUnlessSignedIn(t)) {
                    return;
                }

                var bogus:Medal = new Medal();
                bogus.core = core;
                bogus.id = 99999999;

                bogus.unlock(function(unlockedMedal:Medal, error:*):void {
                    if (t.assertNotNull(error, "server rejected the unknown medal id")) {
                        t.assertEquals(Errors.INVALID_MEDAL_ID, error.code,
                            "reported as INVALID_MEDAL_ID (202)");
                        t.note("server said: " + describeError(error));
                    }
                    t.assertFalse(unlockedMedal.unlocked, "failed unlock did not flag the medal");
                    t.done();
                });
            });

            add("refuses a session-gated unlock when signed out", function(t:TestContext):void {
                if (isSignedIn) {
                    t.skip("a user is signed in, so this path cannot be reached");
                    return;
                }

                var medals:Array = NGIO.getMedals();
                if (medals == null || medals.length == 0) {
                    t.skip("no medals loaded");
                    return;
                }

                (medals[0] as Medal).unlock(function(medal:Medal, error:*):void {
                    t.assertNotNull(error, "guest unlock is refused");
                    t.assertFalse(medal.unlocked, "medal not flagged unlocked");
                    t.note("server said: " + describeError(error));
                    t.done();
                });
            });

            add("re-reads the medal list after unlocking", function(t:TestContext):void {
                // The list is updated in place, so cached Medal references held
                // by game code have to stay valid across a reload.
                if (skipUnlessSignedIn(t)) {
                    return;
                }

                var before:Array = NGIO.getMedals();
                if (before == null || before.length == 0) {
                    t.skip("no medals loaded");
                    return;
                }

                var firstBefore:Medal = before[0] as Medal;

                NGIO.loadMedals(function(medals:Array, error:*):void {
                    if (!assertNoError(t, error, "medal list reloaded")) {
                        t.done();
                        return;
                    }

                    if (t.assertNotNull(medals, "list returned")) {
                        t.assertEquals(before.length, medals.length, "medal count unchanged");
                        t.assertStrictEquals(firstBefore, medals[0],
                            "existing Medal instances are updated in place, not replaced");
                    }
                    t.done();
                });
            });
        }

        //==================== HELPERS ====================

        /**
         * Choose a medal to unlock, preferring one that is still locked so the
         * test exercises a state change rather than a repeat.
         */
        private function pickMedal():Medal {
            var medals:Array = NGIO.getMedals();
            if (medals == null || medals.length == 0) {
                return null;
            }

            for each (var medal:Medal in medals) {
                if (!medal.unlocked) {
                    return medal;
                }
            }

            return medals[0] as Medal;
        }
    }
}
