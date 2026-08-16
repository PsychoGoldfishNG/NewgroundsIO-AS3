/**
 * TestUI
 *
 * Wraps the display objects the .fla puts on the stage (infoText, inputButton,
 * inputButtonLabel, and the optional inputButton2 / inputButtonLabel2) so suites
 * can talk to the user without knowing anything about the timeline.
 *
 * Both buttons are typed as InteractiveObject rather than MovieClip on purpose:
 * a symbol dropped on the stage with "Button" behaviour compiles to
 * flash.display.SimpleButton, so `caller["inputButton"] as MovieClip` yields
 * null. InteractiveObject covers SimpleButton, MovieClip and Sprite alike,
 * and is the only common ancestor that still dispatches MouseEvent.CLICK.
 *
 * The second button is OPTIONAL. A .fla without it still runs everything except
 * the tests that need a genuine either/or choice, which check hasButton2 and
 * skip with a reason rather than hanging.
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

        /** The clickable controls. Each may be a SimpleButton or a MovieClip. */
        private var button:InteractiveObject;
        private var button2:InteractiveObject;

        /** Text fields sitting next to/over the buttons, holding their captions */
        private var buttonLabel:TextField;
        private var buttonLabel2:TextField;

        /** Callbacks to fire on the next click, or null when no input is wanted */
        private var pendingHandler:Function = null;
        private var pendingHandler2:Function = null;

        //==================== CONSTRUCTOR ====================

        /**
         * @param button2      Optional. Pass null when the .fla has only one button.
         * @param buttonLabel2 Optional, same.
         */
        public function TestUI(infoText:TextField, button:InteractiveObject, buttonLabel:TextField,
                               button2:InteractiveObject = null, buttonLabel2:TextField = null) {
            this.infoText = infoText;
            this.button = button;
            this.buttonLabel = buttonLabel;
            this.button2 = button2;
            this.buttonLabel2 = buttonLabel2;

            armButton(this.button, this.buttonLabel, onButtonClick);
            armButton(this.button2, this.buttonLabel2, onButton2Click);

            hideButton();
        }

        /**
         * Wire one button and its label to the same click handler.
         *
         * The label sits over the button, and a TextField is an
         * InteractiveObject in its own right - so wherever it overlaps, it eats
         * the click and the button never fires. Listen on the label too, rather
         * than relying on how the .fla configured the field.
         */
        private function armButton(target:InteractiveObject, label:TextField, handler:Function):void {
            if (target != null) {
                target.addEventListener(MouseEvent.CLICK, handler);
                // Sprite/MovieClip need buttonMode to get the hand cursor.
                // SimpleButton has useHandCursor and gets it for free.
                if (target is Sprite) {
                    (target as Sprite).buttonMode = true;
                }
            }

            if (label != null) {
                label.addEventListener(MouseEvent.CLICK, handler);
                label.selectable = false;
                label.mouseWheelEnabled = false;
            }
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
         * Show BOTH buttons and wait for whichever is clicked.
         *
         * Whichever fires, the other is torn down first - hideButton() clears
         * both pending handlers, so a two-way choice cannot fire twice even if
         * the user manages to hit both controls.
         */
        public function showButtons(label:String, handler:Function, label2:String, handler2:Function):void {
            showButton(label, handler);

            pendingHandler2 = handler2;

            if (buttonLabel2 != null) {
                buttonLabel2.text = (label2 != null) ? label2 : "Continue";
                buttonLabel2.visible = true;
            }

            if (button2 != null) {
                button2.visible = true;
                button2.mouseEnabled = true;
            }
        }

        /**
         * Hide both buttons and drop any handlers waiting on them.
         */
        public function hideButton():void {
            pendingHandler = null;
            pendingHandler2 = null;

            if (buttonLabel != null) {
                buttonLabel.visible = false;
            }

            if (button != null) {
                button.visible = false;
                button.mouseEnabled = false;
            }

            if (buttonLabel2 != null) {
                buttonLabel2.visible = false;
            }

            if (button2 != null) {
                button2.visible = false;
                button2.mouseEnabled = false;
            }
        }

        /**
         * True when the stage actually provided a usable button. Suites that need
         * human input check this so they can skip rather than hang forever.
         */
        public function get hasButton():Boolean {
            return (button != null);
        }

        /**
         * True when the stage provided a usable SECOND button.
         *
         * Separate from hasButton because the second one is optional: a .fla
         * carrying only inputButton still runs every single-choice prompt.
         */
        public function get hasButton2():Boolean {
            return (button2 != null);
        }

        //==================== PRIVATE METHODS ====================

        private function onButtonClick(event:MouseEvent):void {
            fire(pendingHandler);
        }

        private function onButton2Click(event:MouseEvent):void {
            fire(pendingHandler2);
        }

        private function fire(handler:Function):void {
            if (handler == null) {
                return;
            }

            // Clear state BEFORE invoking, so the handler can immediately arm
            // another prompt without it being wiped by our own cleanup. This
            // also drops the OTHER pending handler, which is what stops a
            // two-way choice firing twice.
            hideButton();
            handler.call(null);
        }
    }
}
