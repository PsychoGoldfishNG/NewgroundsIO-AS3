/**
 * OfflineLocalDataSuite
 *
 * What the library keeps on this computer: medal unlocks still waiting on the
 * gateway (MedalUnlockQueue), and the local copies of save slots (AppState's
 * save slot local fallback and the SaveSlot methods built on it).
 *
 * Nothing here touches the network or the real SharedObject. Storage goes to an
 * in-memory store through LocalStorageHelper.store, and the gateway is replaced
 * by Core.requestHandler, which answers each request with whatever the test
 * says.
 */
package ngiotest.suites {

    import io.newgrounds.Core;
    import io.newgrounds.Errors;
    import io.newgrounds.NGJSON;
    import io.newgrounds.helpers.DateTimeHelper;
    import io.newgrounds.helpers.LocalStorageHelper;
    import io.newgrounds.models.objects.Medal;
    import io.newgrounds.models.objects.ObjectFactory;
    import io.newgrounds.models.objects.SaveSlot;
    import io.newgrounds.models.objects.User;

    import ngiotest.TestConfig;
    import ngiotest.TestContext;
    import ngiotest.TestSuite;

    public class OfflineLocalDataSuite extends TestSuite {

        /** Not the real test app, so nothing here can collide with live data */
        private static const APP_ID:String = "11111:OfflineTest";

        private static const CLOUD_TIME:String = "2026-08-20T14:32:00-04:00";
        private static const NEWER_TIME:String = "2026-08-21T00:00:00.000Z";
        private static const OLDER_TIME:String = "2020-01-01T00:00:00.000Z";

        /** The in-memory store, as key -> value */
        private var memory:Object;

        override public function get suiteName():String {
            return "Offline / Local data";
        }

        override public function setUp(done:Function):void {
            resetStore();
            done.call(null);
        }

        override public function tearDown(done:Function):void {
            LocalStorageHelper.store = null;
            done.call(null);
        }

        override public function build():void {

            //==================== DATES ====================

            add("parses an ISO 8601 datetime with any offset", function(t:TestContext):void {
                resetStore();
                var utc:Number = DateTimeHelper.parseIso("2026-08-25T21:42:42Z");
                t.assertEquals(Date.UTC(2026, 7, 25, 21, 42, 42), utc, "Z");
                t.assertEquals(utc, DateTimeHelper.parseIso("2026-08-25T17:42:42-04:00"), "a negative offset is the same moment");
                t.assertEquals(utc, DateTimeHelper.parseIso("2026-08-25T23:42:42+02:00"), "a positive offset is the same moment");
                t.assertEquals(utc + 500, DateTimeHelper.parseIso("2026-08-25T21:42:42.5Z"), "fractions of a second");
                t.assertTrue(isNaN(DateTimeHelper.parseIso("not a date")), "junk is NaN");
                t.assertTrue(isNaN(DateTimeHelper.parseIso(null)), "null is NaN");
                t.done();
            });

            add("writes UTC datetimes that read back", function(t:TestContext):void {
                var time:Number = Date.UTC(2026, 0, 2, 3, 4, 5, 6);
                t.assertEquals("2026-01-02T03:04:05.006Z", DateTimeHelper.toIso(time), "formatted");
                t.assertEquals(time, DateTimeHelper.parseIso(DateTimeHelper.toIso(time)), "round trip");
                t.done();
            });

            //==================== MEDAL UNLOCK QUEUE ====================

            add("records an unlock before sending it", function(t:TestContext):void {
                resetStore();
                var core:Core = signedInCore(1);
                core.requestHandler = function(request:String, respond:Function):void {
                    // Never answered: the connection dropped
                };
                core.medalUnlockQueue.unlock([5]);
                t.assertEquals("5", core.medalUnlockQueue.getPendingIds().join(","), "buffered");
                t.done();
            });

            add("drops an unlock the gateway accepted", function(t:TestContext):void {
                resetStore();
                var core:Core = signedInCore(1);
                answerAll(core, unlockReply(true, 0));
                core.medalUnlockQueue.unlock([5], function(outcomes:Array):void {
                    t.assertNull(outcomes[0].error, "no error");
                    t.assertNotNull(outcomes[0].medal, "the medal");
                    t.assertEquals(0, core.medalUnlockQueue.getPendingIds().length, "no longer buffered");
                    t.done();
                });
            });

            add("drops an unlock the gateway rejected for that medal", function(t:TestContext):void {
                resetStore();
                var core:Core = signedInCore(1);
                answerAll(core, unlockReply(false, Errors.INVALID_MEDAL_ID));
                core.medalUnlockQueue.unlock([5], function(outcomes:Array):void {
                    t.assertEquals(Errors.INVALID_MEDAL_ID, outcomes[0].error.code, "the gateway's error");
                    t.assertEquals(0, core.medalUnlockQueue.getPendingIds().length, "never retried");
                    t.done();
                });
            });

            add("keeps an unlock blocked on the session", function(t:TestContext):void {
                resetStore();
                var core:Core = signedInCore(1);
                answerAll(core, unlockReply(false, Errors.EXPIRED_SESSION));
                core.medalUnlockQueue.unlock([5], function(outcomes:Array):void {
                    t.assertNotNull(outcomes[0].error, "an error");
                    t.assertEquals("5", core.medalUnlockQueue.getPendingIds().join(","), "kept for a retry");
                    t.done();
                });
            });

            add("keeps an unlock that got no answer", function(t:TestContext):void {
                resetStore();
                var core:Core = signedInCore(1);
                core.requestHandler = function(request:String, respond:Function):void {
                    respond(0, null);
                };
                core.medalUnlockQueue.unlock([5], function(outcomes:Array):void {
                    t.assertNotNull(outcomes[0].error, "an error");
                    t.assertEquals("5", core.medalUnlockQueue.getPendingIds().join(","), "kept for a retry");
                    t.done();
                });
            });

            add("never sends one player's unlock for another", function(t:TestContext):void {
                resetStore();
                memory["ngio-pending-medal-unlocks-for-" + APP_ID] = NGJSON.stringify([{id: 5, user: 2}]);
                var core:Core = signedInCore(1);
                var sent:int = 0;
                core.requestHandler = function(request:String, respond:Function):void {
                    sent++;
                };
                core.medalUnlockQueue.retryPending();
                t.assertEquals(0, sent, "nothing sent");
                t.assertEquals("5", core.medalUnlockQueue.getPendingIds().join(","), "still waiting for player 2");
                t.done();
            });

            add("sends a guest unlock for whoever signs in, and settles it", function(t:TestContext):void {
                resetStore();
                // An entry from before unlocks recorded their player reads as a guest's
                memory["ngio-pending-medal-unlocks-for-" + APP_ID] = "[5]";
                var core:Core = signedInCore(1);
                answerAll(core, unlockReply(true, 0));
                core.medalUnlockQueue.retryPending();
                t.assertEquals(0, core.medalUnlockQueue.getPendingIds().length, "settled for player 1");
                t.done();
            });

            add("doesn't keep a guest unlock when keepGuestUnlocks is off", function(t:TestContext):void {
                resetStore();
                var core:Core = new Core(APP_ID, TestConfig.ENCRYPTION_KEY);
                core.appState.session.id = "guest-session";
                core.medalUnlockQueue.keepGuestUnlocks = false;
                core.medalUnlockQueue.unlock([5], function(outcomes:Array):void {
                    t.assertEquals(Errors.LOGIN_REQUIRED, outcomes[0].error.code, "refused: nobody signed in");
                    t.assertEquals(0, core.medalUnlockQueue.getPendingIds().length, "not kept");
                    t.done();
                });
            });

            add("holds guest unlocks on a retry pass when holdGuestUnlocks is on", function(t:TestContext):void {
                resetStore();
                memory["ngio-pending-medal-unlocks-for-" + APP_ID] = NGJSON.stringify([{id: 5, user: null}, {id: 6, user: 1}]);
                var core:Core = signedInCore(1);
                core.medalUnlockQueue.holdGuestUnlocks = true;
                var sent:int = 0;
                core.requestHandler = function(request:String, respond:Function):void {
                    sent++;
                    respond(200, unlockReply(true, 0));
                };
                core.medalUnlockQueue.retryPending();
                t.assertEquals(1, sent, "only the player's own entry was sent");
                t.assertEquals("5", core.medalUnlockQueue.getGuestIds().join(","), "the guest entry still waits");
                t.done();
            });

            add("claims guest unlocks for the signed-in player", function(t:TestContext):void {
                resetStore();
                memory["ngio-pending-medal-unlocks-for-" + APP_ID] = NGJSON.stringify([{id: 5, user: null}, {id: 9, user: null}]);
                var core:Core = signedInCore(1);
                core.medalUnlockQueue.holdGuestUnlocks = true;
                answerAll(core, unlockReply(true, 0));
                core.medalUnlockQueue.claimGuestUnlocks([5, 77], function(outcomes:Array):void {
                    t.assertEquals(1, outcomes.length, "77 had no guest entry");
                    t.assertEquals(5, outcomes[0].id, "5 was claimed");
                    t.assertEquals("9", core.medalUnlockQueue.getPendingIds().join(","), "only 9 is left");
                    t.done();
                });
            });

            add("keeps a claimed unlock as the player's own when it can't be sent yet", function(t:TestContext):void {
                resetStore();
                memory["ngio-pending-medal-unlocks-for-" + APP_ID] = NGJSON.stringify([{id: 5, user: null}]);
                var core:Core = signedInCore(1);
                core.medalUnlockQueue.holdGuestUnlocks = true;
                core.requestHandler = function(request:String, respond:Function):void {
                    respond(0, null);
                };
                core.medalUnlockQueue.claimGuestUnlocks([5], function(outcomes:Array):void {
                    t.assertEquals(0, core.medalUnlockQueue.getGuestIds().length, "no longer a guest entry");
                    t.assertEquals("5", core.medalUnlockQueue.getPendingIds().join(","), "still pending, as player 1's");
                    t.done();
                });
            });

            add("claims nothing with nobody signed in", function(t:TestContext):void {
                resetStore();
                memory["ngio-pending-medal-unlocks-for-" + APP_ID] = NGJSON.stringify([{id: 5, user: null}]);
                var core:Core = new Core(APP_ID, TestConfig.ENCRYPTION_KEY);
                core.medalUnlockQueue.claimGuestUnlocks([5], function(outcomes:Array):void {
                    t.assertEquals(0, outcomes.length, "nothing claimed");
                    t.assertEquals("5", core.medalUnlockQueue.getGuestIds().join(","), "still a guest entry");
                    t.done();
                });
            });

            add("discards guest unlocks and leaves players' own", function(t:TestContext):void {
                resetStore();
                memory["ngio-pending-medal-unlocks-for-" + APP_ID] = NGJSON.stringify([{id: 5, user: null}, {id: 5, user: 2}, {id: 6, user: null}]);
                var core:Core = signedInCore(1);
                core.medalUnlockQueue.discardGuestUnlocks([5]);
                t.assertEquals("6", core.medalUnlockQueue.getGuestIds().join(","), "only 6 is left as a guest entry");
                t.assertEquals("5,6", core.medalUnlockQueue.getPendingIds().join(","), "player 2's 5 is untouched");
                t.done();
            });

            add("Medal.unlock() marks the medal unlocked only when the gateway accepts it", function(t:TestContext):void {
                resetStore();
                var core:Core = signedInCore(1);
                var medal:Medal = ObjectFactory.CreateObject("Medal", {id: 5, name: "Test"}, core) as Medal;
                answerAll(core, unlockReply(false, Errors.EXPIRED_SESSION));
                medal.unlock(function(sameMedal:Medal, error:*):void {
                    t.assert(sameMedal === medal, "called back with the same medal");
                    t.assertNotNull(error, "refused");
                    t.assertFalse(medal.unlocked, "not marked unlocked");

                    answerAll(core, unlockReply(true, 0));
                    medal.unlock(function(sameMedal2:Medal, error2:*):void {
                        t.assertNull(error2, "accepted");
                        t.assertTrue(medal.unlocked, "marked unlocked");
                        t.done();
                    });
                });
            });

            //==================== SAVE SLOTS: WHOSE COPY ====================

            add("lists guest copies when signed out", function(t:TestContext):void {
                resetStore();
                seedLocal(2, "guest-save", NEWER_TIME, null);
                var core:Core = new Core(APP_ID, TestConfig.ENCRYPTION_KEY);
                var sent:int = 0;
                core.requestHandler = function(request:String, respond:Function):void {
                    sent++;
                };
                core.appState.loadData(["saveSlots"], function(appState:*, error:*):void {
                    t.assertNotNull(error, "still reports that the cloud list didn't load");
                    t.assertEquals(0, sent, "refused without being sent");
                    var slot:SaveSlot = slotById(core, 2);
                    if (t.assertNotNull(slot, "the guest copy is listed")) {
                        t.assertEquals("local", slot.source, "local");
                        t.assertTrue(slot.hasData(), "holds data");
                    }
                    t.done();
                });
            });

            add("lists the player's own copies when the request can't reach the gateway", function(t:TestContext):void {
                resetStore();
                seedLocal(3, "offline-save", NEWER_TIME, 1);
                var core:Core = signedInCore(1);
                core.requestHandler = function(request:String, respond:Function):void {
                    respond(0, null);
                };
                core.appState.loadData(["saveSlots"], function(appState:*, error:*):void {
                    t.assertNotNull(error, "an error");
                    var slot:SaveSlot = slotById(core, 3);
                    if (t.assertNotNull(slot, "listed")) {
                        t.assertEquals("local", slot.source, "local");
                    }
                    t.done();
                });
            });

            add("gives a fresh guest saveSlotCount empty slots to save into", function(t:TestContext):void {
                resetStore();
                var core:Core = new Core(APP_ID, TestConfig.ENCRYPTION_KEY);
                core.requestHandler = function(request:String, respond:Function):void {};
                core.appState.loadData(["saveSlots"], function(appState:*, error:*):void {
                    t.assertEquals(3, core.appState.saveSlots.length, "three slots by default");
                    for each (var slot:SaveSlot in core.appState.saveSlots) {
                        t.assertEquals("local", slot.source, "slot " + slot.id + " describes the local copy");
                        t.assertFalse(slot.hasData(), "slot " + slot.id + " is empty");
                    }
                    t.assertTrue(core.appState.hasLoaded("saveSlots"), "marked loaded");
                    t.done();
                });
            });

            add("lists as many empty slots as saveSlotCount says, around a guest copy", function(t:TestContext):void {
                resetStore();
                seedLocal(4, "guest-save", NEWER_TIME, null);
                var core:Core = new Core(APP_ID, TestConfig.ENCRYPTION_KEY);
                core.appState.saveSlotCount = 10;
                core.requestHandler = function(request:String, respond:Function):void {};
                core.appState.loadData(["saveSlots"], function(appState:*, error:*):void {
                    t.assertEquals(10, core.appState.saveSlots.length, "ten slots");
                    t.assertEquals(4, core.appState.saveSlots[3].id, "kept in id order");
                    t.assertTrue(slotById(core, 4).hasData(), "the guest copy is still there");
                    t.assertFalse(slotById(core, 5).hasData(), "the rest are empty");
                    t.done();
                });
            });

            add("fills the empty slots in place once the cloud list arrives", function(t:TestContext):void {
                resetStore();
                var core:Core = signedInCore(1);
                core.requestHandler = function(request:String, respond:Function):void {
                    respond(0, null);
                };
                core.appState.loadData(["saveSlots"], function(appState:*, error:*):void {
                    var placeholder:SaveSlot = slotById(core, 2);
                    core.appState.applySlotListResult([cloudSlot(core, 1, null), cloudSlot(core, 2, CLOUD_TIME), cloudSlot(core, 3, null)]);
                    t.assertTrue(slotById(core, 2) === placeholder, "the same slot");
                    t.assertEquals("cloud", placeholder.source, "now the cloud copy");
                    t.assertTrue(placeholder.hasData(), "holds the cloud save");
                    t.done();
                });
            });

            add("never shows one player's local copy to another", function(t:TestContext):void {
                resetStore();
                seedLocal(1, "player-two-save", NEWER_TIME, 2);
                var core:Core = signedInCore(1);
                core.appState.applySlotListResult([cloudSlot(core, 1, null)]);
                t.assertEquals("cloud", slotById(core, 1).source, "only the cloud copy");
                t.assertFalse(slotById(core, 1).hasData(), "empty");
                t.assertEquals("player-two-save", memory[localKey(2) + ":slot:1"], "still there for player 2");
                t.done();
            });

            add("gives a guest copy to the next player who signs in, and only to them", function(t:TestContext):void {
                resetStore();
                seedLocal(2, "guest-save", NEWER_TIME, null);
                var core:Core = signedInCore(1);
                core.appState.applySlotListResult([cloudSlot(core, 2, null)]);
                t.assertEquals("local", slotById(core, 2).source, "player 1 gets it");
                t.assertEquals("guest-save", memory[localKey(1) + ":slot:2"], "moved to player 1");
                t.assertNull(memory[localKey(null) + ":slot:2"], "gone from the guest copies");
                t.done();
            });

            add("keeps guest copies to guests when offerGuestSaves is off", function(t:TestContext):void {
                resetStore();
                seedLocal(2, "guest-save", NEWER_TIME, null);
                var core:Core = signedInCore(1);
                core.appState.offerGuestSaves = false;
                core.appState.applySlotListResult([cloudSlot(core, 2, null)]);
                t.assertFalse(slotById(core, 2).hasData(), "player 1 doesn't get it");
                t.assertEquals("guest-save", memory[localKey(null) + ":slot:2"], "still a guest copy");
                t.done();
            });

            add("signing out resets a slot's source", function(t:TestContext):void {
                resetStore();
                seedLocal(3, "local", NEWER_TIME, 1);
                var core:Core = signedInCore(1);
                core.appState.applySlotListResult([cloudSlot(core, 3, null)]);
                t.assertEquals("local", slotById(core, 3).source, "local while signed in");
                core.appState.clearSession();
                t.assertEquals("cloud", slotById(core, 3).source, "reset");
                t.assertEquals("local", memory[localKey(1) + ":slot:3"], "the copy is kept for player 1");
                t.done();
            });

            //==================== SAVE SLOTS: CONFLICTS ====================

            add("a newer local copy over a cloud save is a conflict", function(t:TestContext):void {
                resetStore();
                seedLocal(3, "offline-save", NEWER_TIME, 1);
                var core:Core = signedInCore(1);
                core.appState.applySlotListResult([cloudSlot(core, 3, CLOUD_TIME)]);
                var slot:SaveSlot = slotById(core, 3);
                t.assertEquals("conflict", slot.source, "conflict");
                t.assertEquals(CLOUD_TIME, slot.datetime, "the slot describes the cloud copy");
                var local:Object = slot.getLocalCopy();
                if (t.assertNotNull(local, "the local copy is described")) {
                    t.assertEquals(NEWER_TIME, local.datetime, "local datetime");
                }
                t.done();
            });

            add("an older local copy loses to the cloud, across time zones", function(t:TestContext):void {
                resetStore();
                // 14:32 at -04:00 is 18:32Z, so 18:00Z is older
                seedLocal(3, "older", "2026-08-20T18:00:00.000Z", 1);
                var core:Core = signedInCore(1);
                core.appState.applySlotListResult([cloudSlot(core, 3, CLOUD_TIME)]);
                t.assertEquals("cloud", slotById(core, 3).source, "cloud");
                t.done();
            });

            add("keepCloud() drops the local copy without sending anything", function(t:TestContext):void {
                resetStore();
                seedLocal(3, "offline-save", NEWER_TIME, 1);
                var core:Core = signedInCore(1);
                var sent:int = 0;
                core.requestHandler = function(request:String, respond:Function):void {
                    sent++;
                };
                core.appState.applySlotListResult([cloudSlot(core, 3, CLOUD_TIME)]);
                t.assertTrue(slotById(core, 3).keepCloud(), "dropped");
                t.assertEquals("cloud", slotById(core, 3).source, "cloud");
                t.assertNull(memory[localKey(1) + ":slot:3"], "the local copy is gone");
                t.assertEquals(0, sent, "nothing sent");
                t.done();
            });

            add("keepLocal() and keepCloud() change nothing without a conflict", function(t:TestContext):void {
                resetStore();
                seedLocal(3, "local-only", NEWER_TIME, 1);
                var core:Core = signedInCore(1);
                core.appState.applySlotListResult([cloudSlot(core, 3, null)]);
                var slot:SaveSlot = slotById(core, 3);
                t.assertFalse(slot.keepCloud(), "keepCloud refused");
                slot.keepLocal(function(error:*):void {
                    t.assertNotNull(error, "keepLocal refused");
                    t.assertEquals("local-only", memory[localKey(1) + ":slot:3"], "untouched");
                    t.done();
                });
            });

            add("still finds a conflict on an offline reload", function(t:TestContext):void {
                resetStore();
                var core:Core = signedInCore(1);
                core.appState.applySlotListResult([cloudSlot(core, 3, CLOUD_TIME)]);
                seedLocal(3, "offline-save", NEWER_TIME, 1);
                core.requestHandler = function(request:String, respond:Function):void {
                    respond(0, null);
                };
                core.appState.loadData(["saveSlots"], function(appState:*, error:*):void {
                    t.assertEquals("conflict", slotById(core, 3).source, "conflict");
                    t.done();
                });
            });

            add("an offline reload doesn't let an older local copy replace a known cloud copy", function(t:TestContext):void {
                resetStore();
                seedLocal(3, "older", OLDER_TIME, 1);
                var core:Core = signedInCore(1);
                core.appState.applySlotListResult([cloudSlot(core, 3, CLOUD_TIME)]);
                core.requestHandler = function(request:String, respond:Function):void {
                    respond(0, null);
                };
                core.appState.loadData(["saveSlots"], function(appState:*, error:*):void {
                    t.assertEquals("cloud", slotById(core, 3).source, "still cloud");
                    t.assertEquals(CLOUD_TIME, slotById(core, 3).datetime, "still the cloud copy");
                    t.done();
                });
            });

            //==================== SAVE SLOTS: WRITING ====================

            add("a save that only reaches the local copy still succeeds", function(t:TestContext):void {
                resetStore();
                var core:Core = signedInCore(1);
                core.appState.applySlotListResult([cloudSlot(core, 1, null)]);
                core.requestHandler = function(request:String, respond:Function):void {
                    respond(0, null);
                };
                slotById(core, 1).saveDataRaw("offline-payload", function(error:*):void {
                    t.assertNull(error, "reported as saved");
                    t.assertEquals("local", slotById(core, 1).source, "flagged as local");
                    t.assertEquals("offline-payload", memory[localKey(1) + ":slot:1"], "in the player's own copies");
                    t.done();
                });
            });

            add("a save the cloud accepted is stamped with the cloud's datetime", function(t:TestContext):void {
                resetStore();
                var core:Core = signedInCore(1);
                core.appState.applySlotListResult([cloudSlot(core, 1, null)]);
                answerAll(core, '{"success":true,"app_id":"' + APP_ID + '","result":{"component":"CloudSave.setData",' +
                    '"data":{"success":true,"slot":' + NGJSON.stringify(cloudSlotData(1, CLOUD_TIME)) + '}}}');
                slotById(core, 1).saveDataRaw("synced", function(error:*):void {
                    t.assertNull(error, "saved");
                    t.assertEquals("cloud", slotById(core, 1).source, "cloud");
                    var registry:Object = NGJSON.parse(memory[localKey(1) + ":registry"]);
                    t.assertEquals(CLOUD_TIME, registry["1"].datetime, "the cloud's datetime, not this computer's");
                    t.done();
                });
            });

            add("a slot from another app never reads this app's local copy", function(t:TestContext):void {
                resetStore();
                seedLocal(3, "this app's save", NEWER_TIME, 1);
                var core:Core = signedInCore(1);
                var foreign:SaveSlot = ObjectFactory.CreateObject("SaveSlot", cloudSlotData(3, CLOUD_TIME), core) as SaveSlot;
                foreign.foreignAppId = TestConfig.READABLE_FOREIGN_APP_ID;
                foreign.source = "conflict";
                t.assertNull(foreign.getLocalCopy(), "no local copy");
                t.assertFalse(foreign.keepCloud(), "nothing to drop");
                t.done();
            });
        }

        //==================== HELPERS ====================

        private function resetStore():void {
            memory = {};
            var self:OfflineLocalDataSuite = this;
            LocalStorageHelper.store = {
                getValue: function(key:String):String {
                    return self.memory.hasOwnProperty(key) ? self.memory[key] : null;
                },
                setValue: function(key:String, value:String):Boolean {
                    self.memory[key] = value;
                    return true;
                },
                removeValue: function(key:String):Boolean {
                    delete self.memory[key];
                    return true;
                }
            };
        }

        private function signedInCore(userId:Number):Core {
            var core:Core = new Core(APP_ID, TestConfig.ENCRYPTION_KEY);
            core.appState.session.id = "session-" + userId;
            var user:User = new User();
            user.id = userId;
            user.name = "Player " + userId;
            core.appState.session.user = user;
            return core;
        }

        /** Answers every request with the same JSON */
        private function answerAll(core:Core, json:String):void {
            core.requestHandler = function(request:String, respond:Function):void {
                respond(200, json);
            };
        }

        private function unlockReply(success:Boolean, errorCode:int):String {
            var data:Object = success
                ? {success: true, medal: {id: 5, name: "Test", unlocked: true}, medal_score: 10}
                : {success: false, error: {code: errorCode, message: "Refused"}};
            return NGJSON.stringify({success: true, app_id: APP_ID, result: {component: "Medal.unlock", data: data}});
        }

        private function localKey(owner:*):String {
            var base:String = "ngio-local-save-slots-for-" + APP_ID;
            return (owner === null) ? base : base + ":user:" + owner;
        }

        /** Writes a local copy the way LocalSaveSlotStore would */
        private function seedLocal(id:Number, data:String, datetime:String, owner:*):void {
            var key:String = localKey(owner);
            var registry:Object = memory.hasOwnProperty(key + ":registry") ? NGJSON.parse(memory[key + ":registry"]) : {};
            registry[String(id)] = {size: data.length, datetime: datetime, hasData: true};
            memory[key + ":slot:" + id] = data;
            memory[key + ":registry"] = NGJSON.stringify(registry);
        }

        private function cloudSlotData(id:Number, datetime:String):Object {
            return {
                id: id,
                size: (datetime == null) ? 0 : 100,
                datetime: datetime,
                timestamp: (datetime == null) ? 0 : Math.floor(DateTimeHelper.parseIso(datetime) / 1000),
                url: (datetime == null) ? null : "https://example.com/slot" + id + ".dat"
            };
        }

        private function cloudSlot(core:Core, id:Number, datetime:String):SaveSlot {
            return ObjectFactory.CreateObject("SaveSlot", cloudSlotData(id, datetime), core) as SaveSlot;
        }

        private function slotById(core:Core, id:Number):SaveSlot {
            if (core.appState.saveSlots == null) return null;
            for each (var slot:SaveSlot in core.appState.saveSlots) {
                if (slot.id == id) return slot;
            }
            return null;
        }
    }
}
