#! /usr/bin/ruby -Ke

require "csv"
require "kconv"

StationName			= "station_name"
LineCode			= "line_cd"
LineName			= "line_name"
Latitude			= "lat"				# 緯度
Longitude			= "lon"				# 経度
StationCode			= "station_cd"
StationSort			= "station_sort"
GlobalStationCode	= "station_g_cd"

Station = Struct.new(:gid, :name, :lat, :lon)
RailStation = Struct.new(:rid, :station_gid)
RailJoin = Struct.new(:rsi1, :rsi2, :cost)

PI = 3.1415926535

#=== つながってる駅を返す
=begin
def make_station_join(rail_station)
	joins = Hash.new {|h, k| h[k] = []}
	rail_station.each do |k, v|
		joins[v.station_gid].push(v.rid)
	end
	joins.values.select{|v| v.length > 1}
end
=end

#=== 路線情報
class RailInfo
	attr_accessor :stations, :rail_stations		#, :lines, :joins
	attr_accessor :rail_lines
	attr_accessor :rail_joins

	# 駅情報CSV読み込み
	def read_station_csv(station_csv_fn)
		metros = read_csv(station_csv_fn)
		@stations, @rail_stations, @rail_lines = make_stations(metros)
	end

	# 路線情報CSV読み込み
	def read_rail_join_csv(join_csv_fn)
		joins = read_csv(join_csv_fn)
		@rail_joins = make_rail_joins(joins)
	end

	#=== CSVファイル一括読み込み
	def read_csv(csv_fn)
		fields = nil
		data = []
		CSV.open(csv_fn, "r") do |row|
			unless fields
				fields = row
			else
				if row[0] =~ /^#/
					# コメント
				else
					data.push(Hash[*fields.zip(row).flatten])
				end
			end
		end
		data
	end

	#=== 駅情報取り出し
	def make_stations(metros)
		stations = {}
		rail_stations = {}
		lines = {}
		metros.each do |e|
			gid = e[GlobalStationCode].to_i
			unless stations.has_key?(gid)
				stations[gid] = Station.new(gid, e[StationName], e[Latitude].to_f, e[Longitude].to_f)
			end

			id = e[StationCode].to_i
			rail_stations[id] = RailStation.new(id, gid)

			unless lines.has_key?(e['line_cd'])
				lines[e['line_cd'].to_i] = e['line_name']
			end
		end
		return stations, rail_stations, lines
	end

	#=== 路線接続情報取り出し
	def make_rail_joins(joins)
		rail_joins = {}
		joins.each do |e|
			line_cd = e['line_cd'].to_i
			unless rail_joins.has_key?(line_cd)
				rail_joins[line_cd] = []
			end

			st1 = e['station_cd1'].to_i
			st2 = e['station_cd2'].to_i
			km = e['s_km'] ? e['s_km'].to_f : distance(st1, st2)
			rail_joins[line_cd].push(RailJoin.new(st1, st2, km))
		end
		return rail_joins
	end

	#=== 駅間の距離
	# ref: http://wadati.blog10.fc2.com/blog-entry-345.html
	def distance(st1, st2)
		r = 6378.137		# 地球の半径

		unless @rail_stations.has_key?(st1)
			raise "not exist @rail_stations:#{st1}"
		end
		unless @rail_stations.has_key?(st2)
			raise "not exist @rail_stations:#{st2}"
		end

		i1 = @stations[@rail_stations[st1].station_gid]
		i2 = @stations[@rail_stations[st2].station_gid]

		dlat = (i1.lat - i2.lat) * (PI / 180)
		dlon = (i1.lon - i2.lon) * (PI / 180)
		dy = r * dlat
		dx = r * dlon * Math.cos(i1.lat * (PI / 180))
		l = Math.sqrt(dx*dx + dy*dy)
		return l
	end
end

def dump_rail_info(rail_info)
	puts "package {"
	puts "public class Data {"
	puts "public static var Stations:Object = {"
#	puts(rail_info.stations.to_a.sort_by{|x| x[0]}.map do |k, e|
#		%!\t"#{e.gid}": {"name":"#{e.name}", "lat":#{e.lat}, "lng":#{e.lon}}!	#.toutf8
#	end.join(",\n"))
	puts "};"

	puts "public static var RailStations:Object = {"
#	puts(rail_info.rail_stations.to_a.sort_by{|x| x[0]}.map do |k, e|
#		%!\t"#{e.rid}": "#{e.station_gid}"!
#	end.join(",\n"))
	puts "};"

	puts "public static var Lines:Object = {"
#	puts(rail_info.rail_joins.to_a.sort_by{|k, e| k}.map do |k, e|
#		name = rail_info.rail_lines[k]
#		joins = e.map{|j| %!{"rsi1":"#{j.rsi1}", "rsi2":"#{j.rsi2}", "cost":#{j.cost}}!}
#		%!\t"#{k}": { "name":"#{name}", "joins":[ #{joins.join(", ")} ] }!	#.toutf8
#	end.join(",\n"))
	puts "};"


	puts %!public static function init():void {!

	puts(rail_info.stations.to_a.sort_by{|x| x[0]}.map do |k, e|
		%!\tData.Stations["#{e.gid}"] = {"name":"#{e.name}", "lat":#{e.lat}, "lng":#{e.lon}};!
	end.join("\n").toutf8)

	puts(rail_info.rail_stations.to_a.sort_by{|x| x[0]}.map do |k, e|
		%!\tData.RailStations["#{e.rid}"] = "#{e.station_gid}";!
	end.join("\n"))

	puts(rail_info.rail_joins.to_a.sort_by{|k, e| k}.map do |k, e|
		name = rail_info.rail_lines[k]
		joins = e.map{|j| %!{"rsi1":"#{j.rsi1}", "rsi2":"#{j.rsi2}", "cost":#{j.cost}}!}
		%!\tData.Lines["#{k}"] = { "name":"#{name}", "joins":[ #{joins.join(", ")} ] };!
	end.join("\n").toutf8)

	puts %!}!


	puts "}"
	puts "}"
end

station_fn = ARGV.shift
join_fn = ARGV.shift

rail_info = RailInfo.new
rail_info.read_station_csv(station_fn)
rail_info.read_rail_join_csv(join_fn)
dump_rail_info(rail_info)
