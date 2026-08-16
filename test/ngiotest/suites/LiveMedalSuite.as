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

            add("unlocking one medal does not unlock another", function(t:TestContext):void {
                // Needs two medals to mean anything: with only one there is no
                // second, still-locked medal to check, so "the unlock landed on
                // the right medal" and "the unlock did nothing at all" produce
                // identical observations.
                //
                // The app has three now, so this runs. The guard stays because
                // the medal count is server-side configuration that can change
                // without anyone touching this repo, and a suite that quietly
                // stops proving something is worse than one that says so.
                if (TestConfig.EXPECTED_MEDAL_COUNT < 2) {
                    t.skip("the test app has only " + TestConfig.EXPECTED_MEDAL_COUNT +
                           " medal - two or more are needed to tell a targeted unlock from a no-op");
                    return;
                }

                if (skipUnlessSignedIn(t)) {
                    return;
                }

                var allMedals:Array = NGIO.getMedals();
                if (allMedals == null || allMedals.length < 2) {
                    t.skip("fewer than two medals were returned by the server");
                    return;
                }

                var target:Medal = allMedals[0] as Medal;
                var bystander:Medal = allMedals[1] as Medal;
                var bystanderWasUnlocked:Boolean = bystander.unlocked;

                target.unlock(function(unlockedMedal:Medal, error:*):void {
                    if (assertNoError(t, error, "unlock accepted")) {
                        t.assertTrue(target.unlocked, "the targeted medal is unlocked");
                        t.assertEquals(bystanderWasUnlocked, bystander.unlocked,
                            "the other medal's state was not touched");
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

            // REMOVED: "refuses a session-gated unlock when signed out".
            //
            // It could never run. This suite is registered after sign-in, so its
            // own guard - skip if isSignedIn - fired on every run a developer
            // actually does, and the test reported [SKIP] "this path cannot be
            // reached" forever. It was coverage on paper only.
            //
            // Both halves of what it meant to test now live where they are
            // reachable: LiveNoSessionSuite covers the refusal with no session
            // at all, and LiveGuestSuite covers it with a guest session and no
            // user. Those two states behave differently and neither was
            // previously exercised live.

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
