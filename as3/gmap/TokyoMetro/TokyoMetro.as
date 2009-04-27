package {

import flash.events.*;
import flash.geom.Point;
import flash.display.*;
import flash.text.*;
import flash.utils.Timer;
import com.google.maps.*;
import com.google.maps.controls.*;
import com.google.maps.interfaces.IMap;
import com.google.maps.LatLngBounds;
import com.google.maps.overlays.*;

public class TokyoMetro extends Sprite {
	private var map:Map;
	private var from:TextField;
	private var to:TextField;
	private var button:CustomButton;
	private var debug_text:TextField;
	private var dijkstraAnim:DijkstraAnimation;
	private var myTimer:Timer;
	private var railStationsLine:Object;

	// 連絡通路の距離（一定）
	private const RenrakuDist:Number = 0.1;		// 仮に一律100mとする

	public function TokyoMetro() {
		debug_text = create_static_text(440, 0, 200, 16, "");
		stage.addChild(debug_text);

		Data.init();

		map = new Map();
		map.version = "map_flex_1_3.swc";
		map.key = "ABQIAAAAYPjOknrO2nVrwswpM6J3shSo_w4dtRuu9MOazvQzIrXefBNXZxQEBXRTuZieD-FSmmswkvaAHqatfw";
		map.setSize(new Point(640, 480));
		map.addEventListener(MapEvent.MAP_READY, function (event:*):void {
			map.setCenter(new LatLng(35.68295607559028, 139.71725463867188), 12, MapType.NORMAL_MAP_TYPE);
			map.addControl(new MapTypeControl());
			map.addControl(new ZoomControl());
//			map.setDoubleClickMode(MapAction.ACTION_PAN_ZOOM_IN);
			map.enableScrollWheelZoom();
		});
		addChild(map);

		stage.addChild(create_static_text(100, 450, 40, 20, "出発駅"));
		from = create_input_box(140, 450, 60, 20);
from.text = "浅草";
		stage.addChild(from);
		stage.addChild(create_static_text(210, 450, 40, 20, "目的地"));
		to   = create_input_box(250, 450, 60, 20);
to.text = "中野坂上";
		stage.addChild(to);

		//ボタンの生成
		button = new CustomButton(320, 450, "検索");
		button.addEventListener(MouseEvent.MOUSE_UP, on_btn_pressed);
		addChild(button);

		init_data();
	}

	private function init_data():void {
		var V:Object = {};
		var E:Object = {};

		// ノードの作成
		for (var key:String in Data.RailStations) {
			var station_id:String = Data.RailStations[key];
			V[key] = Data.Stations[station_id];
		}

		// エッジの作成
		E = make_graph_info(Data.Lines, Data.RailStations, Data.Stations);

		// レール駅IDと線の対応付け
		railStationsLine = {}
		for (key in Data.Lines) {
			var line:Object = Data.Lines[key];
			var joins:Object = line.joins;
			for (var i:int=0; i<joins.length; ++i) {
				var join:Object = joins[i];
				railStationsLine[join.rsi1] = line;
				railStationsLine[join.rsi2] = line;
			}
		}

		dijkstraAnim = new DijkstraAnimation(V, E);
	}

	private var bounds: LatLngBounds;

	public static function expand_bounds(bounds: LatLngBounds, pos:LatLng):void {
		bounds.union(new LatLngBounds(pos, pos));
	}

	private function on_btn_pressed(ev:MouseEvent):void {
		map.closeInfoWindow();
		try {
			map.clearOverlays();
		} catch (e:*) {		// ??? クリアはできるけど進まなくなる？
			trace("error:" + String(e));
		}
		if (myTimer) {
			myTimer.stop();
		}

		var from_key:String = search_station(from.text);
		if (from_key == "") {
			map.openInfoWindow(map.getCenter(), new InfoWindowOptions({title: from.text, content: "出発駅が見つかりません"}));
		} else {
			var to_key:String = search_station(to.text);
			if (to_key == "") {
				map.openInfoWindow(map.getCenter(), new InfoWindowOptions({title: to.text, content: "目的地が見つかりません"}));
			} else {
				dijkstraAnim.init(from_key, to_key);

				var station:Object = Data.Stations[Data.RailStations[from_key]];
				var station2:Object = Data.Stations[Data.RailStations[to_key]];
				var pos:LatLng = new LatLng(station.lat, station.lng);
				var pos2:LatLng = new LatLng(station2.lat, station2.lng);
				bounds = new LatLngBounds();
				expand_bounds(bounds, pos);
				expand_bounds(bounds, pos2);
				map.addOverlay(new Marker(pos));
				map.addOverlay(new Marker(pos2));

				var zoom:Number = map.getBoundsZoomLevel(bounds);
				map.setCenter(bounds.getCenter(), zoom);

				myTimer = new Timer(1, 0);
				myTimer.addEventListener("timer", onTimer);
				myTimer.start();
			}
		}
	}

	private function onTimer(eventArgs:TimerEvent):void {
		if (!dijkstraAnim.is_end()) {
			dijkstraAnim.step(function(st:String, pre:String, cost:Number):void {
				var station:Object = Data.Stations[Data.RailStations[st]];
				var station2:Object = Data.Stations[Data.RailStations[pre]];

				var pos:LatLng = new LatLng(station.lat, station.lng);
				expand_bounds(bounds, pos);
				var zoom:Number = map.getBoundsZoomLevel(bounds);
				map.setCenter(bounds.getCenter(), zoom);

/*
				var opt:PolylineOptions = new PolylineOptions({strokeStyle: {thickness:3, color: 0xFF0000, alpha:0.5}});
				var polyline:Polyline = new Polyline([pos, new LatLng(station2.lat, station2.lng)], opt);
				map.addOverlay(polyline);
*/

				var rail:Object = railStationsLine[st];
				var rail_name:String = rail ? rail.name : "徒歩";
				map.openInfoWindow(pos, new InfoWindowOptions({title: station.name + " (" + rail_name + ")", content: String(cost)}));
			});

			if (dijkstraAnim.is_end()) {
				myTimer.stop();
			}
		}
	}

	// 路線情報からグラフを生成
	private function make_graph_info(lines:*, rail_stations:*, stations:*):Object {
		function add2graph(graph:*, rsi1:*, rsi2:*, v:*):void {
			if (!graph.hasOwnProperty(rsi1))		graph[rsi1] = {};
			graph[rsi1][rsi2] = v;
		}
		function add_edge(rail_stations:*, stations:*, rsi1:*, rsi2:*, line:*, cost:Number):void {
			var join_info:* = { "cost": cost, "line": line };
			add2graph(graph, rsi1, rsi2, join_info);
			add2graph(graph, rsi2, rsi1, join_info);
		}

		var graph:Object = {};

		// 路線の接続情報
		for (var k:String in lines) {
			var joins:* = lines[k].joins;
			for (var i:int=0; i<joins.length; ++i) {
				var join:Object = joins[i];
				add_edge(rail_stations, stations, join.rsi1, join.rsi2, lines[k], join.cost);
			}
		}

		// 乗り継ぎ：同じ駅で別路線
		var same_stations:Object = {};
		for (k in rail_stations) {
			var station:Object = rail_stations[k];
			if (!same_stations[station]) {
				same_stations[station] = [];
			}
			same_stations[station].push(k);
		}
		var line:* = undefined;
		for (k in same_stations) {
			var s:Array = same_stations[k];
			combination(s, 2).forEach(function(a:Array, index:int, arr:Array):void {
				var rsi1:String = a[0];
				var rsi2:String = a[1];
				var cost:Number = RenrakuDist;
				add_edge(rail_stations, stations, rsi1, rsi2, line, cost);
			});
		}
		return graph;
	}

	// 組み合わせ
	public function combination(arr:Array, num:int):Array {
		if (num < 1 || num > arr.length) {
			return [];
		} else if (num == 1) {
			return arr.map(function(elem:*, index:int, arr2:Array):Array {return [elem];});
		} else {
			var tmp:Array = ([]).concat(arr);
			var res:Array = [];
			for (var i:int=0; i<arr.length - (num - 1); ++i) {
				var va:Array = [tmp.shift()];
				res = res.concat(combination(tmp, num-1).map( function(elem:*, index:int, arr2:Array):Array {return va.concat(elem);} ));
			}
			return res;
		}
	}

	private function trace(str:String):void {
		debug_text.text = str;
	}

	private static function search_station(name:String):String {
		for (var key: String in Data.RailStations) {
			var station_id:String = Data.RailStations[key];
			if (Data.Stations[station_id].name == name) {
				return key;
			}
		}
		return "";
	}

	private static function create_input_box(x:int, y:int, w:int, h:int):TextField {
		var edit:TextField = new TextField();
		edit.border = true;
		edit.x = x;
		edit.y = y;
		edit.width  = w;
		edit.height = h;
		edit.type = TextFieldType.INPUT;
		edit.background = true;
		return edit;
	}

	private static function create_static_text(x:int, y:int, w:int, h:int, str:String):TextField {
		var text:TextField = new TextField();
		text.border = true;
		text.x = x;
		text.y = y;
		text.width  = w;
		text.height = h;
		text.background = true;
		text.text = str;
		return text;
	}
}
//
}
