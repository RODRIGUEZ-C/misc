package {

import flash.events.*;
import flash.geom.Point;
import flash.display.*;
import flash.text.*;
import com.google.maps.*;
import com.google.maps.controls.*;
import com.google.maps.interfaces.IMap;

public class TokyoMetro extends Sprite {
	private var map:Map;
	private var from:TextField;
	private var to:TextField;
	private var button:CustomButton;
	private var debug_text:TextField;

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

		stage.addChild(create_static_text(100, 450, 40, 20, "出発駅"));
		from = create_input_box(140, 450, 60, 20);
from.text = "練馬";
		stage.addChild(from);
		stage.addChild(create_static_text(210, 450, 40, 20, "目的地"));
		to   = create_input_box(250, 450, 60, 20);
to.text = "新宿";
		stage.addChild(to);

		//ボタンの生成
		button = new CustomButton(320, 450, "検索");
		button.addEventListener(MouseEvent.MOUSE_UP, on_btn_pressed);
		addChild(button);

		debug_text = create_static_text(440, 0, 200, 16, "");
		stage.addChild(debug_text);
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

	private function dijkstra(s:String, z:String):void {
		function arclength(n1:String, n2:String):Number {
			if (E.hasOwnProperty(n1) && E[n1].hasOwnProperty(n2)) {
				return E[n1][n2].cost;
			} else {
				return Number.POSITIVE_INFINITY;
			}
		}
		// 配列中で関数呼び出しの結果が最小となる要素のインデクスを返す
		function min_by_idx(array:Array, f:Function):int {
			var res:int = -1;
			var min:*;
			for (var len:int=array.length, i:int=0; i<len; ++i) {
				var x:* = array[i];
				var t:* = f(x);
				if (res < 0 || min > t) {
					res = i;
					min = t;
				}
			}
			return res;
		}

trace("make graph");
		var V:Object = Data.RailStations;	// ノード
		var E:Object = make_graph_info(Data.Lines, Data.RailStations, Data.Stations);	// エッジ

trace("init");
		var distance:Object = new Object();
		var predecessor:Object = new Object();
		var S:Array = [s];
		var left:Array = [];
		distance[s] = 0;
		for (var v:* in V) {
			if (v != s) {
				distance[v] = arclength(s, v);
				predecessor[v] = s;
				left.push(v);
			}
		}

trace("start");
var loopnum:int = 0;
		for (; left.length > 0;) {
loopnum += 1;
			var v_star_idx:int = min_by_idx(left, function(v:String):Number {return distance[v];});
			var v_star:String = left[v_star_idx];
			S.push(v_star);
			if (v_star == z)	break;

			left = left.filter(function(elem:*, index:int, arr:Array):Boolean {return elem != v_star;});
			for (var len:int=left.length, i:int=0; i<len; ++i) {
				v = left[i];
				var dist:Number = arclength(v_star, v);
				var d:Number = distance[v_star] + dist;
				if (d < distance[v]) {
					distance[v] = d;
					predecessor[v] = v_star;
				}
			}
		}

trace("end");

		if (v_star == z) {
			var t:String = String(loopnum) + ":";
			for (var p:String = z; (p = predecessor[p]) != s; ) {
				t += Data.Stations[Data.RailStations[p]].name + ",";
			}
			trace(t);
		}
	}

	// 路線情報からグラフを生成
	private function make_graph_info(lines:*, rail_stations:*, stations:*):Object {
		function add2graph(graph:*, rsi1:*, rsi2:*, v:*):void {
			if (!graph.hasOwnProperty(rsi1))		graph[rsi1] = {};
//			if (!graph[rsi1].hasOwnProperty(rsi2))	graph[rsi1][rsi2] = {};
			graph[rsi1][rsi2] = v;
		}
		function add_edge(rail_stations:*, stations:*, rsi1:*, rsi2:*, line:*, cost:Number):void {
			var join_info:* = { "cost": cost, "line": line };
			add2graph(graph, rsi1, rsi2, join_info);
			add2graph(graph, rsi2, rsi1, join_info);
		}

		var graph:Object = {};
	
		// 路線の接続情報
		for (var k:* in lines) {
			var joins:* = lines[k].joins;
			for (var i:int=0; i<joins.length; ++i) {
				var join:Object = joins[i];
				add_edge(rail_stations, stations, join.rsi1, join.rsi2, lines[k], join.cost);
			}
		}

/*
		// 乗り継ぎ：同じ駅で別路線
		var same_stations:Object = {};
		for (var k in rail_stations) {
			var station = rail_stations[k];
			if (!same_stations[station]) {
				same_stations[station] = [];
			}
			same_stations[station].push(k);
		}
		var line:* = undefined;
		for (var k in same_stations) {
			var s = same_stations[k];
			s.combination(2).each(function(a){
				var rsi1 = a[0];
				var rsi2 = a[1];
				var cost = RenrakuDist;
				add_edge(rail_stations, stations, rsi1, rsi2, line, cost);
			});
		}
*/
		return graph;
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
