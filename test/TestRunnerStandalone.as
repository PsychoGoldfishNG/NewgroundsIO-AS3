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
            NgioUnitTest.instance = new NgioUnitTest(infoText, inputButton, inputButtonLabel);
        }

        //==================== INTERFACE ====================

        private function buildInterface():void {
            var body:TextFormat = new TextFormat("_sans", 13, 0x222222);

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

            inputButton = new Sprite();
            inputButton.name = "inputButton";
            inputButton.x = MARGIN;
            inputButton.y = stage.stageHeight - BUTTON_HEIGHT - MARGIN;
            inputButton.buttonMode = true;
            inputButton.useHandCursor = true;
            inputButton.graphics.beginFill(0xF08020);
            inputButton.graphics.drawRoundRect(0, 0, BUTTON_WIDTH, BUTTON_HEIGHT, 8, 8);
            inputButton.graphics.endFill();
            addChild(inputButton);

            inputButtonLabel = new TextField();
            inputButtonLabel.x = inputButton.x;
            inputButtonLabel.y = inputButton.y + 7;
            inputButtonLabel.width = BUTTON_WIDTH;
            inputButtonLabel.height = BUTTON_HEIGHT;
            inputButtonLabel.selectable = false;
            // The label sits over the button, so it must not eat the click
            inputButtonLabel.mouseEnabled = false;
            inputButtonLabel.autoSize = TextFieldAutoSize.NONE;
            inputButtonLabel.defaultTextFormat = new TextFormat("_sans", 13, 0xFFFFFF, true, null, null, null, null, "center");
            addChild(inputButtonLabel);
        }
    }
}
