/**
 * TestUI
 *
 * Wraps the three display objects the .fla puts on the stage (infoText,
 * inputButton, inputButtonLabel) so suites can talk to the user without
 * knowing anything about the timeline.
 *
 * The button is typed as InteractiveObject rather than MovieClip on purpose:
 * a symbol dropped on the stage with "Button" behaviour compiles to
 * flash.display.SimpleButton, so `caller["inputButton"] as MovieClip` yields
 * null. InteractiveObject covers SimpleButton, MovieClip and Sprite alike,
 * and is the only common ancestor that still dispatches MouseEvent.CLICK.
 */
package ngiotest {

    import flash.display.DisplayObject;
    import flash.display.InteractiveObject;
    import flash.display.Sprite;
    import flash.events.MouseEvent;
    import flash.text.TextField;

    public class TestUI {

        //==================== PROPERTIES ====================

        /** Multiline field used to tell the user what is happening / what to do */
        private var infoText:TextField;

        /** The clickable control. May be a SimpleButton or a MovieClip. */
        private var button:InteractiveObject;

        /** Text field sitting next to/over the button, holding its caption */
        private var buttonLabel:TextField;

        /** Callback to fire on the next click, or null when no input is wanted */
        private var pendingHandler:Function = null;

        //==================== CONSTRUCTOR ====================

        public function TestUI(infoText:TextField, button:InteractiveObject, buttonLabel:TextField) {
            this.infoText = infoText;
            this.button = button;
            this.buttonLabel = buttonLabel;

            if (this.button != null) {
                this.button.addEventListener(MouseEvent.CLICK, onButtonClick);
                // Sprite/MovieClip need buttonMode to get the hand cursor.
                // SimpleButton has useHandCursor and gets it for free.
                if (this.button is Sprite) {
                    (this.button as Sprite).buttonMode = true;
                }
            }

            // The label sits over the button, and a TextField is an
            // InteractiveObject in its own right - so wherever it overlaps, it
            // eats the click and the button never fires. Listen on the label
            // too, rather than relying on how the .fla configured the field.
            if (this.buttonLabel != null) {
                this.buttonLabel.addEventListener(MouseEvent.CLICK, onButtonClick);
                this.buttonLabel.selectable = false;
                this.buttonLabel.mouseWheelEnabled = false;
            }

            hideButton();
        }

        //==================== PUBLIC METHODS ====================

        /**
         * Replace the informational text shown to the user.
         */
        public function setInfo(message:String):void {
            if (infoText != null) {
                infoText.text = (message != null) ? message : "";
            }
        }

        /**
         * Show the button with a caption and wait for a click.
         *
         * @param label   Caption to display on/next to the button
         * @param handler Called once, on the next click. Cleared before it fires,
         *                so a handler is free to call showButton() again.
         */
        public function showButton(label:String, handler:Function):void {
            pendingHandler = handler;

            if (buttonLabel != null) {
                buttonLabel.text = (label != null) ? label : "Continue";
                buttonLabel.visible = true;
            }

            if (button != null) {
                button.visible = true;
                button.mouseEnabled = true;
            }
        }

        /**
         * Hide the button and drop any handler waiting on it.
         */
        public function hideButton():void {
            pendingHandler = null;

            if (buttonLabel != null) {
                buttonLabel.visible = false;
            }

            if (button != null) {
                button.visible = false;
                button.mouseEnabled = false;
            }
        }

        /**
         * True when the stage actually provided a usable button. Suites that need
         * human input check this so they can skip rather than hang forever.
         */
        public function get hasButton():Boolean {
            return (button != null);
        }

        //==================== PRIVATE METHODS ====================

        private function onButtonClick(event:MouseEvent):void {
            if (pendingHandler == null) {
                return;
            }

            // Clear state BEFORE invoking, so the handler can immediately arm
            // another prompt without it being wiped by our own cleanup.
            var handler:Function = pendingHandler;
            hideButton();
            handler.call(null);
        }
    }
}
