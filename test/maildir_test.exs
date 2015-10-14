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

  test "emails sorted" do
    maildir_path = __DIR__ |> Path.join("..") |> Path.join("test/data/test.com/aaa/") |> Path.expand
    emails = Mailbag.Maildir.all(maildir_path, :date)
    last_date = "22221212230000"
    Enum.each(emails, fn(x) -> assert(x.sort_date < last_date); last_date = x.sort_date end)
  end

  test "emails sorted inverse" do
    maildir_path = __DIR__ |> Path.join("..") |> Path.join("test/data/test.com/aaa/") |> Path.expand
    emails = Mailbag.Maildir.all(maildir_path, :date_inv)
    last_date = "22221212230000"
    Enum.each(emails, fn(x) -> assert(x.sort_date < last_date); last_date = x.sort_date end)
  end


  test "emails sorted by subject" do
    maildir_path = __DIR__ |> Path.join("..") |> Path.join("test/data/test.com/aaa/") |> Path.expand
    emails = Mailbag.Maildir.all(maildir_path, :subject)
    last_subject = ""
    Enum.each(emails, fn(x) -> assert(x.subject > last_subject); last_subject = x.subject end)
  end

  test "emails sorted  by subject inverse" do
    maildir_path = __DIR__ |> Path.join("..") |> Path.join("test/data/test.com/aaa/") |> Path.expand
    emails = Mailbag.Maildir.all(maildir_path, :subject_inv)
    last_subject = to_string(<<255>>)
    Enum.each(emails, fn(x) -> assert(x.subject < last_subject); last_subject = x.subject end)
  end
end
