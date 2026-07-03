defmodule Mix.Tasks.Mb.Users do
  use Mix.Task

  @shortdoc "Create users and manage roles"

  @moduledoc """
  Manage users from the command line. Works with local or remote databases.

  ## Usage

      # Local dev server (default DB):
      mix mb.users list
      mix mb.users create user@example.com password123 admin
      mix mb.users set-role user@example.com staff
      mix mb.users reset-password user@example.com newpassword123

      # Remote database via DATABASE_URL (SSL auto-enabled):
      DATABASE_URL=ecto://USER:PASS@HOST/DATABASE mix mb.users list

      # Disable SSL explicitly for a remote database:
      DATABASE_URL=ecto://USER:PASS@HOST/DATABASE DATABASE_SSL=false mix mb.users list

  SSL is automatically enabled when DATABASE_URL points to a non-local host.
  Set DATABASE_SSL=false to disable this.

  ## Roles

    * admin
    * staff
    * participant
  """

  alias MykonosBiennale.Accounts
  alias MykonosBiennale.Repo
  alias MykonosBiennale.Accounts.User

  def run(args) do
    start_repo()

    valid_roles = User.roles()

    case args do
      ["create", email, password, role_str] ->
        role = parse_role(role_str, valid_roles)
        create_user(email, password, role)

      ["set-role", email, role_str] ->
        role = parse_role(role_str, valid_roles)
        set_role(email, role)

      ["reset-password", email, password] ->
        reset_password(email, password)

      ["list"] ->
        list_users()

      _ ->
        Mix.shell().info("""
        Usage: mix mb.users <command> [args]

        Commands:
          create <email> <password> <role>     Create a new user (auto-confirmed)
          set-role <email> <role>               Change a user's role
          reset-password <email> <password>     Reset a user's password
          list                                  List all users

        Roles: admin, staff, participant

        Set DATABASE_URL to connect to a remote database.
        """)
    end
  end

  defp start_repo do
    repo_opts =
      Application.get_env(:mykonos_biennale, Repo, [])
      |> Keyword.put(:pool_size, 2)
      |> Keyword.put(:queue_target, 5000)
      |> maybe_add_ssl()

    Application.put_env(:mykonos_biennale, Repo, repo_opts)

    [:crypto, :logger, :bcrypt_elixir, :ecto_sql, :postgrex]
    |> Enum.each(&Application.ensure_all_started/1)

    Repo.start_link()
  end

  defp maybe_add_ssl(opts) do
    url = System.get_env("DATABASE_URL")

    cond do
      System.get_env("DATABASE_SSL") == "false" ->
        Keyword.put(opts, :ssl, false)

      url != nil && !String.contains?(url, "localhost") && !String.contains?(url, "127.0.0.1") ->
        Keyword.put(opts, :ssl, verify: :verify_none)

      true ->
        opts
    end
  end

  defp parse_role(role_str, valid_roles) do
    role = String.to_atom(role_str)

    unless role in valid_roles do
      Mix.shell().error("Invalid role: #{role_str}. Valid roles: #{inspect(valid_roles)}")
      Mix.raise("Invalid role")
    end

    role
  end

  defp create_user(email, password, role) do
    if String.length(password) < 12 do
      Mix.raise("Password must be at least 12 characters")
    end

    if Accounts.get_user_by_email(email) do
      Mix.raise("User already exists: #{email}")
    end

    user =
      %User{}
      |> User.admin_changeset(%{email: email, role: role})
      |> Ecto.Changeset.put_change(:hashed_password, Bcrypt.hash_pwd_salt(password))
      |> Ecto.Changeset.put_change(:confirmed_at, DateTime.utc_now(:second))
      |> Repo.insert!()

    Mix.shell().info("User created: #{user.email} (role: #{user.role})")
  end

  defp set_role(email, role) do
    user = Accounts.get_user_by_email(email)

    unless user do
      Mix.raise("User not found: #{email}")
    end

    user = user |> Ecto.Changeset.change(role: role) |> Repo.update!()
    Mix.shell().info("Role updated: #{user.email} -> #{role}")
  end

  defp reset_password(email, password) do
    if String.length(password) < 12 do
      Mix.raise("Password must be at least 12 characters")
    end

    user = Accounts.get_user_by_email(email)

    unless user do
      Mix.raise("User not found: #{email}")
    end

    user =
      user
      |> Ecto.Changeset.change(hashed_password: Bcrypt.hash_pwd_salt(password))
      |> Repo.update!()

    Mix.shell().info("Password reset for: #{user.email}")
  end

  defp list_users do
    users = Accounts.list_users()

    if users == [] do
      Mix.shell().info("No users found")
    else
      Mix.shell().info(String.pad_trailing("Email", 40) <> "Role")
      Mix.shell().info(String.duplicate("-", 50))

      for user <- users do
        Mix.shell().info(String.pad_trailing(user.email, 40) <> "#{user.role}")
      end
    end
  end
end
