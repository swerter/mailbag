defmodule Maildir.MaildirTests do
  use ExUnit.Case, async: true
  doctest Mailbag.Maildir


  test "list all emails in a maildir and check subjects" do
    maildir_path = __DIR__ |> Path.join("..") |> Path.join("test/data/test.com/aaa/") |> Path.expand
    emails = Mailbag.Maildir.all(maildir_path)
    subjects = Enum.map(emails, &(&1.subject))
    assert Enum.any?(subjects, &(String.match?(&1,~r/15% Rabatt auf Flyer & Falzflyer/)))
  end

  test "list all emails in a maildir and check subjects (with encoding)" do
    maildir_path = __DIR__ |> Path.join("..") |> Path.join("test/data/test.com/aaa/") |> Path.expand
    emails = Mailbag.Maildir.all(maildir_path)
    subjects = Enum.map(emails, &(&1.subject))
    assert Enum.any?(subjects, &(String.match?(&1,~r/¿TE IMAGINAS ENVIOS EN 24 HORAS?/)))
  end

  test "list all emails in a maildir " do
    maildir_path = __DIR__ |> Path.join("..") |> Path.join("test/data/test.com/aaa/") |> Path.expand
    emails = Mailbag.Maildir.all(maildir_path)
  end


  test "mailbox_path " do
    base_path = "/aaa/bbb/"
    email = "hum@blum.com"
    folder = ".Drafts"
    mailbox_path = Mailbag.Maildir.mailbox_path(base_path, email, folder)
    assert mailbox_path == "/aaa/bbb/blum.com/hum/.Drafts"
  end

end
