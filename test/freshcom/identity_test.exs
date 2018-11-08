defmodule Freshcom.IdentityTest do
  use Freshcom.IntegrationCase

  alias Freshcom.Identity

  defp register_user(opts \\ []) do
    req = %Request{
      fields: %{
        name: Faker.Name.name(),
        username: Faker.Internet.user_name(),
        email: Faker.Internet.email(),
        password: "test1234",
        is_term_accepted: true
      },
      include: opts[:include]
    }

    {:ok, %{data: user}} = Identity.register_user(req)

    user
  end

  defp add_user(account_id) do
    req = %Request{
      account_id: account_id,
      fields: %{
        "username" => Faker.Internet.user_name(),
        "role" => "developer",
        "password" => Faker.String.base64(12)
      },
      _role_: "sysdev"
    }

    {:ok, %{data: user}} = Identity.add_user(req)

    user
  end

  defp get_urt(account_id, user_id) do
    req = %Request{
      account_id: account_id,
      identifiers: %{"user_id" => user_id},
      _role_: "system"
    }

    {:ok, %{data: urt}} = Identity.get_refresh_token(req)

    urt
  end

  describe "register_user/1" do
    test "with invalid request" do
      assert {:error, %{errors: errors}} = Identity.register_user(%Request{})
      assert length(errors) > 0
    end

    test "with valid request" do
      req = %Request{
        fields: %{
          "name" => Faker.Name.name(),
          "username" => Faker.Internet.user_name(),
          "email" => Faker.Internet.email(),
          "password" => Faker.String.base64(12),
          "is_term_accepted" => true
        }
      }

      assert {:ok, %{data: data}} = Identity.register_user(req)
      assert data.id
    end
  end

  describe "add_user/1" do
    test "with invalid request" do
      assert {:error, %{errors: errors}} = Identity.add_user(%Request{})
      assert length(errors) > 0
    end

    test "with unauthorized requester" do
      req = %Request{
        account_id: uuid4(),
        fields: %{
          "username" => Faker.Internet.user_name(),
          "role" => "developer",
          "password" => Faker.String.base64(12)
        }
      }
      assert {:error, :access_denied} = Identity.add_user(req)
    end

    test "with valid request" do
      requester = register_user()
      account_id = requester.default_account_id

      req = %Request{
        requester_id: requester.id,
        account_id: account_id,
        fields: %{
          "username" => Faker.Internet.user_name(),
          "role" => "developer",
          "password" => Faker.String.base64(12)
        },
        include: "refresh_tokens"
      }

      assert {:ok, %{data: data}} = Identity.add_user(req)
      assert data.id
      assert data.username == req.fields["username"]
      assert length(data.refresh_tokens) == 2
    end
  end

  describe "update_user_info/1" do
    test "with missing identifiers" do
      assert {:error, %{errors: errors}} = Identity.update_user_info(%Request{})
      assert length(errors) > 1
    end

    test "with invalid identifiers" do
      req = %Request{identifiers: %{"id" => uuid4()}}
      assert {:error, :not_found} = Identity.update_user_info(req)
    end

    test "with unauthorize requester" do
      requester = register_user()

      req = %Request{identifiers: %{"id" => requester.id}}
      assert {:error, :access_denied} = Identity.update_user_info(req)
    end

    test "with valid request" do
      requester = register_user()

      new_name = Faker.Name.name()
      req = %Request{
        requester_id: requester.id,
        account_id: requester.default_account_id,
        identifiers: %{"id" => requester.id},
        fields: %{"name" => new_name}
      }

      assert {:ok, %{data: data}} = Identity.update_user_info(req)
      assert data.name == new_name
    end
  end

  describe "list_user/1" do
    test "with unauthorized requester" do
      req = %Request{}

      assert {:error, :access_denied} = Identity.list_user(req)
    end

    test "with valid request" do
      requester = register_user()
      add_user(requester.default_account_id)
      add_user(requester.default_account_id)

      req = %Request{
        requester_id: requester.id,
        account_id: requester.default_account_id
      }

      assert {:ok, %{data: data}} = Identity.list_user(req)
      assert length(data) == 2
    end
  end

  describe "get_user/1" do
    test "with unauthorized requester" do
      req = %Request{}

      assert {:error, :access_denied} = Identity.get_user(req)
    end

    test "target non existing user" do
      requester = register_user()
      add_user(requester.default_account_id)

      req = %Request{
        requester_id: requester.id,
        account_id: requester.default_account_id,
        identifiers: %{"id" => uuid4()}
      }

      assert {:error, :not_found} = Identity.get_user(req)
    end

    test "target user of another account" do
      requester = register_user()
      other_user = register_user()
      target_user = add_user(other_user.default_account_id)

      req = %Request{
        requester_id: requester.id,
        account_id: requester.default_account_id,
        identifiers: %{"id" => target_user.id}
      }

      assert {:error, :not_found} = Identity.get_user(req)
    end

    test "target user with invalid password" do
      user = register_user()

      req = %Request{
        identifiers: %{"username" => user.username, "password" => "invalid"},
        _role_: "system"
      }

      assert {:error, :not_found} = Identity.get_user(req)
    end

    test "target user with valid password" do
      user = register_user()

      req = %Request{
        identifiers: %{"username" => user.username, "password" => "test1234"},
        _role_: "system"
      }

      assert {:ok, %{data: data}} = Identity.get_user(req)
      assert data.id == user.id
    end

    test "target valid user" do
      requester = register_user()
      user = add_user(requester.default_account_id)

      req = %Request{
        requester_id: requester.id,
        account_id: requester.default_account_id,
        identifiers: %{"id" => user.id}
      }

      assert {:ok, %{data: data}} = Identity.get_user(req)
      assert data.id == user.id
    end
  end

  describe "get_refresh_token/1" do
    test "with unauthorized requester" do
      req = %Request{}

      assert {:error, :access_denied} = Identity.get_refresh_token(req)
    end

    test "with valid request" do
      user = register_user()
      account_id = user.default_account_id

      req = %Request{
        account_id: account_id,
        identifiers: %{
          "user_id" => user.id
        },
        _role_: "system"
      }

      assert {:ok, %{data: data}} = Identity.get_refresh_token(req)
      assert data.account_id == account_id
      assert data.user_id == user.id
      assert data.prefixed_id
    end
  end

  describe "exchange_refresh_token/1" do
    test "with no refresh token given" do
      req = %Request{}

      assert {:error, :not_found} = Identity.exchange_refresh_token(req)
    end

    test "target account with no user refresh token" do
      requester = register_user()
      %{default_account_id: target_account_id} = register_user()
      urt = get_urt(requester.default_account_id, requester.id)

      req = %Request{
        account_id: target_account_id,
        identifiers: %{"id" => urt.prefixed_id}
      }

      assert {:error, :not_found} = Identity.exchange_refresh_token(req)
    end

    test "target corresponding test account" do
      requester = register_user(include: "default_account")
      urt = get_urt(requester.default_account_id, requester.id)
      test_account_id = requester.default_account.test_account_id

      req = %Request{
        account_id: test_account_id,
        identifiers: %{"id" => urt.prefixed_id}
      }

      assert {:ok, %{data: data}} = Identity.exchange_refresh_token(req)
      assert data.prefixed_id
      assert data.account_id == test_account_id
      assert data.user_id == requester.id
    end

    test "target the same account" do
      requester = register_user(include: "default_account")
      account_id = requester.default_account_id
      urt = get_urt(account_id, requester.id)

      req = %Request{
        account_id: account_id,
        identifiers: %{"id" => urt.prefixed_id}
      }

      assert {:ok, %{data: data}} = Identity.exchange_refresh_token(req)
      assert data.prefixed_id
      assert data.id == urt.id
    end
  end

  describe "get_account/1" do
    test "with unauthorized requester" do
      req = %Request{}

      assert {:error, :access_denied} = Identity.get_account(req)
    end

    test "with valid request" do
      user = register_user()

      req = %Request{
        requester_id: user.id,
        account_id: user.default_account_id
      }

      assert {:ok, %{data: data}} = Identity.get_account(req)
      assert data.id == user.default_account_id
    end
  end
end