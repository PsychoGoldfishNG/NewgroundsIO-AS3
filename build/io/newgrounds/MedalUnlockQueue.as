/**
 * MedalUnlockQueue
 *
 * A durable buffer of medal ids whose unlock was requested but never confirmed,
 * and the background pass that retries them.
 *
 * An unlock sent straight to the gateway is lost if the connection drops
 * mid-request or the player closes the game before the answer arrives, and the
 * player has already earned the medal. Ids are recorded before the request goes
 * out, so a crash mid-request still leaves the id behind for the next attempt.
 *
 * Core creates one of these in its constructor. That's what scopes the buffer
 * correctly: the pending set is per App ID and Core is the per-app instance.
 * NGIO drives the retry pass on a timer, the same way it drives keepAlive().
 *
 * Each buffered unlock records the player who earned it (their user id, or null
 * when nobody was signed in), so on a shared computer one player's unlock is
 * never sent for another.
 */
package io.newgrounds {

	import io.newgrounds.helpers.LocalStorageHelper;
	import io.newgrounds.models.objects.Response;

	public class MedalUnlockQueue {

		/**
		 * Error codes meaning the call was blocked on identity before this medal
		 * was ever looked at. The gateway hasn't ruled on the medal, so the id
		 * stays buffered. Medal.unlock needs a signed-in player, so a signed-out
		 * unlock is refused locally with 102 or 110, the same as the server would.
		 */
		private static const SESSION_CLASS_ERROR_CODES:Array = [
			Errors.MISSING_PARAMETER,   // 102
			Errors.EXPIRED_SESSION,     // 104
			Errors.LOGIN_REQUIRED,      // 110
			Errors.CANCELLED_SESSION    // 111
		];

		private var core:Core;
		private var storageKey:String;

		/**
		 * Ids out on a live request right now, as id -> true. Lets a retry pass
		 * skip anything already in flight instead of sending it twice.
		 */
		private var inFlight:Object = {};

		/** Told about every retry pass that sent anything, as {listener, thisArg}. */
		private var retryListeners:Array = [];

		/**
		 * Whether an unlock attempted while nobody is signed in is kept and sent
		 * after a later sign-in. When false it is never recorded, and any guest
		 * entry already buffered is dropped instead of sent. Set through
		 * NGIO.keepGuestMedalUnlocks.
		 */
		public var keepGuestUnlocks:Boolean = true;

		/**
		 * Whether guest entries wait for the game to claim or discard them,
		 * instead of going to whoever signs in next. No effect while
		 * keepGuestUnlocks is false. Set through NGIO.holdGuestMedalUnlocks.
		 */
		public var holdGuestUnlocks:Boolean = false;

		public function MedalUnlockQueue(core:Core) {
			this.core = core;
			// Scoped by App ID for the same reason the saved session id is: apps on
			// the same host share their local storage.
			this.storageKey = "ngio-pending-medal-unlocks-for-" + core.appId;
		}

		/** Ids currently waiting on the gateway, for any player. */
		public function getPendingIds():Array {
			var ids:Array = [];
			for each (var entry:Object in readEntries()) {
				if (ids.indexOf(entry.id) == -1) ids.push(entry.id);
			}
			return ids;
		}

		/** Ids recorded while nobody was signed in, and not yet sent or discarded. */
		public function getGuestIds():Array {
			var ids:Array = [];
			for each (var entry:Object in readEntries()) {
				if (entry.user === null && ids.indexOf(entry.id) == -1) ids.push(entry.id);
			}
			return ids;
		}

		/**
		 * Hands guest entries to the signed-in player and sends them. Each is
		 * recorded as that player's before it goes out, so one that can't be sent
		 * yet waits for them like any of their own. Ids with no guest entry are
		 * ignored. With nobody signed in, the callback gets an empty list.
		 *
		 * @param ids Medal ids to claim
		 * @param callback Called as callback(outcomes), the same shape unlock() reports
		 * @param thisArg Context for the callback
		 */
		public function claimGuestUnlocks(ids:Array, callback:Function = null, thisArg:* = null):void {
			var user:* = currentUserId();
			var entries:Array = readEntries();
			var claimed:Array = [];
			for each (var id:* in ids) {
				if (!(id is Number) || claimed.indexOf(id) != -1) continue;
				for each (var entry:Object in entries) {
					if (entry.id == id && entry.user === null) {
						claimed.push(id);
						break;
					}
				}
			}

			if (user === null || claimed.length == 0) {
				if (callback != null) callback.call(thisArg, []);
				return;
			}

			var kept:Array = entries.filter(function(e:Object, index:int, all:Array):Boolean {
				return e.user !== null || claimed.indexOf(e.id) == -1;
			});
			for each (var claimedId:Number in claimed) {
				var owned:Boolean = false;
				for each (var k:Object in kept) {
					if (k.id == claimedId && sameUser(k.user, user)) {
						owned = true;
						break;
					}
				}
				if (!owned) kept.push({id: claimedId, user: user});
			}
			write(kept);

			var toSend:Array = [];
			for each (var sendId:Number in claimed) {
				if (inFlight[sendId] !== true) toSend.push(sendId);
			}
			if (toSend.length == 0) {
				if (callback != null) callback.call(thisArg, []);
				return;
			}
			send(toSend, user, callback, thisArg);
		}

		/** Drops guest entries for these ids without sending them. Players' own entries are untouched. */
		public function discardGuestUnlocks(ids:Array):void {
			var entries:Array = readEntries();
			var kept:Array = entries.filter(function(entry:Object, index:int, all:Array):Boolean {
				return entry.user !== null || ids.indexOf(entry.id) == -1;
			});
			if (kept.length != entries.length) write(kept);
		}

		/**
		 * Unlocks one or more medals, buffering each id before it is sent.
		 *
		 * @param ids Medal ids to unlock
		 * @param callback Called once every id has an answer, as callback(outcomes),
		 *        where each outcome is {id, medal, error, status}. status is a
		 *        MedalUnlockStatus value, and error is null exactly when it's UNLOCKED.
		 * @param thisArg Context for the callback
		 */
		public function unlock(ids:Array, callback:Function = null, thisArg:* = null):void {
			var unique:Array = [];
			for each (var id:* in ids) {
				if (id is Number && unique.indexOf(id) == -1) unique.push(id);
			}
			if (unique.length == 0) {
				if (callback != null) callback.call(thisArg, []);
				return;
			}

			// Buffer BEFORE sending, not after the answer. This is what makes a
			// crash or reload mid-request survivable.
			var user:* = currentUserId();
			if (user !== null || keepGuestUnlocks) {
				addPending(unique, user);
			}

			send(unique, user, callback, thisArg);
		}

		/**
		 * Re-sends what is still buffered for whoever is signed in now: their own
		 * entries and any guest entries, minus anything already in flight. Another
		 * player's entries wait until that player signs in again. With
		 * holdGuestUnlocks on, guest entries wait for claimGuestUnlocks() instead.
		 *
		 * Never throws. A failed pass is exactly the "still can't reach the
		 * gateway" case this exists for, and one bad pass mustn't stop the next.
		 *
		 * @param callback Called as callback(outcomes) once this pass is done, or
		 *        with an empty list when nothing was waiting. Retry listeners hear
		 *        about the pass too, but only when it sent something.
		 * @param thisArg Context for the callback
		 */
		public function retryPending(callback:Function = null, thisArg:* = null):void {
			var pending:Array = [];
			var user:* = null;
			try {
				var entries:Array = readEntries();
				if (!keepGuestUnlocks) {
					var withoutGuests:Array = entries.filter(function(entry:Object, index:int, all:Array):Boolean {
						return entry.user !== null;
					});
					if (withoutGuests.length != entries.length) {
						entries = withoutGuests;
						write(entries);
					}
				}

				user = currentUserId();
				for each (var entry:Object in entries) {
					if ((entry.user === null ? !holdGuestUnlocks : sameUser(entry.user, user))
						&& pending.indexOf(entry.id) == -1 && inFlight[entry.id] !== true) {
						pending.push(entry.id);
					}
				}
			} catch (e:Error) {
				// See above: a retry pass never passes a failure on.
				pending = [];
			}

			if (pending.length == 0) {
				if (callback != null) callback.call(thisArg, []);
				return;
			}
			var self:MedalUnlockQueue = this;
			send(pending, user, function(outcomes:Array):void {
				if (callback != null) callback.call(thisArg, outcomes);
				// A copy, so a listener that removes itself doesn't skip the next one.
				for each (var entry:Object in self.retryListeners.concat()) {
					entry.listener.call(entry.thisArg, outcomes);
				}
			}, null);
		}

		/**
		 * Adds a listener for retry passes: every pass that sent anything, whether
		 * the timer or the game started it, calls listener(outcomes) once all the
		 * answers are in. This is how a game hears that a medal earned offline has
		 * now unlocked. Adding the same listener and thisArg twice does nothing more.
		 */
		public function addRetryListener(listener:Function, thisArg:* = null):void {
			if (retryListenerIndex(listener, thisArg) != -1) return;
			retryListeners.push({listener: listener, thisArg: thisArg});
		}

		/** Removes a listener added with the same listener and thisArg. */
		public function removeRetryListener(listener:Function, thisArg:* = null):void {
			var index:int = retryListenerIndex(listener, thisArg);
			if (index != -1) retryListeners.splice(index, 1);
		}

		//==================== PRIVATE ====================

		/** Sends one Medal.unlock per id on behalf of `user`, settling the buffer as each comes back. */
		private function send(ids:Array, user:*, callback:Function, thisArg:*):void {
			var outcomes:Array = [];
			var remaining:int = ids.length;
			var finish:Function = function(outcome:Object):void {
				outcomes.push(outcome);
				remaining--;
				if (remaining == 0 && callback != null) callback.call(thisArg, outcomes);
			};

			// One request per id rather than one batch: the gateway rules on each
			// medal separately, and Core's component queue belongs to the game, so a
			// retry pass must never drain it.
			for each (var id:Number in ids) {
				sendOne(id, user, finish);
			}
		}

		/**
		 * Sends one id. Its own function so each answer's closure captures its own
		 * id: a closure made inside send()'s loop would share the loop variable.
		 */
		private function sendOne(id:Number, user:*, finish:Function):void {
			var self:MedalUnlockQueue = this;
			inFlight[id] = true;
			core.callComponent("Medal.unlock", {id: id}, function(response:*, callbackParams:* = null):void {
				delete self.inFlight[id];

				var outcome:Object = self.adjudicate(id, response);
				if (outcome.adjudicated) {
					// The gateway ruled on this medal for this player. Retrying can't
					// change that, so drop it whether the answer was yes or no.
					self.removePending(id, user);
				}
				finish({id: outcome.id, medal: outcome.medal, error: outcome.error, status: self.statusFor(outcome, user)});
			});
		}

		/**
		 * Where an answered attempt left the medal. Ruled on: unlocked or rejected.
		 * Not ruled on: whatever the buffer still holds for it. An entry for the
		 * player it was sent for, or a guest entry (a retry pass sends those for
		 * whoever is signed in), means it will be tried again; a guest entry under
		 * holdGuestUnlocks waits for a claim instead.
		 */
		private function statusFor(outcome:Object, user:*):String {
			if (outcome.adjudicated) {
				return outcome.error == null ? MedalUnlockStatus.UNLOCKED : MedalUnlockStatus.REJECTED;
			}
			for each (var entry:Object in readEntries()) {
				if (entry.id == outcome.id && (entry.user === null || sameUser(entry.user, user))) {
					if (entry.user === null && user === null && holdGuestUnlocks) return MedalUnlockStatus.HELD;
					return MedalUnlockStatus.PENDING;
				}
			}
			return MedalUnlockStatus.DROPPED;
		}

		private function retryListenerIndex(listener:Function, thisArg:*):int {
			for (var i:int = 0; i < retryListeners.length; i++) {
				if (retryListeners[i].listener === listener && retryListeners[i].thisArg === thisArg) return i;
			}
			return -1;
		}

		/** The signed-in player's user id, or null when nobody is signed in. */
		private function currentUserId():* {
			if (core.appState == null || core.appState.session == null || core.appState.session.user == null) return null;
			return core.appState.session.user.id;
		}

		private static function sameUser(a:*, b:*):Boolean {
			if (a === null || b === null) return a === null && b === null;
			return a == b;
		}

		/**
		 * Has the gateway ruled on this specific medal? That, not "did it
		 * succeed", decides whether the id can be dropped.
		 *
		 * @return {id, medal, error, adjudicated}
		 */
		private function adjudicate(id:Number, response:*):Object {
			// No response, or callComponent's local failure object: nothing reached
			// the gateway, or nothing came back.
			if (!(response is Response)) {
				return {id: id, medal: null, error: asError(response != null ? response.error : null), adjudicated: false};
			}

			var res:Response = response as Response;
			// The request as a whole was rejected before this medal was considered.
			if (res.success !== true) {
				return {id: id, medal: null, error: asError(res.error), adjudicated: false};
			}

			var result:* = res.getResult();
			if (result == null) {
				return {id: id, medal: null, error: Errors.getError(Errors.INVALID_RESPONSE), adjudicated: false};
			}
			if (result.success === true) {
				return {id: id, medal: result.medal, error: null, adjudicated: true};
			}

			var error:* = (result.error != null) ? result.error : Errors.getError(Errors.INVALID_RESPONSE);
			var code:int = (error.code != null) ? int(error.code) : Errors.UNKNOWN;
			// Anything outside the session class means the gateway looked at this
			// medal and rejected it, 202 (an unknown medal id) above all. That id is
			// dropped and never retried.
			return {id: id, medal: null, error: error, adjudicated: SESSION_CLASS_ERROR_CODES.indexOf(code) == -1};
		}

		private function asError(error:*):* {
			if (error != null && !(error is String)) return error;
			if (error is String) return Errors.getError(Errors.INVALID_RESPONSE, error as String, true);
			return Errors.getError(Errors.INVALID_RESPONSE);
		}

		/**
		 * The stored entries, as {id, user}. A bare number is an entry from before
		 * unlocks recorded their player, and is read as a guest entry.
		 */
		private function readEntries():Array {
			try {
				var raw:String = LocalStorageHelper.getValue(storageKey);
				if (raw == null || raw == "") return [];
				var parsed:* = NGJSON.parse(raw);
				if (!(parsed is Array)) return [];

				var entries:Array = [];
				for each (var item:* in parsed) {
					if (item is Number) {
						entries.push({id: item, user: null});
					} else if (item != null && item.id is Number) {
						entries.push({id: item.id, user: (item.user is Number) ? item.user : null});
					}
				}
				return entries;
			} catch (e:Error) {
				// Unreadable stored data is treated as absent, not fatal.
			}
			return [];
		}

		private function addPending(ids:Array, user:*):void {
			var entries:Array = readEntries();
			for each (var id:Number in ids) {
				var found:Boolean = false;
				for each (var entry:Object in entries) {
					if (entry.id == id && sameUser(entry.user, user)) {
						found = true;
						break;
					}
				}
				if (!found) entries.push({id: id, user: user});
			}
			write(entries);
		}

		/**
		 * Drops `id` for `user`, and any guest entry for it too: a guest unlock
		 * sent after a sign-in is settled for that player.
		 */
		private function removePending(id:Number, user:*):void {
			var entries:Array = readEntries();
			var kept:Array = entries.filter(function(entry:Object, index:int, all:Array):Boolean {
				return entry.id != id || (entry.user !== null && !sameUser(entry.user, user));
			});
			if (kept.length == entries.length) return;
			write(kept);
		}

		private function write(entries:Array):void {
			// Best effort, never fatal: a failed write just means the buffer isn't
			// durable this time.
			try {
				LocalStorageHelper.setValue(storageKey, NGJSON.stringify(entries));
			} catch (e:Error) {
			}
		}
	}
}
