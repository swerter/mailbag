defmodule Maildir.MaildirTests do
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


  test "mailcleansing" do
    clean_date = Mailbag.Maildir.date_cleansing("Mon, 5 Oct 2015 13:36:10 +0200 (CEST)")
    assert {:ok, _} = Timex.DateFormat.parse(clean_date, "{RFC1123}")
    clean_date = Mailbag.Maildir.date_cleansing("5 Oct 2015 13:36:10 +0200 (CEST)")
    assert {:ok, _} = Timex.DateFormat.parse(clean_date, "{RFC1123}")
    clean_date = Mailbag.Maildir.date_cleansing("Thu,  1 Oct 2015 20:32:09 GMT")
    assert {:ok, _} = Timex.DateFormat.parse(clean_date, "{RFC1123}")
    clean_date = Mailbag.Maildir.date_cleansing("Wed, 12 Aug 2015 9:34:50 +0200")
    assert {:ok, _} = Timex.DateFormat.parse(clean_date, "{RFC1123}")
    clean_date = Mailbag.Maildir.date_cleansing("Thu, 5 Feb 2015 09:50:04 -0500")
    assert {:ok, _} = Timex.DateFormat.parse(clean_date, "{RFC1123}")
  end

end
