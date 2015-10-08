defmodule MaildirTests do
  use ExUnit.Case, async: true
  doctest Mailbag.Maildir


  test "list all emails in a maildir and check subjects" do
    maildir_path = "test/data/INBOX"
    emails = Mailbag.Maildir.all(maildir_path)
    subjects = Enum.map(emails, &(&1.subject))
    assert Enum.any?(subjects, &(String.match?(&1,~r/15% Rabatt auf Flyer & Falzflyer/)))
  end

  test "list all emails in a maildir and check subjects (with encoding)" do
    maildir_path = "test/data/INBOX"
    emails = Mailbag.Maildir.all(maildir_path)
    subjects = Enum.map(emails, &(&1.subject))
    assert Enum.any?(subjects, &(String.match?(&1,~r/¿TE IMAGINAS ENVIOS EN 24 HORAS?/)))
  end

end
