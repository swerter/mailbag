defmodule MaildirTests do
  use ExUnit.Case, async: true
  doctest Mailbag.Maildir


  test "list all emails in a maildir" do
    maildir_path = "test/data/"
    emails = Mailbag.Maildir.all(maildir_path)
  end

end
