/* gmime-test; compile with:
   gcc -o extract_text extract_text.c -Wall -O0 -ggdb3 \
   `pkg-config --cflags --libs gmime-2.6`
*/
#include <gmime/gmime.h>
#include <stdio.h>
#include <errno.h>
#include <string.h>
#include <locale.h>


void print_html(GMimePart *part) {

  // STREAMING out to stdout
  GMimeStream *stream;
  GMimeDataWrapper *wrapper;
  wrapper = g_mime_part_get_content_object((GMimePart *) part);
  stream = g_mime_stream_file_new (stdout);
  g_mime_stream_file_set_owner ((GMimeStreamFile *) stream, FALSE);
  /* write the message to the stream */
  /* g_mime_object_write_to_stream ((GMimeObject *) part, stream); */
  g_mime_data_wrapper_write_to_stream((GMimeDataWrapper *) wrapper, stream);

  /* flush the stream (kinda like fflush() in libc's stdio) */
  g_mime_stream_flush (stream);

  /* free the output stream */
  g_object_unref (stream);
}

void extract_html_foreach_callback (GMimeObject *parent, GMimeObject *part, gpointer user_data) {
  int *count = user_data;

  if (GMIME_IS_MESSAGE_PART (part)) {
    /* message/rfc822 or message/news */

    /* g_mime_message_foreach() won't descend into
       child message parts, so if we want to count any
       subparts of this child message, we'll have to call
       g_mime_message_foreach() again here. */

      GMimeMessage *message;
      message = g_mime_message_part_get_message ((GMimeMessagePart *) part);
      g_mime_message_foreach (message, extract_html_foreach_callback, count);

  } else if (GMIME_IS_MULTIPART (part)) {
    if (g_mime_content_type_is_type(g_mime_object_get_content_type(part), "multipart", "alternative")) {
      GMimeObject *subpart;
      int nr_parts;
      nr_parts = g_mime_multipart_get_count ((GMimeMultipart *) part);
      for(int i=0; i<nr_parts; i++) {
        subpart = g_mime_multipart_get_part((GMimeMultipart *) part, i);
        if (g_mime_content_type_is_type(g_mime_object_get_content_type(subpart), "text", "html")) {
          (*count)++;
          print_html((GMimePart *) subpart);
        }
      }
    }
  }
}


void print_txt(GMimePart *part) {

  // STREAMING out to stdout
  GMimeStream *stream, *fstream;
  GMimeDataWrapper *wrapper;
  GMimeFilter *filter;
  wrapper = g_mime_part_get_content_object((GMimePart *) part);
  stream = g_mime_stream_file_new (stdout);

  // If without html filter
  /* g_mime_stream_file_set_owner ((GMimeStreamFile *) stream, FALSE); */
  /* /\* write the message to the stream *\/ */
  /* /\* g_mime_object_write_to_stream ((GMimeObject *) part, stream); *\/ */
  /* g_mime_data_wrapper_write_to_stream((GMimeDataWrapper *) wrapper, stream); */
  /* /\* flush the stream (kinda like fflush() in libc's stdio) *\/ */
  /* g_mime_stream_flush (stream); */

  fstream = g_mime_stream_filter_new (stream);
  filter = g_mime_filter_html_new (255, 0);
  g_mime_stream_filter_add ((GMimeStreamFilter *) fstream, filter);
  g_object_unref (filter);



  g_mime_data_wrapper_write_to_stream((GMimeDataWrapper *) wrapper, fstream);
  /* flush the stream (kinda like fflush() in libc's stdio) */
  g_mime_stream_flush (fstream);

  /* free the output stream */
  g_object_unref (fstream);
  /* g_object_unref (stream); */
}

void extract_txt_foreach_callback (GMimeObject *parent, GMimeObject *part, gpointer user_data) {
  int *count = user_data;

  if (GMIME_IS_MESSAGE_PART (part)) {

      GMimeMessage *message;
      message = g_mime_message_part_get_message ((GMimeMessagePart *) part);
      g_mime_message_foreach (message, extract_html_foreach_callback, count);

  } else if (GMIME_IS_PART (part)) {
    if (g_mime_content_type_is_type(g_mime_object_get_content_type(part), "text", "plain")) {
      (*count)++;
      print_txt((GMimePart *) part);
    }
  }
}


static gboolean
test_stream (GMimeStream *stream)
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


  /* gpointer user_data = NULL; */
  int count = 0;
  g_mime_message_foreach(msg, extract_html_foreach_callback, &count);
  if (count == 0) { //there is no html part, extract plain text
    g_mime_message_foreach(msg, extract_txt_foreach_callback, &count);
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



static gboolean
test_file (const char *path)
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

  rv = test_stream (stream);  /* test-stream will unref it */

 leave:
  if (file)
    fclose (file);

  return rv;
}

int
main (int argc, char *argv[])
{
  gboolean rv;

  if (argc < 2) {
    g_printerr ("usage: %s <msg-files>\n", argv[0]);
    return 1;
  }

  setlocale (LC_ALL, "");

  g_mime_init(GMIME_ENABLE_RFC2047_WORKAROUNDS);

  int x;
  for ( x = 1; x < argc; x++ ) {
    /* printf("File: %s\n", argv[x]); */
    rv = test_file (argv[x]);
  }

  g_mime_shutdown ();

  return rv ? 0 : 1;
}
