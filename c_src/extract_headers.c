/* gmime-test; compile with:
   gcc -o extract_structure extract_headers.c -Wall -O0 -ggdb3 \
   `pkg-config --cflags --libs gmime-2.6`
*/
#include <gmime/gmime.h>
#include <stdio.h>
#include <stdlib.h>
#include <errno.h>
#include <string.h>
#include <locale.h>
#include <string.h>

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
  int i;
  for (i=0; i<internet_address_list_length(address_list); i++) {
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

static gboolean has_attachment(GMimePart *part, GMimeStream *out_stream, gboolean has_attach) {
  if (GMIME_IS_MESSAGE_PART (part)) {
    has_attachment(part, out_stream, has_attach);
  } else if (GMIME_IS_MULTIPART (part)) {
    int nr_parts;
    int i;
    nr_parts = g_mime_multipart_get_count ((GMimeMultipart *) part);
    for(i=0; i<nr_parts; i++) {
      GMimeObject *subpart;
      subpart = g_mime_multipart_get_part((GMimeMultipart *) part, i);
      has_attachment((GMimePart *) subpart, out_stream, has_attach);
    }
  } else if (GMIME_IS_PART (part)) {
    /* /\* a normal leaf part, could be text/plain or */
    /*  * image/jpeg etc *\/ */
    if (g_mime_content_type_is_type(g_mime_object_get_content_type((GMimeObject *) part), "text", "*")) {
    /*   if (g_mime_content_type_is_type(g_mime_object_get_content_type((GMimeObject *) part), "text", "plain")) { */
    /*     g_mime_stream_printf (out_stream, "%%{type: \"plain\"}"); */
    /*   } */
    /*   if (g_mime_content_type_is_type(g_mime_object_get_content_type((GMimeObject *) part), "text", "html")) { */
    /*     g_mime_stream_printf (out_stream, "%%{type: \"html\"}"); */
    /*   } */
    }
    else {
      has_attach = TRUE;
    }
  }
  return has_attach;
}

void extract_headers (GMimeMessage *message, GMimeStream *out_stream) {
  const char *subject;
  char *escaped_subject;
  const char *sender;
  char *escaped_sender;
  const char *reply_to;
  char *escaped_reply_to;
  time_t t;
  int tz;
  char buf[64];
  struct tm *t_m;
  subject = g_mime_message_get_subject(message);
  escaped_subject = str_replace((char *) subject, "\"", "");
  g_mime_stream_printf (out_stream, "subject: \"%s\", ", escaped_subject);
  g_mime_stream_printf (out_stream, "message_id: \"%s\", ", g_mime_message_get_message_id(message));
  sender = g_mime_message_get_sender(message);
  escaped_sender = str_replace((char *) sender, "\"", "");
  g_mime_stream_printf (out_stream, "sender: \"%s\", ", escaped_sender);
  reply_to = g_mime_message_get_reply_to(message);
  escaped_reply_to = str_replace((char *) reply_to, "\"", "");
  g_mime_stream_printf (out_stream, "reply_to: \"%s\", ", escaped_reply_to);
  g_mime_message_get_date (message, &t, &tz);
  t_m = localtime (&t);
  strftime(buf, sizeof(buf) - 1, "%c", t_m);
  g_mime_stream_printf (out_stream, "date: \"%s\", ", buf);
  strftime(buf, sizeof(buf) - 1, "%Y%m%d%H%M%S", t_m);
  g_mime_stream_printf (out_stream, "sort_date: \"%s\", ", buf);

  InternetAddressList *recipients;
  recipients = g_mime_message_get_recipients(message, GMIME_RECIPIENT_TYPE_TO);
  g_mime_stream_printf (out_stream, "recipients_to: [");
  extract_addresses(recipients, out_stream);
  g_mime_stream_printf (out_stream, "], ");

  recipients = g_mime_message_get_recipients(message, GMIME_RECIPIENT_TYPE_CC);
  g_mime_stream_printf (out_stream, "recipients_cc: [");
  extract_addresses(recipients, out_stream);
  g_mime_stream_printf (out_stream, "], ");

  recipients = g_mime_message_get_recipients(message, GMIME_RECIPIENT_TYPE_BCC);
  g_mime_stream_printf (out_stream, "recipients_bcc: [");
  extract_addresses(recipients, out_stream);
  g_mime_stream_printf (out_stream, "] ");
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

  GMimeObject *mime_part;
  mime_part = g_mime_message_get_mime_part(msg);
  if (g_mime_content_type_is_type(g_mime_object_get_content_type(mime_part), "multipart", "*")) {
    if (has_attachment((GMimePart *) mime_part, out_stream, FALSE) == TRUE) {
      g_mime_stream_printf (out_stream, ", has_attachment: true");
    } else {
      g_mime_stream_printf (out_stream, ", has_attachment: false");
    };
  } else {
    g_mime_stream_printf (out_stream, ", has_attachment: false");
  }

 leave:
  if (parser)
    g_object_unref (parser);
  else
    g_object_unref (stream);

  if (msg)
    g_object_unref (msg);

  return rv;
}



void extract_flags(const char *filename, GMimeStream *out_stream) {
  char* flags;
  char* string;
  char* tofree;

  string = strdup(filename);

  if (string != NULL) {

    tofree = string;

    if(strstr(filename, "new") != NULL) {
      g_mime_stream_printf (out_stream, "new: true, ");
    } else {
      g_mime_stream_printf (out_stream, "new: false, ");
    }

    strsep(&string, ":");
    flags = strsep(&string, ":");
    if(strstr(flags, "D") != NULL) {
      g_mime_stream_printf (out_stream, "draft: true, ");
    } else {
      g_mime_stream_printf (out_stream, "draft: false, ");
    }
    if(strstr(flags, "F") != NULL) {
      g_mime_stream_printf (out_stream, "flagged: true, ");
    } else {
      g_mime_stream_printf (out_stream, "flagged: false, ");
    }
    if(strstr(flags, "P") != NULL) {
      g_mime_stream_printf (out_stream, "passed: true, ");
    } else {
      g_mime_stream_printf (out_stream, "passed: false, ");
    }
    if(strstr(flags, "R") != NULL) {
      g_mime_stream_printf (out_stream, "replied: true, ");
    } else {
      g_mime_stream_printf (out_stream, "replied: false, ");
    }
    if(strstr(flags, "S") != NULL) {
      g_mime_stream_printf (out_stream, "seen: true, ");
    } else {
      g_mime_stream_printf (out_stream, "seen: false, ");
    }
    if(strstr(flags, "T") != NULL) {
      g_mime_stream_printf (out_stream, "trashed: true, ");
    } else {
      g_mime_stream_printf (out_stream, "trashed: false, ");
    }

    free(tofree);
  }
}


static gboolean
test_file (const char *path, GMimeStream *out_stream)
{
  FILE *file;
  GMimeStream *stream;
  gboolean rv;

  stream = NULL;
  file   = NULL;

  extract_flags(path, out_stream);
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

  if (argc == 2) {
    g_mime_stream_printf (out_stream, "%%{");
    g_mime_stream_printf (out_stream, "path: \"%s\", ", argv[1]);
    rv = test_file (argv[1], out_stream);
    g_mime_stream_printf (out_stream, "}");
  } else {
    g_mime_stream_printf (out_stream, "[");
    int x;
    for (x = 1; x < argc; x++ ) {
      /* printf("File: %s\n", argv[x]); */
      if (x > 1) {
        g_mime_stream_printf (out_stream, ", ");
      }
      g_mime_stream_printf (out_stream, "%%{");
      g_mime_stream_printf (out_stream, "path: \"%s\", ", argv[x]);
      rv = test_file (argv[x], out_stream);
      g_mime_stream_printf (out_stream, "}");
    }
    g_mime_stream_printf (out_stream, "]");
  }

  g_mime_shutdown ();

  /* flush stdout */
  g_mime_stream_flush (out_stream);

  /* free/close the stream */
  g_object_unref (out_stream);

  return rv ? 0 : 1;
}
