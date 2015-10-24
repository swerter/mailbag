defmodule Mailbag.Email do
  @moduledoc """
  Module for working with single emails within a maildir.
  """
  use Timex

  @doc """
  Returns the content of a single email
  """
  def one(base_path, email_address, id, folder \\ ".") do
    email_path = Mailbag.Email.email_path(base_path, email_address, id, folder)
    email_text = extract_gmime_text(email_path)
    IO.puts email_text
    headers = Mailbag.Email.extract_gmime_headers(email_path)
    IO.inspect headers
    {email_text, headers, email_path}
  end


  @doc """
  On a mailserver, the email is often stored as followes for
  the user aaa@bbb.com
  /bbb.com/aaa/{INBOX,Drafts,...}
  email_path converts the email to such a path.

      Mailbag.Email.email_path("/x/test/data", "aaa@test.com", "1443716368_0.10854.brumbrum,U=605,FMD5=7e33429f656f1e6e9d79b29c3f82c57e:2,")
      "/x/bbb.com/aaa/cur/1443716371_0.10854.brumbrum,U=609,FMD5=7e33429f656f1e6e9d79b29c3f82c57e:2,"

  """
  def email_path(base_path, email, id, folder \\ ".") do
    [user_name, domain] = String.split(email, "@")

    folder_path = base_path
    |> Path.join(domain)
    |> Path.join(user_name)
    |> Path.join(folder)
    |> Path.expand

    if File.exists?(path = folder_path |> Path.join("cur") |> Path.join(id)) do
      path
    else
    if File.exists?(path = folder_path |> Path.join("new") |> Path.join(id)) do
      path
    else
      raise "Path does not exist: #{path}; email_id: #{id}"
    end
    end
  end


  @doc """
  Extracts the text part of an email. If there is an alternative/html part, that one
  is returned. If not, the plain text is passed through a basic html filter and
  returned.
  ## Example
      iex> Mailbag.Email.extract_gmime_text("./test/data/test.com/aaa/cur/1443716368_0.10854.brumbrum,U=605,FMD5=7e33429f656f1e6e9d79b29c3f82c57e:2,")
      "xx"


  """
  def extract_gmime_text(path) do
    command = Path.dirname(__DIR__) |> Path.join("..") |> Path.join("priv") |> Path.join("extract_text") |> Path.expand
    # %{out: email_text, status: 1} = Porcelain.exec command, [path]
    unless is_list(path), do: path = [path]
    {email_text, 1} = System.cmd command, path
    email_text
  end


  @doc """
  Extracts the text part of an email. If there is an alternative/html part, that one
  is returned. If not, the plain text is passed through a basic html filter and
  returned.
  ## Example
      iex> Mailbag.Email.extract_gmime_body_structure("./test/data/test.com/aaa/cur/1443716368_0.10854.brumbrum,U=605,FMD5=7e33429f656f1e6e9d79b29c3f82c57e:2,")
      %{multipart: %{entries: [%{type: "plain"}, %{type: "html"}], type: "multipart/alternative"}}
  """
  def extract_gmime_body_structure(path) do
    command = Path.dirname(__DIR__) |> Path.join("..") |> Path.join("priv") |> Path.join("extract_structure") |> Path.expand
    # %{out: email_structure, status: 1} = Porcelain.exec command, [path]
    unless is_list(path), do: path = [path]
    {email_structure, 1} = System.cmd command, path
    {res, []} = Code.eval_string(email_structure)
    res
  end


  @doc """
  Extracts the headers of an email
  ## Example
  %{date: "Thu 24 Sep 2015 01:55:49 PM CEST",
  message_id: "NM658B0B631029381DDvsncf@newsletter.voyages-sncf.com",
  path: "./test/data/test.com/aaa/cur/1443716368_0.10854.brumbrum,U=605,FMD5=7e33429f656f1e6e9d79b29c3f82c57e:2,",
  recipients_bcc: [], recipients_cc: [], recipients_to: ["blue@tester.ch"],
  reply_to: "Voyages-sncf.com <bonsplans@newsletter.voyages-sncf.com>",
  sender: "Voyages-sncf.com <bonsplans@newsletter.voyages-sncf.com>",
  sort_date: "20150924135549",
  subject: "PETITS PRIX : 2 millions de billets a prix Prem's avec TGV et Intercites !"}
  """
  def extract_gmime_headers(path) do
    command = Path.dirname(__DIR__)  |> Path.join("..") |> Path.join("priv") |> Path.join("extract_headers") |> Path.expand
    # %{out: email_headers, status: 1} = Porcelain.exec command, [path]
    unless is_list(path), do: path = [path]
    {email_headers, 0} = System.cmd command, path
    {res, []} = Code.eval_string(email_headers)
    res
  end


  @doc """
  If an email has been seen, it's moved from the 'new' directory to the
  'cur' directory within the maildir folder.
  """
  def seen(path) do
  end


  @doc """
  Returns the id, that is the filename of the email
  'cur' directory within the maildir folder.
  Example:
      iex> Mailbag.Email.id("./test/data/test.com/aaa/cur/1443716368_0.10854.brumbrum,U=605,FMD5=7e33429f656f1e6e9d79b29c3f82c57e:2,")
      "1443716368_0.10854.brumbrum,U=605,FMD5=7e33429f656f1e6e9d79b29c3f82c57e:2,"
  """
  def id(path) do
    Path.basename(path)
  end


  @doc """
  Returns whether the email has been seen.
  Inernally, that means if the email is in the 'cur' directory within the maildir folder.
  Example:
      iex> Mailbag.Email.seen?("./test/data/test.com/aaa/cur/1443716368_0.10854.brumbrum,U=605,FMD5=7e33429f656f1e6e9d79b29c3f82c57e:2,")
      true
  """
  def seen?(path) do
    (Path.dirname(path) |> Path.basename) == "cur"
  end


  @doc """
  Returns whether the email is new.
  Inernally, that means if the email is in the 'new' directory within the maildir folder.
  Example:
      iex> Mailbag.Email.new?("./test/data/test.com/aaa/cur/1443716368_0.10854.brumbrum,U=605,FMD5=7e33429f656f1e6e9d79b29c3f82c57e:2,")
      false
  """
  def new?(path) do
    (Path.dirname(path) |> Path.basename) == "new"
  end


  @doc """
  Returns the base_path of a path, that is without the filename and
  without the 'cur' or 'tmp' directory.
  Example:
      iex> Mailbag.Email.base_path("./test/data/test.com/aaa/cur/1443716368_0.10854.brumbrum,U=605,FMD5=7e33429f656f1e6e9d79b29c3f82c57e:2,")
      "./test/data/test.com/aaa"
  """
  def base_path(path) do
    Path.dirname(path) |> Path.dirname
  end

  # def extract_body(stream) do
  #   System.cmd
  #   Stream.drop_while(stream, &(&1 != "\n")) # get header
  #   |> Enum.to_list
  #   |> Enum.join("")
  # end

  # def decode_email(path) do
  #   email = File.read!(Path.expand(path))
  #   decode_body_structure(%{raw: email})
  # end

  # def extract_body_from_email(path) do
  #   IO.puts "______"
  #   IO.puts Path.expand(path)
  #   email = File.read!(Path.expand(path))
  #   body_structure = decode_email(path)
  #   IO.inspect body_structure
  #   html_part = extract_html_part(email, body_structure)
  #   IO.puts "____"
  #   IO.inspect html_part
  #   html_part
  # end


  # def decode_body_structure(%{raw: string}, parent_boundary \\ "", parent_type \\ "", index \\ -1) do
  #   case Mailbag.Maildir.extract_content_type_and_boundary(string) do
  #     # multipart
  #     %{content_type: "multipart/"<>part_type, boundary: boundary, charset: _} ->
  #       splitted = String.split(string, ~r"\s*--#{boundary}\s*") |> Enum.slice(1..-2)
  #       # call recursively decode_body_structure, with the remaining string within the boundaries
  #       # to extract sub-parts. Put the results together into a structure like %{alternative: %{boundary: xx,}}
  #       # We also need the index to know afterwards which part to extract
  #       splitted |> Enum.with_index
  #       |> Enum.map( fn {part, idx} ->
  #           Dict.put(%{}, String.to_atom(part_type), decode_body_structure(%{raw: part}, boundary, part_type, idx)) end
  #         )
  #     # text part, eg plain/html
  #     %{content_type: "text/"<>text_type, charset: charset} ->
  #       %{boundary: parent_boundary, content_type: text_type, index: index}
  #     # attachments (anything else than text or multipart)
  #     %{content_type: content_type, boundary: _, charset: _} ->
  #       %{content_type: content_type, boundary: parent_boundary, index: index}
  #     # attachments (anything else than text or multipart)
  #     %{content_type: content_type, charset: _} ->
  #       %{content_type: content_type, boundary: parent_boundary, index: index}
  #   end
  # end
  # def decode_body_structure(%{body: _}=mail, _, _, _), do: mail


  # def extract_body_from_string(string) do
  #   body = string |> String.split("\n\n") |> Enum.at(1)
  #   %{content_type: "text/"<>text_type, charset: charset} = Mailbag.Maildir.extract_content_type_and_boundary(string)
  #   IO.puts body
  #   body = case Mailbag.Maildir.extract_content_transfer_encoding(string) do
  #            "quoted-printable" -> body |> Mailbag.MimeMail.qp_to_binary
  #            "base64" -> body |> String.replace(~r/\s/,"") |> Base.decode64 |> Mailbag.MimeMail.ok_or("")
  #            _ -> body
  #          end

  #   body = body
  #   |> Iconv.conv(charset,"utf8")
  #   |> Mailbag.MimeMail.ok_or(Mailbag.MimeMail.ensure_ascii(body))
  #   |> Mailbag.MimeMail.ensure_utf8
  # end


  # def extract_part(body_string, boundary, index) do
  #   String.split(body_string, ~r"\s*--#{boundary}\s*") |> Enum.at(index)
  # end


  # def extract_html_part(body_string, body_structure) when is_list(body_structure) do
  #   x = Enum.map(body_structure,
  #            fn(x) -> extract_html_part(body_string, x) end)
  #   x |> List.flatten |> Enum.join
  # end

  # def extract_html_part(body_string, %{mixed: list}) when is_list(list) do
  #   extract_html_part(body_string, list)
  # end

  # def extract_html_part(body_string, %{related: list}) when is_list(list) do
  #   extract_html_part(body_string, list)
  # end

  # def extract_html_part(body_string, %{alternative: list}) when is_list(list) do
  #   extract_html_part(body_string, list)
  # end

  # def extract_html_part(body_string, %{alternative: alt}) do
  #   if alt.content_type == "html" do
  #     part = extract_part(body_string, alt.boundary, alt.index+1)
  #     extract_body_from_string(part)
  #   end
  # end

  # def extract_html_part(body_string, %{related: alt}) do
  #   if alt.content_type == "html" do
  #     part = extract_part(body_string, alt.boundary, alt.index+1)
  #     IO.puts part
  #     extract_body_from_string(part)
  #   end
  # end

  # def extract_html_part(body_string, body_structure) when is_map(body_structure) do end

end
