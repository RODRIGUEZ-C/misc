
PROJECT=TokyoMetro

SRCS =	$(wildcard *.as)

all:	$(PROJECT).swf

$(PROJECT).swf:	$(SRCS)
	mxmlc -compiler.library-path=../sdk/lib/map_flex_1_3.swc -incremental=true -default-size 640 480 -default-frame-rate=60 -default-background-color=0xFFFFFF $(PROJECT).as

clean:
	rm -f *.cache
	rm -f $(PROJECT).swf

conv:
	cd conv; ruby conv.rb 
