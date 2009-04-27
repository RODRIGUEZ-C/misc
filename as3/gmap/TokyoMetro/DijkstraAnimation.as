package {

import flash.events.*;
import flash.geom.Point;
import flash.display.*;
import flash.text.*;

public class DijkstraAnimation {
	private var V:Object;
	private var E:Object;

	private var b_end:Boolean;
	private var s:String;
	private var z:String;

	private var distance:Object;
	private var predecessor:Object;
	private var S:Array;
	private var left:Array;

	public function DijkstraAnimation(V_:Object, E_:Object) {
		V = V_;
		E = E_;
		b_end = true;
	}

	public function is_end():Boolean { return b_end; }

	public function init(from:String, to:String):void {
		b_end = false;
		s = from;
		z = to;

		distance = new Object();
		predecessor = new Object();
		S = [s];
		left = [];
		distance[s] = 0;
		for (var v:* in V) {
			if (v != s) {
				distance[v] = arclength(s, v);
				predecessor[v] = s;
				left.push(v);
			}
		}
	}

	public function step(f:Function):void {
		if (!b_end) {
			var v_star_idx:int = min_by_idx(left, function(v:String):Number {return distance[v];});
			var v_star:String = left[v_star_idx];
			f(v_star, predecessor[v_star], distance[v_star]);
			S.push(v_star);
			if (v_star == z) {
				b_end = true;
				return;
			}

			left = left.filter(function(elem:*, index:int, arr:Array):Boolean {return elem != v_star;});
			for (var len:int=left.length, i:int=0; i<len; ++i) {
				var v:String = left[i];
				var dist:Number = arclength(v_star, v);
				var d:Number = distance[v_star] + dist;
				if (d < distance[v]) {
					distance[v] = d;
					predecessor[v] = v_star;
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
