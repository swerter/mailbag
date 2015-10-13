/* gmime-test; compile with:
   gcc -o extract_structure extract_structure.c -Wall -O0 -ggdb3 \
   `pkg-config --cflags --libs gmime-2.6`
*/
#include <gmime/gmime.h>
#include <stdio.h>
#include <errno.h>
#include <string.h>
#include <locale.h>

void extract_all_parts (GMimePart *part, GMimeStream *out_stream) {
  /* g_mime_stream_printf (out_stream, "%%{"); */

  if (GMIME_IS_MESSAGE_PART (part)) {
    g_mime_stream_printf (out_stream, "[");
    extract_all_parts(part, out_stream);
    g_mime_stream_printf (out_stream, "],");

  } else if (GMIME_IS_MULTIPART (part)) {
    /* g_mime_stream_printf (out_stream, g_mime_content_type_to_string(g_mime_object_get_content_type((GMimeObject *) part))); */
    int nr_parts;
    nr_parts = g_mime_multipart_get_count ((GMimeMultipart *) part);
    g_mime_stream_printf (out_stream, "multipart: %%{type: \"%s\", entries: [", g_mime_content_type_to_string(g_mime_object_get_content_type((GMimeObject *) part)));
    for(int i=0; i<nr_parts; i++) {
      if (i > 0) {
        g_mime_stream_printf (out_stream, ", ");
      }
      GMimeObject *subpart;
      subpart = g_mime_multipart_get_part((GMimeMultipart *) part, i);
      extract_all_parts((GMimePart *) subpart, out_stream);
    }
    g_mime_stream_printf (out_stream, "]}");
  } else if (GMIME_IS_MESSAGE_PARTIAL (part)) {
    g_mime_stream_printf (out_stream, "partial: ");

  } else if (GMIME_IS_PART (part)) {
    /* a normal leaf part, could be text/plain or
     * image/jpeg etc */
    if (g_mime_content_type_is_type(g_mime_object_get_content_type((GMimeObject *) part), "text", "*")) {
      if (g_mime_content_type_is_type(g_mime_object_get_content_type((GMimeObject *) part), "text", "plain")) {
        g_mime_stream_printf (out_stream, "%%{type: \"plain\"}");
      }
      if (g_mime_content_type_is_type(g_mime_object_get_content_type((GMimeObject *) part), "text", "html")) {
        g_mime_stream_printf (out_stream, "%%{type: \"html\"}");
      }
    }
    else {
      const char *filename;
      filename = g_mime_part_get_filename (part);
      g_mime_stream_printf (out_stream, "attachment: ");
      g_mime_stream_printf (out_stream, "%%{filename: %s }", filename);

    }
  } else {
    /* should never happen */
    g_mime_stream_printf (out_stream, "NOT_POSSIBLE\n");
  }
  /* g_mime_stream_printf (out_stream, "},"); */

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


  GMimeObject *mime_part;
  mime_part = g_mime_message_get_mime_part(msg);
  g_mime_stream_printf (out_stream, "%%{");
  if (g_mime_content_type_is_type(g_mime_object_get_content_type(mime_part), "multipart", "*")) {
    /* g_mime_stream_printf (out_stream, g_mime_content_type_to_string(g_mime_object_get_content_type(mime_part))); */
    /* int nr_parts; */
    /* nr_parts = g_mime_multipart_get_count ((GMimeMultipart *) mime_part); */
    /* g_mime_stream_printf (out_stream, "\nTotal parts: -> %i parts\n", nr_parts); */
    extract_all_parts((GMimePart *) mime_part, out_stream);
  } else {
    if (g_mime_content_type_is_type(g_mime_object_get_content_type((GMimeObject *) mime_part), "text", "*")) {
      if (g_mime_content_type_is_type(g_mime_object_get_content_type((GMimeObject *) mime_part), "text", "plain")) {
        g_mime_stream_printf (out_stream, "type: \"plain\"");
      }
      if (g_mime_content_type_is_type(g_mime_object_get_content_type((GMimeObject *) mime_part), "text", "html")) {
        g_mime_stream_printf (out_stream, "type: \"html\"");
      }
    }
  }
  g_mime_stream_printf (out_stream, "}");

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

  if (argc == 2) {
    rv = test_file (argv[1], out_stream);
  } else {
    g_mime_stream_printf (out_stream, "[");
    int x;
    for ( x = 1; x < argc; x++ ) {
      /* printf("File: %s\n", argv[x]); */
      /* g_mime_stream_printf (out_stream, "%s\n", argv[x]); */
      rv = test_file (argv[x], out_stream);
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
