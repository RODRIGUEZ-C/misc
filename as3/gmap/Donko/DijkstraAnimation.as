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
	private var nleft:int;				// 未確定のノードの数
	private var left_flag:Object;		// 未確定のノード

	public function DijkstraAnimation(V_:Object, E_:Object) {
		V = V_;
		E = E_;
		b_end = true;
	}

	public function is_end():Boolean { return b_end; }

	public function execute(from:String, to:String, f:Function):void {
		function nullcb(st:String, pre:String, cost:Number, updates:Array):void {}

		init(from, to);
		while (!b_end) {
			step(nullcb);
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
		nleft = 0;
		left_flag = {}
		distance[s] = 0;
		left_flag[s] = false;
		for (var v:* in V) {
			if (v != s) {
				distance[v] = arclength(s, v);
				predecessor[v] = s;
				left.push(v);
				++nleft;
				left_flag[v] = true;
			}
		}
	}

	public function step(f:Function):void {
		if (!b_end) {
			var v_star_idx:int = min_by_idx(left, nleft, function(v:String):Number {return v != "" ? distance[v] : Number.POSITIVE_INFINITY;});
			var v_star:String = left[v_star_idx];
			S.push(v_star);
			if (v_star == z) {
				f(v_star, predecessor[v_star], distance[v_star], []);
				b_end = true;
				return;
			}

			// v* を未確定の要素から取り除く
			var updates:Array = [];
			--nleft;
			left[v_star_idx] = left[nleft];
			left[nleft] = v_star;
			left_flag[v_star] = false;
			for (var key:String in E[v_star]) {
				var v:String = key;
				if (left_flag[v]) {
					var dist:Number = arclength(v_star, v);
					var d:Number = distance[v_star] + dist;
					if (d < distance[v]) {
						updates.push([v, predecessor[v]]);
						distance[v] = d;
						predecessor[v] = v_star;
					}
				}
			}

			f(v_star, predecessor[v_star], distance[v_star], updates);
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
	private static function min_by_idx(array:Array, n:int, f:Function):int {
		var res:int = -1;
		var min:Number;
		for (var i:int=0; i<n; ++i) {
			var x:* = array[i];
			var t:Number = f(x);
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
