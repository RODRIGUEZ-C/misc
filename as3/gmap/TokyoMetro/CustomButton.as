package {
	import flash.display.*;
	import flash.system.*;
	import flash.text.*;

	//カスタムボタン
	public class CustomButton extends SimpleButton {

		//コンストラクタ
		public function CustomButton(x_:int, y_:int, label:String="") {
			//ボタンスプライト
			var downSprite:Sprite=makeSprite(label,true);
			var upSprite  :Sprite=makeSprite(label,false);

			//状態
			downState   =downSprite;
			overState   =upSprite;
			upState     =upSprite;
			hitTestState=upSprite;

			x = x_; y = y_;
		}

		//スプライトの生成
		private function makeSprite(text:String,downFlag:Boolean):Sprite {
			//スプライト
			var sp:Sprite=new Sprite();

			//ラベル
			var label:TextField=new TextField();
			label.text=text;
			label.autoSize=TextFieldAutoSize.CENTER;
			label.selectable=false;

			//シェイプ
			var w:int=label.textWidth+24;
			sp.addChild(makeRect(0,0,w-1,22-1,0xC0C0C0));
			if (downFlag) {
				sp.addChild(makeLine(0,0,w-1,0,0x000000));
				sp.addChild(makeLine(0,1,w-2,1,0x000000));
				sp.addChild(makeLine(0,2,w-3,2,0x808080));
				sp.addChild(makeLine(0,21,w-1,21,0x000000));
				sp.addChild(makeLine(0,20,w-2,20,0xEEEEEE));
				sp.addChild(makeLine(0,0,0,22,0x000000));
				sp.addChild(makeLine(1,0,1,22-2,0x000000));
				sp.addChild(makeLine(2,2,2,22-3,0x808080));
				sp.addChild(makeLine(w-1,0,w-1,22,0x000000));
				sp.addChild(makeLine(w-2,1,w-2,20,0xEEEEEE));
			} else {
				sp.addChild(makeLine(0,0,w-1,0,0xEEEEEE));
				sp.addChild(makeLine(0,21,w-1,21,0x000000));
				sp.addChild(makeLine(1,20,w-2,20,0x808080));
				sp.addChild(makeLine(0,0,0,21,0xEEEEEE));
				sp.addChild(makeLine(w-1,0,w-1,22,0x000000));
				sp.addChild(makeLine(w-2,1,w-2,21,0x808080));
			}
			label.x=(w-label.textWidth)/2-(label.width -label.textWidth)/2;
			label.y=(22-label.textHeight)/2-(label.height-label.textHeight)/2;
			sp.addChild(label);
			
			//フォーマット
			var format:TextFormat=new TextFormat();
			format.font="_等幅";
			format.size=12*Capabilities.screenDPI/72;
			label.setTextFormat(format);
			return sp;
		}

		//ラインの生成
		private function makeLine(x0:Number,y0:Number,x1:Number,y1:Number,color:int):Shape {
			var line:Shape=new Shape();
			line.graphics.lineStyle(1,color);
			line.graphics.moveTo(x0,y0);
			line.graphics.lineTo(x1,y1);
			return line;
		}

		//矩形の生成
		public function makeRect(x:Number,y:Number,w:Number,h:Number,color:int):Shape {
			var rect:Shape=new Shape();
			rect.graphics.beginFill(color);
			rect.graphics.drawRect(x,y,w,h);
			rect.graphics.endFill();
			return rect;
		}
	}
}
