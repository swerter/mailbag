defmodule Mailbag.Maildir do
  @moduledoc """
  Module for working with maildirs.
  """
  use Timex


  @doc """
  On a mailserver, the email is often stored as followes for
  the user aaa@bbb.com
  /bbb.com/aaa/{INBOX,Drafts,...}
  mailbox_path converts the email to such a path.
  ## Example
      iex> Mailbag.Maildir.mailbox_path("/x/", "aaa@bbb.com")
      "/x/bbb.com/aaa/INBOX"
      iex> Mailbag.Maildir.mailbox_path("/x/", "aaa@bbb.com", "Draft")
      "/x/bbb.com/aaa/Draft"

  """
  def mailbox_path(base_path, email, folder \\ "INBOX") do
    [user_name, domain] = String.split(email, "@")

    base_path
      |> Path.join(domain)
      |> Path.join(user_name)
      |> Path.join(folder)
      |> Path.expand
  end

  @doc """
  Extract a list of all emails in a maildir folder, including 'cur', and 'new'.
  ## Example
      iex> emails = Mailbag.Maildir.all("test/data/INBOX") |> Enum.count
      4

  """
  def all(maildir_path) do
    unless is_maildir?(maildir_path), do: raise "Not a maildir"

    {:ok, new_emails} = File.ls(Path.join(maildir_path, "new"))
    {:ok, current_emails} = File.ls(Path.join(maildir_path, "cur"))

    Enum.map(new_emails, fn(x) -> parse_email_header(Path.join(maildir_path, "new"), x) end) ++
      Enum.map(current_emails, fn(x) -> parse_email_header(Path.join(maildir_path, "cur"), x) end)
  end



  @doc """
  Extract information from the email header.
  Uses streams to avoid having to read the whole email just to
  extract the header values.
  """
  def parse_email_header(folder_path, email_id) do
    email_file_path = Path.join(folder_path, email_id)

    content_stream = File.stream!(email_file_path)
    header = extract_header(content_stream)
    from = extract_from_header(content_stream, "From:")
    if is_nil(Regex.run(~r/.*<(.*)>/, from)) do
      from_email =  from
    else
      from_email = Regex.run(~r/.*<(.*)>/, from) |> List.last
    end
    from_email = Mailbag.MimeMail.Words.word_decode(from_email)
    subject = extract_from_header(content_stream, "Subject:")
    |> Mailbag.MimeMail.Words.word_decode
    # If there is no date in the header
    date = extract_from_header(content_stream, "Date:") |> date_cleansing
    date = case Timex.DateFormat.parse(date, "{RFC1123}") do
      {:ok, date} -> date
      {_, date} -> {:ok, date} = Timex.DateFormat.parse("Mon, 1 Jan 1970 00:00:00 +0000", "{RFC1123}"); date
    end
    {:ok, date_sort_string} = Timex.Format.DateTime.Formatters.Default.format(date, "{YYYY}{M}{D}{h24}{m}{s}")
    %{content_type: content_type, boundary: boundary} = extract_content_type_and_boundary(header)

    %{id: email_id, from: from, from_email: from_email, subject: subject, date: date, content_type: content_type, date_sort_string: date_sort_string, boundary: boundary}
  end


  def extract_header(stream) do
    Stream.take_while(stream, &(&1 != "\n")) # get header
    |> Enum.to_list
    |> Enum.join("")
  end



  def extract_content_type_and_boundary(header) do
    re = ~r/Content-[T|t]ype: .*\n?(\s+.*\n)*/
    if is_nil(Regex.run(re, header)) do
      %{content_type: "", boundary: "", charset: ""}
    else
      boundary = ""
      charset = ""
      full_line = Regex.run(re, header) |> Enum.at(0)

      if Regex.match?(re = ~r/Content-[T|t]ype: ([\w|\/|-]*);/, full_line) do
        [_, content_type] = Regex.run(re, full_line)
      end

      additions = String.split(full_line, ";")
      |> Enum.slice(1..-1)
      |> Enum.reduce(%{}, fn(x, acc) ->
        [_, key, val] = Regex.run(~r/(\w*)="?(.*)"?/, x)
        res = case key do
          "boundary" -> %{boundary: String.replace(val, "\"", "")}
          "charset" ->  %{charset: String.replace(val, "\"", "")}
            _ -> %{}
        end
        Map.merge(acc, res)
      end)


      # if Regex.match?(re = ~r/Content-[T|t]ype: ([\w|\/]*);\s*boundary="(.*)";?/, full_line) do
      #   [_, content_type, boundary] = Regex.run(re, full_line)
      #   boundary = String.replace(boundary, "\"", "")
      # end

      # if Regex.match?(re = ~r/Content-[T|t]ype: ([\w|\/]*); charset=(.*);?/, full_line) do
      #   [_, content_type, charset] = Regex.run(re, full_line)
      # end

      # if Regex.match?(re = ~r/Content-[T|t]ype: ([\w|\/]*); charset=(.*);?.*/, full_line) do
      #   [_, content_type, charset] = Regex.run(re, full_line)
      # end
      # charset = charset |> String.replace("\"", "")
      # boundary = boundary |> String.replace(";", "")
      Map.merge(%{content_type: content_type, charset: charset}, additions)
    end
  end


  def extract_content_transfer_encoding(header) do
    re = Regex.run(~r/Content-[T|t]ransfer-[E|e]ncoding:\s+([\w|-]*)/, header) |> Enum.at(1)
  end


  # Extracts the field "type" from the email header
  # Example extract_from_header(stream, "From") would return the email sender, eg. "Hans Huber <h.h@blue.com>"
  def extract_from_header(stream, type) do
    res = Stream.take_while(stream, &(&1 != "\n")) # get header
    |> Stream.filter(&(Regex.match?(~r/^\S*?#{type}.*\n/, &1))) |> Enum.at(0) # extract from header the field
    if res == 0 do # if not found, return empty string
      ""
    else # if found, return the field
      res
      |> String.split("#{type}")
      |> List.last
      |> String.strip
    end
  end



  @doc """
  Cleanes the date because there are some ugly formatted dates out there
  """
  def date_cleansing(date) do
    date
    |> date_cleansing_remove_trailing_timezone
    |> date_cleansing_add_missing_weekday
    |> date_cleansing_remove_double_spaces
    |> date_cleansing_single_digits
  end

  defp date_cleansing_remove_trailing_timezone(date) do
    # remove '(CEST)' in "Mon, 5 Oct 2015 13:36:10 +0200 (CEST)"
    case Regex.run( ~r/(.*)\s(\(.*\))/, date) do
      [_, cleaned_date, _] -> cleaned_date
      nil -> date
    end
  end

  defp date_cleansing_add_missing_weekday(date) do
    # Add eg 'Mon, " to "5 Oct 2015 13:36:10 +0200"
    if String.contains?(date, ",") do
      date
    else
      "Mon, #{date}"
    end
  end

  defp date_cleansing_remove_double_spaces(date) do
    # Remove double spaces " to "5 Oct 2015 13:36:10 +0200"
    if String.contains?(date, "  ") do
      String.replace(date, "  ", " ")
    else
      date
    end
  end

  defp date_cleansing_single_digits(date) do
    # Remove single digits in hours " to "5 Oct 2015 3:36:10 +0200"
    Regex.replace(~r/(.*)\D(\d:\d\d:\d\d)(.*)/, date, "\\g{1} 0\\g{2}\\g{3}")
  end


  def is_maildir?(path) do
    File.dir?(path) &&
    File.dir?(Path.join(path, 'new')) &&
    File.dir?(Path.join(path, 'cur')) &&
    File.dir?(Path.join(path, 'tmp'))
  end

end
