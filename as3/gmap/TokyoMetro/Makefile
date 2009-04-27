
PROJECT=TokyoMetro

SRCS =	$(wildcard *.as)

all:	$(PROJECT).swf

$(PROJECT).swf:	$(SRCS)
	mxmlc -compiler.library-path=../sdk/lib/map_flex_1_3.swc -incremental=true -default-size 800 600 -default-frame-rate=60 -default-background-color=0xFFFFFF $(PROJECT).as

clean:
	rm -f *.cache
	rm -f $(PROJECT).swf

conv:	Data.as

Data.as:	tool/m_station.csv tool/station_join.csv
	cd tool && ruby conv.rb m_station.csv station_join.csv >../Data.as

deploy:
	deploy.sh
