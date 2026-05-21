alias MykonosBiennale.Accounts
alias MykonosBiennale.Repo
alias MykonosBiennale.Accounts.User

case Accounts.get_user_by_email("thanosv@gmail.com") do
  nil ->
    {:ok, user} =
      %User{}
      |> User.admin_changeset(%{email: "thanosv@gmail.com", role: :admin})
      |> Ecto.Changeset.put_change(:hashed_password, Bcrypt.hash_pwd_salt("changeme123"))
      |> Ecto.Changeset.put_change(:confirmed_at, DateTime.utc_now(:second))
      |> Repo.insert()

    IO.puts("✓ Admin user created: #{user.email} (role: #{user.role})")

  user ->
    user = user |> Ecto.Changeset.change(role: :admin) |> Repo.update!()
    IO.puts("✓ Admin user exists: #{user.email} (role: #{user.role})")
end