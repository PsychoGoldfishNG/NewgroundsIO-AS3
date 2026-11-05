/**
 * MedalUnlockStatus
 *
 * Where an unlock attempt left the medal. Every outcome MedalUnlockQueue
 * reports has one, as outcome.status. error is null exactly when the status is
 * UNLOCKED.
 */
package io.newgrounds {

	public class MedalUnlockStatus {

		/** The gateway unlocked it. */
		public static const UNLOCKED:String = "unlocked";

		/** The gateway ruled on this medal and refused it (202 above all). It isn't retried. */
		public static const REJECTED:String = "rejected";

		/** Not ruled on yet, and still buffered: a retry pass will send it again. */
		public static const PENDING:String = "pending";

		/** Earned while nobody was signed in, and buffered until the game claims or
		 * discards it (NGIO.holdGuestMedalUnlocks). */
		public static const HELD:String = "held";

		/** Not ruled on, and not buffered either: a guest unlock with
		 * NGIO.keepGuestMedalUnlocks off. Nothing will send it again. */
		public static const DROPPED:String = "dropped";
	}
}
