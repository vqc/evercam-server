defmodule UserTest do
  use EvercamMedia.ModelCase

  setup do
    {:ok, params: %{username: "johndoe", password: "johndoe", firstname: "John", lastname: "Doe"}}
  end

  test "email validation is correct", %{params: params} do
    refute User.changeset(%User{}, params).valid?
    refute User.changeset(%User{}, Map.merge(params, %{email: nil})).valid?
    refute User.changeset(%User{}, Map.merge(params, %{email: ""})).valid?
    refute User.changeset(%User{}, Map.merge(params, %{email: "spa ces@example.com"})).valid?

    assert User.changeset(%User{}, Map.merge(params, %{email: "regular@example.com"})).valid?
    assert User.changeset(%User{}, Map.merge(params, %{email: "no_dot_in_domain@example"})).valid?
    assert User.changeset(%User{}, Map.merge(params, %{email: "unicode@はじめよう.みんな"})).valid?
    assert User.changeset(%User{}, Map.merge(params, %{email: "plus+-minus@example.com"})).valid?
  end
end
