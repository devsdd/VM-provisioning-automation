# include <stdio.h>
# include <stdlib.h>
# include <string.h>
# include <cgic.h>
# include <flate.h>
# include <unistd.h>
# include <sys/types.h>
# include <sys/stat.h>
# include <fcntl.h>
# include <errno.h>
# include <dirent.h>
# include <ctype.h>
# include <glob.h>
# include <mysql/mysql.h>

# define VM_DIR	"/tmp/"				/* directory to create request files in	*/
# define XEN_CONF_FILES_PATH "/tmp/"

int create_file(char *OS, char *hostname);
int get_vps_list(char *user, char *vpslist[]);
int get_server_wise_vpslist(void);

int cgiMain(void)
{
	char hostname[64];
	char action [32];		/* buffer to capture form action	*/
//	cgiFormResultType result;
	char OS[16];
	char choice[12];		/* choice of interfaces to start existing VM or create new one	*/
	char buffer[64];
	char *vpslist[32];
	unsigned char i, len;		/* small positive counters	*/

	cgiHeaderContentType("text/html");			/* outputs the HTTP header	*/
	templateSetFile("/var/www/html/interface.html");	/* external HTML template	*/

	/* enable this to run the CGI in a debug mode with the values of a previous form submission
	(refer http://www.boutell.com/cgic/#debug) for more info on this	*/
//	cgiReadEnvironment("/var/www/cgi-bin/capcgi.dat");

	/* read in the CGI variables for form action, authenticated user, OS selection radio
	 * buttons and hostname text input	*/
	templateSetVar("user", "test.user");	/*
	templateSetVar("user", cgiRemoteUser); 'cgiRemoteUser' is a CGIC
	environment variable that contains the authenticated username, if any	*/
/*
	debug statement
strcpy(cgiRemoteUser, "test.user");	*/

	cgiFormStringNoNewlines("action", action, 32);	/* record the form action	*/
// for debugging
//	strcpy (action, "Request");
	
	len = strlen(buffer);

	if (strcmp(action, "Request") == 0) {

//		cgiFormStringNoNewlines("OS", OS, 16);
		cgiFormStringNoNewlines("hostname", buffer, 64);
// for debugging
		strcpy(OS, "Linux");
//		strcpy(hostname, "ghost.name");

		/* If hostname is left blank, throw an error */
		if (len == 0) {
			templateSetVar("no_hostname", "");
			goto print;
		}

		/* check for blanks etc. in hostname	*/
		for (i = 0 ; i < len ; i++) {
			if (isspace(buffer[i])) {
				templateSetVar("bad_hostname", "");
				goto print;
			}
		}

		/* check for invalid Windows hostnames	*/
		if (strcmp(OS, "Windows") == 0) {
			for (i = 0 ; i < len ; i++) {
				if(len > 15) {
					templateSetVar("bad_hostname", "");
					goto print;
				}
				if (!isalnum(buffer[i]) && buffer[i] != '-') {
					templateSetVar("bad_hostname", "");
					goto print;
				} else {
					/* convert windows hostnames to uppercase	*/
					hostname[i] = toupper(buffer[i]);
				}
			}
			hostname[i] = '\0';
		} else if (strcmp(OS, "Linux") == 0) {
			strncpy(hostname, buffer, sizeof(buffer));
		} else {		 /* If no OS is selected, throw an error	*/
			templateSetVar("invalid_OS_choice", "");
			goto print;
		}

		/* if all is well, create the request file and fill it with the hostname	*/
		/*
		if (create_file(OS, hostname) == EXIT_FAILURE) {
			goto print;
		}
		*/

		/* check no. of VM's on each server	*/
		if (get_server_wise_vpslist() < 1) {
			templateSetVar("db_read_failed", "");
			goto print;
		}
			goto print;

		/* Now, insert an entry into the DB instead of creating a file	*/

//		insert_into_DB(cgiRemoteUser, hostname, OS);


		templateSetVar("success", "");
		templateSetVar("OS", OS);
		templateSetVar("hostname", hostname);

	} else if (strcmp(action, "Select") == 0) {

		cgiFormStringNoNewlines("choice", choice, 16);
// for debugging
//		strcpy(choice, "Existing");
		if (strcmp(choice, "New") == 0) {
			templateSetVar("form", "");
		
		} else if (strcmp(choice, "Existing") == 0) {
			*vpslist = NULL;
/*			if (get_vps_list(cgiRemoteUser, vpslist) != 0) {
				templateSetVar("no-vps", "");
			} else {
//				fprintf(cgiOut, "\n%s", vpslist[0]);
			}
			*/
		}

	} else {
		templateSetVar("selection", "");
	}

print:	templatePrint();
	return 0;
}

int get_server_wise_vpslist(void)
{
	MYSQL *conn;		/* DB connection handle structure	*/
	MYSQL_RES *res;		/* result of a SELECT-like query	*/
	MYSQL_ROW row;		/* one row of data			*/
	int ServerID, ServerCount, i;
	char *server = "localhost";
	char *user = "root";
	char *DB = "vps";
	char *query = NULL;

	conn = mysql_init(NULL);	/* Initialize the DB connection handle	*/

	/* Connect to DB	*/
	if (!mysql_real_connect(conn, server, user, NULL, DB, 0, NULL, 0)) {
		templateSetVar("db_error", "Unable to connect to database.");
		return -1;
	}

	/* Send SQL Query	*/
	if (mysql_query(conn, "SELECT server_id FROM guests ORDER BY server_id DESC LIMIT 1;")) {
		templateSetVar("db_error", "Failed to get server ID.");
		return -2;
	}

	/* Retrieve the result of the last query	*/
	res = mysql_use_result(conn);

	/* store the result in appropriate variable	*/
	while ((row = mysql_fetch_row(res)) != NULL) {
		ServerCount = atoi(row[0]);
	}

	printf("max server id = %d", ServerCount);
	
//	sprintf(query, "SELECT * FROM guests WHERE server_id = '%d';", ServerID);

	mysql_free_result(res);
	mysql_close(conn);

	return 0;
}

int create_file(char *OS, char* hostname)
{
	char filename[64], buffer[64];
	int fd, i = 0, j = 48;	/* filenames need to use ASCII codes for numbers	*/
	DIR *dirp;

	bzero(filename, sizeof(filename));	/* blank out the string	*/
	bzero(buffer, sizeof(buffer));	/* blank out the string	*/
	strcpy(buffer, VM_DIR);
	strcat(buffer, OS);

	/* first check if the parent directories exist, if not, create them, mode 755	*/
	if ((dirp = opendir(buffer)) == NULL) {
		if (mkdir(buffer, S_IRWXU | S_IRGRP | S_IXGRP | S_IROTH | S_IXOTH) != 0) {
			templateSetVar("file_create_error", "");
			templateSetVar("error_msg", "Parent directory does not exist and could not be created");
		}
		closedir(dirp);
	}

	strcat(buffer, "/");
	strcat(buffer, cgiRemoteUser);

//	debug statement
//	templateSetVar("filename", buffer);

	/* if "filename" already exists, use names like "filename.0",
	 * "filename.1" etc. Obviously, this will only work as long as the file
	 * count is single digit, but since we plan to delete the files after
	 * the VM is created, this should be OK.	*/
	while (access(buffer, F_OK) == 0) {
		if (i == 0) {			/* first time through	*/
			strcat(buffer, ".0");
		}
		i = strlen(buffer);
		buffer[--i] = (char)++j;
	}

	/* if a non-existing filename is found, use it.	*/
	strcpy(filename, buffer);	
//	debug statement:
//	fprintf(cgiOut, "<br> filename is %s<br>", filename);

	if ((fd = open(filename, O_CREAT|O_EXCL, S_IRUSR | S_IWUSR | S_IRGRP | S_IROTH )) == -1) {
		/* failed to create the file with mode 644*/
		switch (errno) {
			case EACCES:		templateSetVar("error_msg", "Access Denied");
						return EXIT_FAILURE;

			case ENAMETOOLONG: 	templateSetVar("error_msg", "Name Too Long");
						return EXIT_FAILURE;

			default:		templateSetVar("error_msg", "Unspecified Error");
						return EXIT_FAILURE;
		}
	} else {
		close(fd); 	/* close and reopen FD as it can't be used for writing	*/

		if ((fd = open(filename, O_WRONLY | O_TRUNC)) == -1) {
			fprintf(cgiOut, "fopen failed<br>");
			templateSetVar("write_error", "");
			templateSetVar("error_msg", strerror(errno));
			return EXIT_FAILURE;
		} else if (write(fd, hostname, strlen(hostname)) < 1) { /* write hostname to file */
			fprintf(cgiOut, "fwrite failed<br>");
			templateSetVar("write_error", "");
			templateSetVar("error_msg", strerror(errno));
			return EXIT_FAILURE;
		}
		close(fd);
	}

	return EXIT_SUCCESS;
}

int get_vps_list(char *user, char *list[])
{
	char temp[128], buffer[64];
	glob_t globpat; 		/* structure containing matched pattern details */
	int i;

	bzero(temp, sizeof(temp));
	strcpy(temp, XEN_CONF_FILES_PATH);
	strcat(temp, user);
	strcat(temp, "/conf/*");
//	printf ("%s", temp);

	if (glob(temp, GLOB_ERR, NULL, &globpat) == GLOB_NOMATCH) {
		return 1;
	} else {
		for (i = 0;  i < globpat.gl_pathc ; i++) {
			strcpy(list[i], globpat.gl_pathv[i]);
		}
	}

	return 0;
}
