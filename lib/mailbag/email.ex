defmodule Mailbag.Email do
  @moduledoc """
  Module for working with single emails within a maildir.
  """
  use Timex

  @doc """
  Returns the content of a single email
  """
  def one(base_path, id, email_address, folder \\ "INBOX") do
    mailbox_path = Mailbag.Maildir.mailbox_path(base_path, email_address, folder)
    dir = "cur"
    tmp_path = mailbox_path |> Path.join("new")
    if File.exists?(tmp_path), do: folder_path = tmp_path; dir="new"
    tmp_path = mailbox_path |> Path.join("cur")
    if File.exists?(tmp_path), do: folder_path = tmp_path; dir="cur"
    email_path = folder_path |> Path.join(id)
    if File.exists?(email_path) do
      email_text = extract_gmime_body(email_path)
      header = Mailbag.Maildir.parse_email_header(folder_path, id)
      {email_text, header, email_path, dir}
    else
      raise "Email path not found: #{email_path}"
    end
  end


  def extract_body(stream) do
    System.cmd
    Stream.drop_while(stream, &(&1 != "\n")) # get header
    |> Enum.to_list
    |> Enum.join("")
  end

  def extract_gmime_body(path) do
    command = Path.expand("./priv/extract_text")
    {email_txt, 1} = System.cmd command, [path]
    IO.inspect email_txt
    email_txt
  end

  def decode_email(path) do
    email = File.read!(Path.expand(path))
    decode_body_structure(%{raw: email})
  end

  def extract_body_from_email(path) do
    IO.puts "______"
    IO.puts Path.expand(path)
    email = File.read!(Path.expand(path))
    body_structure = decode_email(path)
    IO.inspect body_structure
    html_part = extract_html_part(email, body_structure)
    IO.puts "____"
    IO.inspect html_part
    html_part
  end


  def decode_body_structure(%{raw: string}, parent_boundary \\ "", parent_type \\ "", index \\ -1) do
    case Mailbag.Maildir.extract_content_type_and_boundary(string) do
      # multipart
      %{content_type: "multipart/"<>part_type, boundary: boundary, charset: _} ->
        splitted = String.split(string, ~r"\s*--#{boundary}\s*") |> Enum.slice(1..-2)
        # call recursively decode_body_structure, with the remaining string within the boundaries
        # to extract sub-parts. Put the results together into a structure like %{alternative: %{boundary: xx,}}
        # We also need the index to know afterwards which part to extract
        splitted |> Enum.with_index
        |> Enum.map( fn {part, idx} ->
            Dict.put(%{}, String.to_atom(part_type), decode_body_structure(%{raw: part}, boundary, part_type, idx)) end
          )
      # text part, eg plain/html
      %{content_type: "text/"<>text_type, charset: charset} ->
        %{boundary: parent_boundary, content_type: text_type, index: index}
      # attachments (anything else than text or multipart)
      %{content_type: content_type, boundary: _, charset: _} ->
        %{content_type: content_type, boundary: parent_boundary, index: index}
      # attachments (anything else than text or multipart)
      %{content_type: content_type, charset: _} ->
        %{content_type: content_type, boundary: parent_boundary, index: index}
    end
  end
  def decode_body_structure(%{body: _}=mail, _, _, _), do: mail


  def extract_body_from_string(string) do
    body = string |> String.split("\n\n") |> Enum.at(1)
    %{content_type: "text/"<>text_type, charset: charset} = Mailbag.Maildir.extract_content_type_and_boundary(string)
    IO.puts body
    body = case Mailbag.Maildir.extract_content_transfer_encoding(string) do
             "quoted-printable" -> body |> Mailbag.MimeMail.qp_to_binary
             "base64" -> body |> String.replace(~r/\s/,"") |> Base.decode64 |> Mailbag.MimeMail.ok_or("")
             _ -> body
           end

    body = body
    |> Iconv.conv(charset,"utf8")
    |> Mailbag.MimeMail.ok_or(Mailbag.MimeMail.ensure_ascii(body))
    |> Mailbag.MimeMail.ensure_utf8
  end


  def extract_part(body_string, boundary, index) do
    String.split(body_string, ~r"\s*--#{boundary}\s*") |> Enum.at(index)
  end


  def extract_html_part(body_string, body_structure) when is_list(body_structure) do
    x = Enum.map(body_structure,
             fn(x) -> extract_html_part(body_string, x) end)
    x |> List.flatten |> Enum.join
  end

  def extract_html_part(body_string, %{mixed: list}) when is_list(list) do
    extract_html_part(body_string, list)
  end

  def extract_html_part(body_string, %{related: list}) when is_list(list) do
    extract_html_part(body_string, list)
  end

  def extract_html_part(body_string, %{alternative: list}) when is_list(list) do
    extract_html_part(body_string, list)
  end

  def extract_html_part(body_string, %{alternative: alt}) do
    if alt.content_type == "html" do
      part = extract_part(body_string, alt.boundary, alt.index+1)
      extract_body_from_string(part)
    end
  end

  def extract_html_part(body_string, %{related: alt}) do
    if alt.content_type == "html" do
      part = extract_part(body_string, alt.boundary, alt.index+1)
      IO.puts part
      extract_body_from_string(part)
    end
  end

  def extract_html_part(body_string, body_structure) when is_map(body_structure) do end

end
