/**
 * TestRunnerStandalone
 *
 * A second entry point for the same test suite, for people who would rather
 * compile with the Flex SDK than open the .fla. See build-tests.ps1.
 *
 * The .fla supplies infoText / inputButton / inputButtonLabel from its stage;
 * this class builds equivalents in code and hands them to the same
 * initiator.NgioUnitTest that the .fla uses, so both routes run identical
 * tests. Output goes to trace() either way - in a standalone SWF that means the
 * debug player's flashlog.txt, so the on-screen text is a mirror of the last
 * status message rather than the full report.
 */
package {

    import flash.display.Sprite;
    import flash.display.StageAlign;
    import flash.display.StageScaleMode;
    import flash.events.Event;
    import flash.text.TextField;
    import flash.text.TextFieldAutoSize;
    import flash.text.TextFormat;

    import initiator.NgioUnitTest;

    public class TestRunnerStandalone extends Sprite {

        private static const MARGIN:Number = 16;
        private static const BUTTON_WIDTH:Number = 260;
        private static const BUTTON_HEIGHT:Number = 32;

        private var infoText:TextField;
        private var inputButton:Sprite;
        private var inputButtonLabel:TextField;
        private var inputButton2:Sprite;
        private var inputButtonLabel2:TextField;

        public function TestRunnerStandalone() {
            if (stage != null) {
                start();
            } else {
                addEventListener(Event.ADDED_TO_STAGE, onAddedToStage);
            }
        }

        private function onAddedToStage(event:Event):void {
            removeEventListener(Event.ADDED_TO_STAGE, onAddedToStage);
            start();
        }

        private function start():void {
            stage.align = StageAlign.TOP_LEFT;
            stage.scaleMode = StageScaleMode.NO_SCALE;

            buildInterface();

            // Same constructor the .fla path ends up calling
            NgioUnitTest.instance = new NgioUnitTest(infoText, inputButton, inputButtonLabel,
                                                     inputButton2, inputButtonLabel2);
        }

        //==================== INTERFACE ====================

        private function buildInterface():void {
            var body:TextFormat = new TextFormat("_sans", 13, 0x222222);
            var buttonY:Number = stage.stageHeight - BUTTON_HEIGHT - MARGIN;

            infoText = new TextField();
            infoText.x = MARGIN;
            infoText.y = MARGIN;
            infoText.width = stage.stageWidth - (MARGIN * 2);
            infoText.height = stage.stageHeight - BUTTON_HEIGHT - (MARGIN * 3);
            infoText.multiline = true;
            infoText.wordWrap = true;
            infoText.selectable = false;
            infoText.border = true;
            infoText.borderColor = 0xBBBBBB;
            infoText.background = true;
            infoText.backgroundColor = 0xFFFFFF;
            infoText.defaultTextFormat = body;
            addChild(infoText);

            inputButton = makeButton("inputButton", MARGIN, buttonY, 0xF08020);
            inputButtonLabel = makeButtonLabel(inputButton);

            // The second button is optional on a .fla stage, but the standalone
            // build draws its own interface - so it may as well supply one, and
            // run the either/or prompts the .fla path would skip.
            inputButton2 = makeButton("inputButton2", MARGIN + BUTTON_WIDTH + MARGIN, buttonY, 0x5A6B7C);
            inputButtonLabel2 = makeButtonLabel(inputButton2);
        }

        private function makeButton(name:String, x:Number, y:Number, colour:uint):Sprite {
            var button:Sprite = new Sprite();
            button.name = name;
            button.x = x;
            button.y = y;
            button.buttonMode = true;
            button.useHandCursor = true;
            button.graphics.beginFill(colour);
            button.graphics.drawRoundRect(0, 0, BUTTON_WIDTH, BUTTON_HEIGHT, 8, 8);
            button.graphics.endFill();
            addChild(button);
            return button;
        }

        private function makeButtonLabel(button:Sprite):TextField {
            var label:TextField = new TextField();
            label.x = button.x;
            label.y = button.y + 7;
            label.width = BUTTON_WIDTH;
            label.height = BUTTON_HEIGHT;
            label.selectable = false;
            // The label sits over the button, so it must not eat the click
            label.mouseEnabled = false;
            label.autoSize = TextFieldAutoSize.NONE;
            label.defaultTextFormat = new TextFormat("_sans", 13, 0xFFFFFF, true, null, null, null, null, "center");
            addChild(label);
            return label;
        }
    }
}
