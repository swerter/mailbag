defmodule Mailbag.Maildir do
  @moduledoc """
  Module for working with maildirs.
  """
  use Timex

  @doc """
  Extract a list of all emails in a maildir folder
  ## Example
      iex> emails = #{__MODULE__}.all("test/data")
  """
  def all(email, folder \\ "INBOX") do
    mailbox_path = mailbox_path(email, folder)
    unless is_maildir?(mailbox_path), do: raise "Not a maildir"
    IO.puts mailbox_path

    {:ok, new_emails} = File.ls(Path.join(mailbox_path, "new"))
    {:ok, current_emails} = File.ls(Path.join(mailbox_path, "cur"))

    Enum.map(new_emails, fn(x) -> parse_email_header(Path.join(mailbox_path, "new"), x, email) end)
  end


  @doc """
  Returns the content of a single email
  """
  def one(email, id, folder \\ "INBOX") do
    mailbox_path = mailbox_path(email, folder)
    path = mailbox_path |> Path.join("new") |> Path.join(id)
    if File.exists?(path), do: email_path = path
    path = mailbox_path |> Path.join("cur") |> Path.join(id)
    if File.exists?(path), do: email_path = path
    IO.inspect email_path
    {:ok, content} = File.read(email_path)
    IO.inspect content
    content
  end


  @doc """
  Extract information from the email header.
  Uses streams to avoid having to read the whole email just to
  extract the header values.
  """
  def parse_email_header(folder_path, email_id, email) do
    email_file_path = Path.join(folder_path, email_id)

    content_stream = File.stream!(email_file_path)
    from = extract_from_header(content_stream, "From")
    if is_nil(Regex.run(~r/.*<(.*)>/, from)) do
      from_email =  from
    else
      from_email = Regex.run(~r/.*<(.*)>/, from) |> List.last
    end
    subject = extract_from_header(content_stream, "Subject")
    date = DateFormat.format!(extract_from_header(content_stream, "Date"), "{ISO}")
    content_type = extract_from_header(content_stream, "Content-Type")
    %{email_address: email, id: email_id, from: from, from_email: from_email, subject: subject, date: date, content_type: content_type}
  end

  # Extracts the field "type" from the email header
  # Example extract_from_header(stream, "From") would return the email sender, eg. "Hans Huber <h.h@blue.com>"
  def extract_from_header(stream, type) do
    IO.puts "hello extract_from_header: #{type}"
    res = Stream.take_while(stream, &(&1 != "\n")) # get header
    |> Stream.filter(&(Regex.match?(~r/^\S*?#{type}:.*\n/, &1))) |> Enum.at(0) # extract from header the field
    if res == 0 do # if not found, return empty string
      ""
    else # if found, return the field
      res
      |> String.split("#{type}:")
      |> List.last
      |> String.strip
    end
  end


  def is_maildir?(path) do
    File.dir?(path) &&
    File.dir?(Path.join(path, 'new')) &&
    File.dir?(Path.join(path, 'cur')) &&
    File.dir?(Path.join(path, 'tmp'))
  end

  def mailbox_path(email, folder \\ "INBOX") do
    base_path    = Application.get_env(:migadu, Migadu.Maildir)[:base_path]
    [user_name, domain] = String.split(email, "@")

    base_path
      |> Path.join(domain)
      |> Path.join(user_name)
      |> Path.join(folder)
      |> Path.expand
  end
end
