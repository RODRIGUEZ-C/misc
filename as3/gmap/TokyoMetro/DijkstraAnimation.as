package {

import flash.events.*;
import flash.geom.Point;
import flash.display.*;
import flash.text.*;

public class DijkstraAnimation {
	public var V:Object;				// ノード
	public var E:Object;				// エッジ

	private var b_end:Boolean;			// 終了した？
	public var s:String;				// 開始駅
	public var z:String;				// 終着駅

	public var distance:Object;			// 距離（移動コスト）
	public var predecessor:Object;		// エッジ
	private var S:Array;				// 確定したノード
	private var left:Array;				// 未確定のノード
	private var left_flag:Object;		// 未確定のノード

	public function DijkstraAnimation(V_:Object, E_:Object) {
		V = V_;
		E = E_;
		b_end = true;
	}

	public function is_end():Boolean { return b_end; }

	public function execute(from:String, to:String, f:Function):void {
		init(from, to);
		while (!b_end) {
			step(undefined);
		}
	}

	public function init(from:String, to:String):void {
		b_end = false;
		s = from;
		z = to;

		distance = new Object();
		predecessor = new Object();
		S = [s];
		left = [];
		left_flag = {}
		distance[s] = 0;
		left_flag[s] = false;
		for (var v:* in V) {
			if (v != s) {
				distance[v] = arclength(s, v);
				predecessor[v] = s;
				left.push(v);
				left_flag[v] = true;
			}
		}
	}

	public function step(f:Function):void {
		if (!b_end) {
			var v_star_idx:int = min_by_idx(left, function(v:String):Number {return v != "" ? distance[v] : Number.POSITIVE_INFINITY;});
			var v_star:String = left[v_star_idx];
			if (f != undefined) f(v_star, predecessor[v_star], distance[v_star]);
			S.push(v_star);
			if (v_star == z) {
				b_end = true;
				return;
			}

			left[v_star_idx] = "";
			left_flag[v] = false;
			for (var key:String in E[v_star]) {
				var v:String = key;
				if (left_flag[v]) {
					var dist:Number = arclength(v_star, v);
					var d:Number = distance[v_star] + dist;
					if (d < distance[v]) {
						distance[v] = d;
						predecessor[v] = v_star;
					}
				}
			}
		}
	}

	private function result():void {
		var t:String = "";
		for (var p:String = z; (p = predecessor[p]) != s; ) {
			t += Data.Stations[Data.RailStations[p]].name + ",";
		}
		trace(t);
	}

	private function arclength(n1:String, n2:String):Number {
		if (E.hasOwnProperty(n1) && E[n1].hasOwnProperty(n2)) {
			return E[n1][n2].cost;
		} else {
			return Number.POSITIVE_INFINITY;
		}
	}

	// 配列中で関数呼び出しの結果が最小となる要素のインデクスを返す
	private static function min_by_idx(array:Array, f:Function):int {
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
}
//
}
