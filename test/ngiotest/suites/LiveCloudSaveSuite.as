/**
 * LiveCloudSaveSuite
 *
 * Writes to a cloud save slot, reads it back over HTTP, and clears it.
 *
 * NOTE ON DEBUG MODE: the gateway never writes a cloud save in debug mode, so a
 * round trip under TestConfig.USE_DEBUG_MODE would read back whatever the slot
 * held before. This suite turns debug mode off for its own run, writes for real
 * to TestConfig.TEST_SAVE_SLOT_ID and TEST_SAVE_SLOT_ID_ALT, and empties both in
 * tearDown. Point those at scratch slots, never ones holding data you care
 * about. One test switches debug mode back on to check that a debug write
 * leaves the slot alone.
 *
 * The read-back is a plain HTTP GET against the returned url, so it is also the
 * only live test that exercises a non-gateway request.
 */
package ngiotest.suites {

    import io.newgrounds.models.objects.SaveSlot;

    import ngiotest.LiveSuite;
    import ngiotest.TestConfig;
    import ngiotest.TestContext;

    public class LiveCloudSaveSuite extends LiveSuite {

        /** Payload written by the save test and checked by the load test */
        private var writtenPayload:String;

        /** The Core's debug mode before setUp turned it off, put back in tearDown */
        private var savedDebugMode:Boolean;

        override public function get suiteName():String {
            return "Live / Cloud saves";
        }

        override public function setUp(done:Function):void {
            super.setUp(function():void {
                savedDebugMode = core.useDebugMode;
                core.useDebugMode = false;
                done.call(null);
            });
        }

        override public function build():void {

            add("writes raw data to a slot", function(t:TestContext):void {
                if (skipUnlessSignedIn(t)) {
                    return;
                }

                var slot:SaveSlot = testSlot();
                if (slot == null) {
                    t.skip("save slot " + TestConfig.TEST_SAVE_SLOT_ID + " not available");
                    return;
                }

                // Unique per run, so a stale read cannot pass by accident.
                writtenPayload = "ngio-as3-unit-test:" + new Date().time;
                slot.saveDataRaw(writtenPayload, function(error:*):void {
                    assertNoError(t, error, "saveDataRaw accepted");
                    t.done();
                });
            });

            add("reports the slot as holding data", function(t:TestContext):void {
                if (skipUnlessSignedIn(t)) {
                    return;
                }

                // Re-fetch the slot list so this reflects server state rather
                // than whatever the write left in memory.
                NGIO.loadSaveSlots(function(slots:Array, error:*):void {
                    if (!assertNoError(t, error, "slot list reloaded")) {
                        t.done();
                        return;
                    }

                    var slot:SaveSlot = testSlot();
                    if (!t.assertNotNull(slot, "test slot present in the list")) {
                        t.done();
                        return;
                    }

                    t.assertTrue(slot.hasData(), "slot reports data after the write");
                    t.assertTrue(slot.size > 0, "slot reports a non-zero size");
                    t.assertNotNull(slot.datetime, "slot reports a save datetime");
                    t.assertTrue(slot.timestamp > 0, "slot reports a save timestamp");
                    t.note("slot " + slot.id + ": " + slot.size + " bytes, saved " + slot.datetime);
                    t.done();
                });
            });

            add("reads the data back over HTTP", function(t:TestContext):void {
                if (skipUnlessSignedIn(t)) {
                    return;
                }

                var slot:SaveSlot = testSlot();
                if (slot == null || !slot.hasData()) {
                    t.skip("test slot holds no data to read");
                    return;
                }

                if (writtenPayload == null) {
                    t.skip("nothing was written this run to compare against");
                    return;
                }

                slot.loadDataRaw(function(data:String, error:*):void {
                    if (!assertNoError(t, error, "loadDataRaw completed")) {
                        t.done();
                        return;
                    }

                    if (t.assertNotNull(data, "data returned")) {
                        t.assertEquals(writtenPayload, data, "round-tripped exactly what was written");
                    }
                    t.done();
                });
            });

            add("a debug-mode write leaves the slot alone", function(t:TestContext):void {
                if (skipUnlessSignedIn(t)) {
                    return;
                }

                var slot:SaveSlot = testSlot();
                if (slot == null || !slot.hasData() || writtenPayload == null) {
                    t.skip("the real write above did not land, so there is nothing to compare against");
                    return;
                }

                var sizeBefore:int = slot.size;
                var timestampBefore:Number = slot.timestamp;

                core.useDebugMode = true;
                slot.saveDataRaw("ngio-as3-debug-write:" + new Date().time, function(error:*):void {
                    core.useDebugMode = false;

                    if (!assertNoError(t, error, "debug-mode saveDataRaw accepted")) {
                        t.done();
                        return;
                    }

                    NGIO.loadSaveSlots(function(slots:Array, reloadError:*):void {
                        if (!assertNoError(t, reloadError, "slot list reloaded")) {
                            t.done();
                            return;
                        }

                        var after:SaveSlot = testSlot();
                        if (!t.assertNotNull(after, "test slot present in the list")) {
                            t.done();
                            return;
                        }

                        t.assertEquals(sizeBefore, after.size, "size unchanged");
                        t.assertEquals(timestampBefore, after.timestamp, "save timestamp unchanged");

                        after.loadDataRaw(function(data:String, loadError:*):void {
                            if (assertNoError(t, loadError, "loadDataRaw completed")) {
                                t.assertEquals(writtenPayload, data, "slot still holds the real write's data");
                            }
                            t.done();
                        });
                    });
                });
            });

            add("round-trips a structured object", function(t:TestContext):void {
                if (skipUnlessSignedIn(t)) {
                    return;
                }

                // Deliberately a different slot from the raw-text tests above -
                // see TEST_SAVE_SLOT_ID_ALT for why sharing one slot made this
                // read back the previous test's payload from cache.
                var slot:SaveSlot = altSlot();
                if (slot == null) {
                    t.skip("save slot " + TestConfig.TEST_SAVE_SLOT_ID_ALT + " not available");
                    return;
                }

                var payload:Object = {
                    level: 7,
                    name: "Tester",
                    unlocked: true,
                    inventory: ["sword", "shield"],
                    ratio: 0.75
                };

                slot.saveData(payload, function(saveError:*):void {
                    if (!assertNoError(t, saveError, "saveData accepted")) {
                        t.done();
                        return;
                    }

                    slot.loadData(function(loaded:Object, loadError:*):void {
                        if (!assertNoError(t, loadError, "loadData completed")) {
                            t.done();
                            return;
                        }

                        if (!t.assertNotNull(loaded, "object returned")) {
                            t.done();
                            return;
                        }

                        // assertNotNull is not enough: 0 is not null. If the url
                        // served something other than our JSON - a proxy page, a
                        // CDN error - a lenient parse can hand back a primitive,
                        // and reading .level off a Number throws from inside the
                        // URLLoader handler. That loses t.done() and burns a
                        // watchdog timeout instead of failing here with a reason.
                        if (loaded is Number || loaded is String || loaded is Boolean) {
                            t.fail("loadData returned the primitive <" + loaded + "> rather than an object" +
                                   " - the slot url probably did not serve our JSON");
                            t.done();
                            return;
                        }

                        t.assertEquals(7, loaded.level, "number survived");
                        t.assertEquals("Tester", loaded.name, "string survived");
                        t.assertStrictEquals(true, loaded.unlocked, "boolean survived");
                        t.assertEquals(0.75, loaded.ratio, "float survived");
                        if (t.assertNotNull(loaded.inventory, "array survived")) {
                            t.assertEquals(2, (loaded.inventory as Array).length, "array length survived");
                            t.assertEquals("sword", loaded.inventory[0], "array contents survived");
                        }
                        t.done();
                    });
                });
            });

            add("clears the slot", function(t:TestContext):void {
                if (skipUnlessSignedIn(t)) {
                    return;
                }

                var slot:SaveSlot = testSlot();
                if (slot == null) {
                    t.skip("save slot " + TestConfig.TEST_SAVE_SLOT_ID + " not available");
                    return;
                }

                slot.clearData(function(error:*):void {
                    if (!assertNoError(t, error, "clearData accepted")) {
                        t.done();
                        return;
                    }

                    NGIO.loadSaveSlots(function(slots:Array, reloadError:*):void {
                        if (assertNoError(t, reloadError, "slot list reloaded after clear")) {
                            var cleared:SaveSlot = testSlot();
                            if (t.assertNotNull(cleared, "slot still listed")) {
                                t.assertFalse(cleared.hasData(), "slot reports empty after clearing");
                            }
                        }
                        t.done();
                    });
                });
            });

            add("reading an empty slot returns null, not an error", function(t:TestContext):void {
                if (skipUnlessSignedIn(t)) {
                    return;
                }

                var slot:SaveSlot = testSlot();
                if (slot == null) {
                    t.skip("save slot " + TestConfig.TEST_SAVE_SLOT_ID + " not available");
                    return;
                }

                if (slot.hasData()) {
                    t.skip("slot was not left empty by the clear test");
                    return;
                }

                slot.loadDataRaw(function(data:String, error:*):void {
                    t.assertNull(data, "no data returned");
                    t.assertNull(error, "an empty slot is not an error condition");
                    t.done();
                });
            });

            // REMOVED: "refuses cloud saves when signed out".
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
        }

        override public function tearDown(done:Function):void {
            // Leave both scratch slots empty regardless of how the suite ended,
            // so a failed run does not leave test data on the account. Debug
            // mode stays off until then, or the clears would not happen either.
            if (!isSignedIn) {
                restoreDebugMode(done);
                return;
            }

            core.useDebugMode = false;
            clearIfUsed(testSlot(), function():void {
                clearIfUsed(altSlot(), function():void {
                    restoreDebugMode(done);
                });
            });
        }

        private function restoreDebugMode(done:Function):void {
            if (core != null) {
                core.useDebugMode = savedDebugMode;
            }
            super.tearDown(done);
        }

        //==================== HELPERS ====================

        private function clearIfUsed(slot:SaveSlot, next:Function):void {
            if (slot == null || !slot.hasData()) {
                next.call(null);
                return;
            }

            slot.clearData(function(error:*):void {
                next.call(null);
            });
        }

        private function testSlot():SaveSlot {
            return NGIO.getSaveSlot(TestConfig.TEST_SAVE_SLOT_ID) as SaveSlot;
        }

        private function altSlot():SaveSlot {
            return NGIO.getSaveSlot(TestConfig.TEST_SAVE_SLOT_ID_ALT) as SaveSlot;
        }
    }
}
