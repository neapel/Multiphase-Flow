
all : flow.js

doc :
	docco *.coffee

%.js : %.coffee
	coffee -b -c -p $< >$@

.PHONY : clean
clean :
	-rm flow.js
	-rm -rf docs
