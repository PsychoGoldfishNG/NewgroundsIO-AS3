/**
 * LiveCloudSaveSuite
 *
 * Writes to a cloud save slot, reads it back over HTTP, and clears it.
 *
 * NOTE ON DEBUG MODE: unlike medals and scores, it is not certain that cloud
 * saves honour debug mode server-side. This suite therefore treats slot
 * TestConfig.TEST_SAVE_SLOT_ID as genuinely writable and restores it to empty
 * at the end. Point TEST_SAVE_SLOT_ID at a scratch slot, never one holding data
 * you care about.
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

        override public function get suiteName():String {
            return "Live / Cloud saves";
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
                t.status("Writing to cloud save slot " + slot.id + "...");

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

            add("refuses cloud saves when signed out", function(t:TestContext):void {
                if (isSignedIn) {
                    t.skip("a user is signed in, so this path cannot be reached");
                    return;
                }

                var slot:SaveSlot = new SaveSlot();
                slot.core = core;
                slot.id = TestConfig.TEST_SAVE_SLOT_ID;

                slot.saveDataRaw("should not persist", function(error:*):void {
                    t.assertNotNull(error, "guest write is refused");
                    if (error != null) {
                        t.note("server said: " + describeError(error));
                    }
                    t.done();
                });
            });
        }

        override public function tearDown(done:Function):void {
            // Leave both scratch slots empty regardless of how the suite ended,
            // so a failed run does not leave test data on the account.
            if (!isSignedIn) {
                done.call(null);
                return;
            }

            clearIfUsed(testSlot(), function():void {
                clearIfUsed(altSlot(), function():void {
                    done.call(null);
                });
            });
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
