# Copied from https://github.com/awetzel/mailibex
defmodule Mailbag.MimeMail do
  def ok_or({:ok,res},_), do: res
  def ok_or(_,default), do: default

  def ensure_ascii(bin), do:
  Kernel.to_string(for(<<c<-bin>>, (c<127 and c>31) or c in [?\t,?\r,?\n], do: c))
  def ensure_utf8(bin) do
    bin
    |> String.chunk(:printable)
    |> Enum.filter(&String.printable?/1)
    |> Kernel.to_string
  end
end


defmodule Mailbag.MimeMail.Words do
    def word_decode(str) do
    str |> String.split(~r/\s+/) |> Enum.map(&single_word_decode/1) |> Enum.join |> String.rstrip
  end

  def single_word_decode("=?"<>rest = str) do
    case String.split(rest,"?") do
      [enc,"Q",enc_str,"="] ->
        str = q_to_binary(enc_str,[])
         Mailbag.MimeMail.ok_or(Iconv.conv(str,enc,"utf8"), Mailbag.MimeMail.ensure_ascii(str))
      [enc,"B",enc_str,"="] ->
        str = Base.decode64(enc_str) |> Mailbag.MimeMail.ok_or(enc_str)
         Mailbag.MimeMail.ok_or(Iconv.conv(str,enc,"utf8"), Mailbag.MimeMail.ensure_ascii(str))
      _ -> "#{str} "
    end
  end
  def single_word_decode(str), do: "#{str} "

  def q_to_binary("_"<>rest,acc), do:
    q_to_binary(rest,[?\s|acc])
  def q_to_binary(<<?=,x1,x2>><>rest,acc), do:
    q_to_binary(rest,[<<x1,x2>> |> String.upcase |> Base.decode16! | acc])
  def q_to_binary(<<c,rest::binary>>,acc), do:
    q_to_binary(rest,[c | acc])
  def q_to_binary("",acc), do:
    (acc |> Enum.reverse |> IO.iodata_to_binary)
end


defmodule Iconv do
  @on_load :init
  def init, do: :erlang.load_nif('#{:code.priv_dir(:mailbag)}/Elixir.Iconv_nif',0)
  @doc "iconv interface, from and to are encoding supported by iconv"
  def conv(_str,_from,_to), do: exit(:nif_library_not_loaded)
end
