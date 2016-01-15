defmodule EvercamMedia.SessionController do
  use EvercamMedia.Web, :controller

  plug :action

  def create(_conn, %{ "user" => %{ "email" => _email, "password" => _password }}) do
  end

  def delete(_conn, %{ "token" => _token }) do
  end
end
