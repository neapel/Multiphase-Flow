
all : flow.js

%.js : %.coffee
	coffee -b -c -p $< >$@
