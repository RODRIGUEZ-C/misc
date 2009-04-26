package {

import flash.events.Event;
import flash.events.MouseEvent;
import flash.geom.Point;
import flash.display.DisplayObject;
import flash.display.Sprite;
import flash.display.Shape;
import flash.text.*;
import com.google.maps.*;
import com.google.maps.controls.*;
import com.google.maps.interfaces.IMap;

public class TokyoMetro extends Sprite {
	private var map:Map;
	private var from:TextField;
	private var to:TextField;
	private var button:CustomButton;

	public function TokyoMetro() {
		map = new Map();
		map.version = "map_flex_1_3.swc";
		map.key = "ABQIAAAAYPjOknrO2nVrwswpM6J3shSo_w4dtRuu9MOazvQzIrXefBNXZxQEBXRTuZieD-FSmmswkvaAHqatfw";
		map.setSize(new Point(640, 480));
		map.addEventListener(MapEvent.MAP_READY, function (event:*):void {
			map.setCenter(new LatLng(35.68295607559028, 139.71725463867188), 12, MapType.NORMAL_MAP_TYPE);
			map.addControl(new MapTypeControl());
			map.addControl(new ZoomControl());
		});
		addChild(map);

		create_static_text(100, 450, 40, 20, "出発駅");
		from = create_input_box(140, 450, 60, 20);
		create_static_text(210, 450, 40, 20, "目的地");
		to   = create_input_box(250, 450, 60, 20);

		//ボタンの生成
		button = new CustomButton(320, 450, "検索");
		button.addEventListener(MouseEvent.MOUSE_UP, on_btn_pressed);
		addChild(button);
	}

	private function on_btn_pressed(ev:MouseEvent):void {
		map.closeInfoWindow();
		var from_key:String = search_station(from.text);
		if (from_key == "") {
			map.openInfoWindow(map.getCenter(), new InfoWindowOptions({title: from.text, content: "出発駅が見つかりません"}));
		} else {
			var to_key:String = search_station(to.text);
			if (to_key == "") {
				map.openInfoWindow(map.getCenter(), new InfoWindowOptions({title: to.text, content: "目的地が見つかりません"}));
			} else {
				dijkstra(from_key, to_key);
			}
		}
	}

	private function dijkstra(from:String, to:String):void {
		
	}

	private function search_station(name:String):String {
		for (var key: String in Data.Stations) {
			var val:* = Data.Stations[key];
			if (val.name == name) {
				return key;
			}
		}
		return "";
	}

	private function create_input_box(x:int, y:int, w:int, h:int):TextField {
		var edit:TextField = new TextField();
		edit.border = true;
		edit.x = x;
		edit.y = y;
		edit.width  = w;
		edit.height = h;
		edit.type = TextFieldType.INPUT;
		edit.background = true;
		stage.addChild(edit);
		return edit;
	}

	private function create_static_text(x:int, y:int, w:int, h:int, str:String):TextField {
		var text:TextField = new TextField();
		text.border = true;
		text.x = x;
		text.y = y;
		text.width  = w;
		text.height = h;
		text.background = true;
		text.text = str;
		stage.addChild(text);
		return text;
	}
}
//
}
