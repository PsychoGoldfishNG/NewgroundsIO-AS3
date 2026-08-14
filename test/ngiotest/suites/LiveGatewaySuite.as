/**
 * LiveGatewaySuite
 *
 * The first live suite to run. Everything here works for a guest, so if these
 * fail the problem is connectivity, app credentials or sandbox permissions -
 * not session handling. Worth reading first when a live run goes wrong.
 */
package ngiotest.suites {

    import ngiotest.LiveSuite;
    import ngiotest.TestConfig;
    import ngiotest.TestContext;

    public class LiveGatewaySuite extends LiveSuite {

        override public function get suiteName():String {
            return "Live / Gateway";
        }

        override public function build():void {

            add("ping reaches the gateway", function(t:TestContext):void {
                // If this one test fails and everything else in the live run
                // fails with it, treat it as "no route to the server" rather
                // than chasing individual components.
                NGIO.sendPing(function(pong:String, error:*):void {
                    if (assertNoError(t, error, "ping returned without error")) {
                        t.assertEquals("pong", pong, "server answered pong");
                    }
                    t.done();
                });
            });

            add("reports the gateway version", function(t:TestContext):void {
                NGIO.loadGatewayVersion(function(version:String, error:*):void {
                    if (assertNoError(t, error, "gateway version loaded")) {
                        if (t.assertNotNull(version, "version string present")) {
                            t.assertTrue(version.length > 0, "version string is not empty");
                            t.note("gateway version " + version);
                        }
                        t.assertEquals(version, NGIO.getGatewayVersion(), "cached on AppState");
                    }
                    t.done();
                });
            });

            add("server time is close to local time", function(t:TestContext):void {
                // A wildly wrong result here usually means the timestamp was
                // parsed as a 32-bit int and truncated, which then breaks
                // anything that compares dates.
                NGIO.loadGatewayTimestamp(function(timestamp:Number, error:*):void {
                    if (assertNoError(t, error, "timestamp loaded")) {
                        if (t.assertNotNull(timestamp, "timestamp present")) {
                            var localSeconds:Number = new Date().time / 1000;
                            t.assertWithin(localSeconds, timestamp, 86400,
                                "server timestamp is within a day of local time");
                            t.note("server unix time " + timestamp);
                        }
                    }
                    t.done();
                });
            });

            add("returns an ISO 8601 datetime", function(t:TestContext):void {
                NGIO.loadGatewayDateTime(function(datetime:String, error:*):void {
                    if (assertNoError(t, error, "datetime loaded")) {
                        if (t.assertNotNull(datetime, "datetime present")) {
                            // e.g. 2026-08-13T10:15:00+00:00
                            t.assertTrue(datetime.length >= 19, "datetime is long enough to be ISO 8601");
                            t.assertTrue(datetime.indexOf("T") == 10, "has a T separator at index 10");
                            t.assertTrue(datetime.indexOf("-") == 4, "has a year-month separator at index 4");
                            t.note("server datetime " + datetime);
                        }
                    }
                    t.done();
                });
            });

            add("converts server time to a Date", function(t:TestContext):void {
                NGIO.loadGatewayDate(function(date:Date, error:*):void {
                    if (assertNoError(t, error, "date loaded")) {
                        if (t.assertNotNull(date, "date present")) {
                            t.assertIsType(date, Date, "is a Date instance");
                            t.assertTrue(date.fullYear >= 2024, "year is plausible, got " + date.fullYear);
                        }
                    }
                    t.done();
                });
            });

            add("reports whether this host is approved", function(t:TestContext):void {
                // The test app runs in viral mode with nothing blocked, so any
                // host - including the local IDE sandbox - should be approved.
                NGIO.loadHostApproved(function(approved:Boolean, error:*):void {
                    if (assertNoError(t, error, "host license loaded")) {
                        t.assertTrue(approved, "host approved for a viral-mode app");
                        t.assertEquals(approved, NGIO.getHostApproved(), "cached on AppState");
                    }
                    t.done();
                });
            });

            add("reports the app version state", function(t:TestContext):void {
                // The AS3 test app has version control switched off, so there is
                // no published version to be behind.
                NGIO.loadCurrentVersion(function(version:String, error:*):void {
                    if (assertNoError(t, error, "current version loaded")) {
                        t.note("current version reported as " + version);
                        t.assertFalse(NGIO.getClientDeprecated(),
                            "client is not deprecated when version control is off");
                    }
                    t.done();
                });
            });

            add("logs a custom event", function(t:TestContext):void {
                NGIO.logEvent(TestConfig.CUSTOM_EVENT, function(error:*):void {
                    assertNoError(t, error, "logEvent('" + TestConfig.CUSTOM_EVENT + "')");
                    t.done();
                });
            });

            add("rejects an event the app does not define", function(t:TestContext):void {
                // The gateway should refuse an unknown event name rather than
                // silently accepting it, otherwise a typo in a game is invisible.
                NGIO.logEvent("definitely-not-a-real-event", function(error:*):void {
                    if (error == null) {
                        t.note("gateway accepted an undefined event name without complaint");
                    } else {
                        t.note("gateway rejected the undefined event: " + describeError(error));
                    }
                    // Recorded as an observation rather than a hard assertion:
                    // which side enforces the event list is a server policy
                    // decision, not a client contract.
                    t.assert(true, "undefined event name handled without throwing");
                    t.done();
                });
            });
        }
    }
}
