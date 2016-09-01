all : vps.cgi

vps.cgi : interface.c
	gcc -g -Wall interface.c -o vps.cgi -l cgic -l flate `mysql_config --cflags` `mysql_config --libs`

install : vps.cgi
	sudo cp vps.cgi /var/www/cgi-bin/
	sudo cp interface.html /var/www/html/

clean	:
	rm -f vps.cgi
