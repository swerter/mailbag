defmodule Mailbag.EmailTests do
  use ExUnit.Case, async: true
  doctest Mailbag.Email


  test "get all headers of a maildir" do
    maildir_path = "test/data/test.com/aaa/INBOX/cur"
    {:ok, email_pathes} = File.ls(maildir_path)
    email_pathes = Enum.map(email_pathes, fn(x) -> Path.join(maildir_path, x) end)
    emails = Mailbag.Email.extract_gmime_headers(email_pathes)
    assert Enum.count(emails) == 3
  end


  test "get the headers of an email" do
    maildir_path = "test/data/test.com/aaa/INBOX/cur/1443716368_0.10854.brumbrum,U=605,FMD5=7e33429f656f1e6e9d79b29c3f82c57e:2,"
    email = Mailbag.Email.extract_gmime_headers(maildir_path)
    res = %{date: "Thu 24 Sep 2015 01:55:49 PM CEST",
  message_id: "NM658B0B631029381DDvsncf@newsletter.voyages-sncf.com",
  path: "test/data/test.com/aaa/INBOX/cur/1443716368_0.10854.brumbrum,U=605,FMD5=7e33429f656f1e6e9d79b29c3f82c57e:2,",
  recipients_bcc: [], recipients_cc: [], recipients_to: ["blue@tester.ch"],
  reply_to: "Voyages-sncf.com <bonsplans@newsletter.voyages-sncf.com>",
  sender: "Voyages-sncf.com <bonsplans@newsletter.voyages-sncf.com>",
  sort_date: "20150924135549",
  subject: "PETITS PRIX : 2 millions de billets a prix Prem's avec TGV et Intercites !"}
    assert email == res
    assert res.subject == email.subject
  end


  test "get the structure of an email" do
    maildir_path = "test/data/test.com/aaa/INBOX/cur/1443716368_0.10854.brumbrum,U=605,FMD5=7e33429f656f1e6e9d79b29c3f82c57e:2,"
    email = Mailbag.Email.extract_gmime_body_structure(maildir_path)
    res = %{multipart: %{entries: [%{type: "plain"}, %{type: "html"}], type: "multipart/alternative"}}
    assert email == res
  end

end
