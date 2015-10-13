/* gmime-test; compile with:
   gcc -o extract_structure extract_structure.c -Wall -O0 -ggdb3 \
   `pkg-config --cflags --libs gmime-2.6`
*/
#include <gmime/gmime.h>
#include <stdio.h>
#include <stdlib.h>
#include <errno.h>
#include <string.h>
#include <locale.h>

/* Replace parts of a string with another */
/* taken from http://stackoverflow.com/questions/779875/what-is-the-function-to-replace-string-in-c */
char *str_replace(char *orig, char *rep, char *with) {
    char *result; // the return string
    char *ins;    // the next insert point
    char *tmp;    // varies
    int len_rep;  // length of rep
    int len_with; // length of with
    int len_front; // distance between rep and end of last rep
    int count;    // number of replacements

    if (!orig) {
        return NULL;
    }
    if (!rep) {
        rep = "";
    }
    len_rep = strlen(rep);
    if (!with) {
        with = "";
    }
    len_with = strlen(with);

    ins = orig;
    for (count = 0; tmp = strstr(ins, rep); ++count) {
        ins = tmp + len_rep;
    }

    // first time through the loop, all the variable are set correctly
    // from here on,
    //    tmp points to the end of the result string
    //    ins points to the next occurrence of rep in orig
    //    orig points to the remainder of orig after "end of rep"
    tmp = result = malloc(strlen(orig) + (len_with - len_rep) * count + 1);

    if (!result) {
        return NULL;
    }

    while (count--) {
        ins = strstr(orig, rep);
        len_front = ins - orig;
        tmp = strncpy(tmp, orig, len_front) + len_front;
        tmp = strcpy(tmp, with) + len_with;
        orig += len_front + len_rep; // move to next "end of rep"
    }
    strcpy(tmp, orig);
    return result;
}


void extract_addresses(InternetAddressList *address_list, GMimeStream *out_stream) {
  for (int i=0; i<internet_address_list_length(address_list); i++) {
    if (i > 0) {
      g_mime_stream_printf (out_stream, ", ");
    }
    InternetAddress *address;
    char *address_string;
    address = internet_address_list_get_address(address_list, i);
    address_string = internet_address_to_string(address, TRUE);
    address_string = str_replace(address_string, "\"", "\\\"");
    g_mime_stream_printf (out_stream, "\"%s\"", address_string);
  }
}

void extract_headers (GMimeMessage *message, GMimeStream *out_stream) {
    InternetAddressList *recipients;
    recipients = g_mime_message_get_recipients(message, GMIME_RECIPIENT_TYPE_TO);
    extract_addresses(recipients, out_stream);

    recipients = g_mime_message_get_recipients(message, GMIME_RECIPIENT_TYPE_CC);
    extract_addresses(recipients, out_stream);

    recipients = g_mime_message_get_recipients(message, GMIME_RECIPIENT_TYPE_BCC);
    extract_addresses(recipients, out_stream);
}



static gboolean
test_stream (GMimeStream *stream, GMimeStream *out_stream)
{
  GMimeParser *parser;
  GMimeMessage *msg;
  gboolean rv;

  parser = NULL;
  msg    = NULL;

  parser = g_mime_parser_new_with_stream (stream);
  if (!parser) {
    g_warning ("failed to create parser");
    rv = FALSE;
    goto leave;
  }


  msg = g_mime_parser_construct_message (parser);
  if (!msg) {
    g_warning ("failed to construct message");
    rv = FALSE;
    goto leave;
  }

  extract_headers(msg, out_stream);

 leave:
  if (parser)
    g_object_unref (parser);
  else
    g_object_unref (stream);

  if (msg)
    g_object_unref (msg);

  return rv;
}



static gboolean
test_file (const char *path, GMimeStream *out_stream)
{
  FILE *file;
  GMimeStream *stream;
  gboolean rv;

  stream = NULL;
  file   = NULL;

  file = fopen (path, "r");
  if (!file) {
    g_warning ("cannot open file '%s': %s", path,
               strerror(errno));
    rv = FALSE;
    goto leave;
  }

  stream = g_mime_stream_file_new (file);
  if (!stream) {
    g_warning ("cannot open stream for '%s'", path);
    rv = FALSE;
    goto leave;
  }

  rv = test_stream (stream, out_stream);  /* test-stream will unref it */

 leave:
  if (file)
    fclose (file);

  return rv;
}


int
main (int argc, char *argv[])
{
  gboolean rv;
  GMimeStream *out_stream;
  out_stream = g_mime_stream_file_new (stdout);

  if (argc < 2) {
    g_printerr ("usage: %s <msg-files>\n", argv[0]);
    return 1;
  }

  setlocale (LC_ALL, "");

  g_mime_init(GMIME_ENABLE_RFC2047_WORKAROUNDS);

  g_mime_stream_printf (out_stream, "[");
  for (int x = 1; x < argc; x++ ) {
    if (x > 1) {
      g_mime_stream_printf (out_stream, ", ");
    }
    rv = test_file (argv[x], out_stream);
  }
  g_mime_stream_printf (out_stream, "]");
  g_mime_stream_printf (out_stream, "\n\n");

  g_mime_shutdown ();

  /* flush stdout */
  g_mime_stream_flush (out_stream);

  /* free/close the stream */
  g_object_unref (out_stream);

  return rv ? 0 : 1;
}
