package {

import flash.events.*;
import flash.geom.Point;
import flash.display.*;
import flash.text.*;
import flash.utils.*;
import flash.ui.Keyboard;
import com.google.maps.*;
import com.google.maps.controls.*;
import com.google.maps.interfaces.IMap;
import com.google.maps.LatLngBounds;
import com.google.maps.overlays.*;

public class Donko extends Sprite {
	private var map:Map;
	private var static_text:Array;
	private var from:TextField;
	private var to:TextField;
	private var button:CustomButton;
	private var debug_text:TextField;
	private var dijkstraAnim:DijkstraAnimation;
	private var myTimer:Timer;
	private var railStationsLine:Object;
	private var nsearch:int;
	private var auto_view:Boolean;
	private var edgelines:Object;

	// 連絡通路の距離（一定）
	private const RenrakuDist:Number = 0.5;		// 仮に一律500mとする

	public function Donko() {
		debug_text = create_static_text(0, 0, 200, 16, "");
		stage.addChild(debug_text);

		stage.scaleMode = StageScaleMode.NO_SCALE;
		stage.align = StageAlign.TOP_LEFT;

		Data.init();

		map = new Map();
		map.version = "map_flex_1_3.swc";
		map.key = "ABQIAAAAYPjOknrO2nVrwswpM6J3shSo_w4dtRuu9MOazvQzIrXefBNXZxQEBXRTuZieD-FSmmswkvaAHqatfw";
		map.setSize(new Point(stage.stageWidth, stage.stageHeight));
		map.addEventListener(MapEvent.MAP_READY, function (event:*):void {
			map.setCenter(new LatLng(35.68295607559028, 139.71725463867188), 12, MapType.NORMAL_MAP_TYPE);
			map.addControl(new MapTypeControl());
			map.addControl(new ZoomControl());
			map.enableScrollWheelZoom();
		});
		map.addEventListener(MapMouseEvent.DOUBLE_CLICK, function (event:MapMouseEvent):void {
			map.setCenter(event.latLng, map.getZoom() + 1);
		});
		map.addEventListener(MapMouseEvent.DRAG_START, function (event:MapMouseEvent):void {
			auto_view = false;
		});
		stage.addEventListener(Event.RESIZE, on_resize);
		addChild(map);

		var y:int = stage.stageHeight - 40;

		static_text = [];
		static_text[0] = create_static_text(100, y, 40, 20, "出発駅");
		stage.addChild(static_text[0]);
		from = create_input_box(140, y, 60, 20);
from.text = "中野";
		stage.addChild(from);
		static_text[1] = create_static_text(210, y, 40, 20, "目的地");
		stage.addChild(static_text[1]);
		to   = create_input_box(250, y, 60, 20);
to.text = "新宿";
		stage.addChild(to);

		from.addEventListener(KeyboardEvent.KEY_DOWN, on_keydown);
		to.addEventListener(KeyboardEvent.KEY_DOWN, on_keydown);

		//ボタンの生成
		button = new CustomButton(320, y, "検索");
		button.addEventListener(MouseEvent.MOUSE_UP, function (ev:MouseEvent):void { on_btn_pressed(); });
		addChild(button);

		button.addEventListener(KeyboardEvent.KEY_DOWN, on_keydown);

		// チェックボックス
//		var cb:CreateCheckBox = new CreateCheckBox(["ノーウェイト"], 400, 450, 20);
//		addChild(cb);

		init_data();
	}

	private function on_resize(event:Event):void {
		map.setSize(new Point(stage.stageWidth, stage.stageHeight));
		var y:int = stage.stageHeight - 40;
		from.y = to.y = button.y = static_text[0].y = static_text[1].y = y;
	}

	private function on_keydown(event:KeyboardEvent):void {
		if (event.keyCode == Keyboard.ENTER) {
			on_btn_pressed();
		}
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


		// デバッグ用：ノードとエッジの数
		var nedge:int = 0;
		for (var k1:String in E) {
			for (var k2:String in E[k1]) {
				nedge += 1;
			}
		}
		var nnode:int = 0;
		for (key in V) {
			nnode += 1;
		}
		trace("#node:" + String(nnode) + ", #edge:" + String(nedge));
	}

	private var bounds: LatLngBounds;

	public static function expand_bounds(bounds: LatLngBounds, pos:LatLng):void {
		bounds.union(new LatLngBounds(pos, pos));
	}

	private function on_btn_pressed():void {
		edgelines = {};
		try {
			map.closeInfoWindow();
			map.clearOverlays();
		} catch (e:*) {		// ??? クリアはできるけど進まなくなる？
//			trace("error:" + String(e));
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

				nsearch = 0;
//				if (true) {
					dijkstraAnim.init(from_key, to_key);

					myTimer = new Timer(1, 0);
					myTimer.addEventListener("timer", on_timer);
					myTimer.start();
/*
				} else {
					var t0:int = getTimer();
					trace("Exec!");
					dijkstraAnim.execute(from_key, to_key, function ():void {
						
					});
					var t1:int = getTimer();
					var d:int = t1 - t0;
					trace(String(d / 1000.0) + " s");

					on_finished();
				}
*/
				auto_view = true;
			}
		}
	}

	private function remove_edge_line(station1id:String, station2id:String):void {
		var station1:Object = Data.Stations[Data.RailStations[station1id]];
		var station2:Object = Data.Stations[Data.RailStations[station2id]];

		var key:String = (station1id < station2id) ? station1id + "," + station2id : station2id + "," + station1id;
		if (edgelines.hasOwnProperty(key)) {
			map.removeOverlay(edgelines[key]);
			edgelines[key] = undefined;
		}
	}

	private function update_edge_line(station1id:String, station2id:String, color:int, alpha:Number):void {
		var station1:Object = Data.Stations[Data.RailStations[station1id]];
		var station2:Object = Data.Stations[Data.RailStations[station2id]];

		var key:String = (station1id < station2id) ? station1id + "," + station2id : station2id + "," + station1id;
		if (edgelines.hasOwnProperty(key)) {
			map.removeOverlay(edgelines[key]);
		}

		var opt:PolylineOptions = new PolylineOptions({strokeStyle: {thickness:3, color: color, alpha:alpha}});
		var polyline:Polyline = new Polyline([new LatLng(station1.lat, station1.lng), new LatLng(station2.lat, station2.lng)], opt);
		map.addOverlay(polyline);
		edgelines[key] = polyline;
	}

	private function on_timer(eventArgs:TimerEvent):void {
		if (!dijkstraAnim.is_end()) {
			dijkstraAnim.step(function(st:String, pre:String, cost:Number, updates:Array):void {
				var station:Object = Data.Stations[Data.RailStations[st]];
				var station2:Object = Data.Stations[Data.RailStations[pre]];

				var pos:LatLng = new LatLng(station.lat, station.lng);
				expand_bounds(bounds, pos);
				if (auto_view) {
					var zoom:Number = map.getBoundsZoomLevel(bounds);
					map.setCenter(bounds.getCenter(), zoom);
				}

				update_edge_line(st, pre, 0xff0000, 1.0);
				updates.forEach(function(elem:Array, index:int, arr:Array):void {
					remove_edge_line(elem[0], elem[1]);
					update_edge_line(st, elem[0], 0x00ff00, 0.5);
				});

				var rail:Object = railStationsLine[st];
				var rail_name:String = rail ? rail.name : "徒歩";
				map.openInfoWindow(pos, new InfoWindowOptions({title: station.name + " (" + rail_name + ")", content: String(cost)}));

				++nsearch;
			});

			if (dijkstraAnim.is_end()) {
				myTimer.stop();
				on_finished();
			}
		}
	}

	private function on_finished():void {
		edgelines = {};
		try {
			map.closeInfoWindow();
			map.clearOverlays();
		} catch (e:*) {		// ??? クリアはできるけど進まなくなる？
//			trace("error:" + String(e));
		}

		var from_key:String = dijkstraAnim.s;
		var to_key:String = dijkstraAnim.z;

		bounds = new LatLngBounds();

		var path_stations:Array = [];

		// 結果を表示
		var predecessor:Object = dijkstraAnim.predecessor;
		var text:String = "";
		var lines:Array = [];
		var points:Array = [];
		var points_array:Array = [];
		var prev_station_id:String;
		var way:String = "";
		for (var p:String = to_key; ; p = predecessor[p]) {
			lines.push(p);
			var station:Object = Data.Stations[Data.RailStations[p]];
			var pos:LatLng = new LatLng(station.lat, station.lng);
			path_stations.unshift(station);
			points.unshift(pos);

			expand_bounds(bounds, pos);

			var line:Object = "";
			if (p != to_key) {
				line = dijkstraAnim.E[prev_station_id][p].line;
				if (line) {
					way = line.name;
				}
			}
			if (p == to_key || p == from_key || !line) {
				map.addOverlay(new Marker(pos, new MarkerOptions({tooltip: station.name + "(" + way + ")"})));
				if (p != to_key) {
					points_array.unshift(points);
					points = [pos];
				}
			}

			if (p == from_key)	break;

			prev_station_id = p;
		}

		const colors:Array = [0xff0000, 0x00ff00, 0x0000ff, 0xff00ff];
		for (var iline:int = 0; iline < points_array.length; ++iline) {
			points = points_array[iline];
			var color:int = colors[iline % colors.length];
			map.addOverlay(new Polyline(points, new PolylineOptions({strokeStyle: {thickness:3, color:color}})));
		}

		var zoom:Number = map.getBoundsZoomLevel(bounds);
		map.setCenter(bounds.getCenter(), zoom);

		trace("#search:" + String(nsearch));
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
	public static function combination(arr:Array, num:int):Array {
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
