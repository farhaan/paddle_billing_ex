defmodule PaddleBilling.Customer do
  @moduledoc """
  Manage customers in Paddle Billing.

  Customers represent individuals or businesses that purchase your products.
  They contain contact information, marketing preferences, and custom metadata.
  Customers can have multiple addresses and be associated with subscriptions and transactions.
  """

  alias PaddleBilling.{Client, Error}

  @type t :: %__MODULE__{
          id: String.t(),
          name: String.t() | nil,
          email: String.t(),
          locale: String.t() | nil,
          status: String.t(),
          custom_data: map() | nil,
          created_at: String.t(),
          updated_at: String.t(),
          marketing_consent: boolean(),
          import_meta: map() | nil
        }

  defstruct [
    :id,
    :name,
    :email,
    :locale,
    :status,
    :custom_data,
    :created_at,
    :updated_at,
    :marketing_consent,
    :import_meta
  ]

  @type list_params :: %{
          optional(:after) => String.t(),
          optional(:id) => [String.t()],
          optional(:email) => String.t(),
          optional(:status) => [String.t()],
          optional(:per_page) => pos_integer(),
          optional(:include) => [String.t()],
          optional(:search) => String.t()
        }

  @type create_params :: %{
          :email => String.t(),
          optional(:name) => String.t(),
          optional(:locale) => String.t(),
          optional(:custom_data) => map()
        }

  @type update_params :: %{
          optional(:name) => String.t(),
          optional(:email) => String.t(),
          optional(:locale) => String.t(),
          optional(:marketing_consent) => boolean(),
          optional(:custom_data) => map(),
          optional(:status) => String.t()
        }

  @doc """
  Lists all customers.

  ## Parameters

  * `:after` - Return customers after this customer ID (pagination)
  * `:id` - Filter by specific customer IDs
  * `:email` - Filter by email address
  * `:status` - Filter by status (active, archived)
  * `:per_page` - Number of results per page (max 200)
  * `:include` - Include related resources (addresses, businesses)
  * `:search` - Search customers by name or email

  ## Examples

      PaddleBilling.Customer.list()
      {:ok, [%PaddleBilling.Customer{}, ...]}

      PaddleBilling.Customer.list(%{
        email: "user@example.com",
        status: ["active"],
        include: ["addresses"],
        per_page: 50
      })
      {:ok, [%PaddleBilling.Customer{}, ...]}

      # Search for customers
      PaddleBilling.Customer.list(%{search: "john doe"})
      {:ok, [%PaddleBilling.Customer{name: "John Doe"}, ...]}
  """
  @spec list(list_params(), keyword()) :: {:ok, [t()]} | {:error, Error.t()}
  def list(params \\ %{}, opts \\ []) do
    case Client.get("/customers", params, opts) do
      {:ok, customers} when is_list(customers) ->
        {:ok, Enum.map(customers, &from_api/1)}

      {:ok, response} ->
        {:error, Error.from_response(response)}

      error ->
        error
    end
  end

  @doc """
  Gets a customer by ID.

  ## Parameters

  * `:include` - Include related resources (addresses, businesses)

  ## Examples

      PaddleBilling.Customer.get("ctm_123")
      {:ok, %PaddleBilling.Customer{id: "ctm_123", email: "user@example.com"}}

      PaddleBilling.Customer.get("ctm_123", %{include: ["addresses", "businesses"]})
      {:ok, %PaddleBilling.Customer{}}

      PaddleBilling.Customer.get("invalid_id")
      {:error, %PaddleBilling.Error{type: :not_found_error}}
  """
  @spec get(String.t(), map(), keyword()) :: {:ok, t()} | {:error, Error.t()}
  def get(id, params \\ %{}, opts \\ []) do
    case Client.get("/customers/#{id}", params, opts) do
      {:ok, customer} when is_map(customer) ->
        {:ok, from_api(customer)}

      {:ok, response} ->
        {:error, Error.from_response(response)}

      error ->
        error
    end
  end

  @doc """
  Creates a new customer.

  ## Parameters

  * `email` - Customer email address (required, must be unique)
  * `name` - Customer name (optional)
  * `locale` - Customer locale (optional, e.g., "en", "fr", "de")
  * `custom_data` - Custom metadata (optional)

  ## Examples

      PaddleBilling.Customer.create(%{
        email: "user@example.com",
        name: "John Doe"
      })
      {:ok, %PaddleBilling.Customer{id: "ctm_123", email: "user@example.com"}}

      PaddleBilling.Customer.create(%{
        email: "enterprise@company.com",
        name: "Acme Corporation",
        locale: "en",
        custom_data: %{
          company_size: "large",
          industry: "technology",
          lead_source: "website"
        }
      })
      {:ok, %PaddleBilling.Customer{}}

      # Validation error for invalid email
      PaddleBilling.Customer.create(%{email: "invalid-email"})
      {:error, %PaddleBilling.Error{type: :validation_error}}
  """
  @spec create(create_params(), keyword()) :: {:ok, t()} | {:error, Error.t()}
  def create(params, opts \\ []) do
    case Client.post("/customers", params, opts) do
      {:ok, customer} when is_map(customer) ->
        {:ok, from_api(customer)}

      {:ok, response} ->
        {:error, Error.from_response(response)}

      error ->
        error
    end
  end

  @doc """
  Updates a customer.

  ## Parameters

  * `name` - Customer name (optional)
  * `email` - Customer email address (optional)
  * `locale` - Customer locale (optional)
  * `marketing_consent` - Marketing consent preference (optional)
  * `custom_data` - Custom metadata (optional)
  * `status` - Customer status: "active" or "archived" (optional)

  ## Examples

      PaddleBilling.Customer.update("ctm_123", %{
        name: "Jane Doe",
        marketing_consent: true
      })
      {:ok, %PaddleBilling.Customer{name: "Jane Doe"}}

      # Update email address
      PaddleBilling.Customer.update("ctm_123", %{
        email: "newemail@example.com"
      })
      {:ok, %PaddleBilling.Customer{}}

      # Add custom metadata
      PaddleBilling.Customer.update("ctm_123", %{
        custom_data: %{
          subscription_tier: "premium",
          last_login: "2024-01-15T10:30:00Z",
          preferences: %{
            newsletter: true,
            notifications: false
          }
        }
      })
      {:ok, %PaddleBilling.Customer{}}
  """
  @spec update(String.t(), update_params(), keyword()) :: {:ok, t()} | {:error, Error.t()}
  def update(id, params, opts \\ []) do
    case Client.patch("/customers/#{id}", params, opts) do
      {:ok, customer} when is_map(customer) ->
        {:ok, from_api(customer)}

      {:ok, response} ->
        {:error, Error.from_response(response)}

      error ->
        error
    end
  end

  @doc """
  Archives a customer.

  Archived customers cannot be used to create new subscriptions or transactions,
  but existing subscriptions and transaction history remain accessible.

  ## Examples

      PaddleBilling.Customer.archive("ctm_123")
      {:ok, %PaddleBilling.Customer{status: "archived"}}
  """
  @spec archive(String.t(), keyword()) :: {:ok, t()} | {:error, Error.t()}
  def archive(id, opts \\ []) do
    update(id, %{status: "archived"}, opts)
  end

  @doc """
  Searches for customers by email or name.

  Convenience function for searching customers.

  ## Examples

      PaddleBilling.Customer.search("john")
      {:ok, [%PaddleBilling.Customer{name: "John Doe"}, ...]}

      PaddleBilling.Customer.search("@company.com")
      {:ok, [%PaddleBilling.Customer{email: "user@company.com"}, ...]}
  """
  @spec search(String.t(), keyword()) :: {:ok, [t()]} | {:error, Error.t()}
  def search(query, opts \\ []) do
    list(%{search: query}, opts)
  end

  @doc """
  Finds a customer by email address.

  Convenience function for finding customers by their unique email.

  ## Examples

      PaddleBilling.Customer.find_by_email("user@example.com")
      {:ok, %PaddleBilling.Customer{email: "user@example.com"}}

      PaddleBilling.Customer.find_by_email("nonexistent@example.com")
      {:ok, []}  # Empty list if not found
  """
  @spec find_by_email(String.t(), keyword()) :: {:ok, [t()]} | {:error, Error.t()}
  def find_by_email(email, opts \\ []) do
    list(%{email: email}, opts)
  end

  @doc """
  Updates a customer's marketing consent.

  Convenience function for managing marketing preferences.

  ## Examples

      PaddleBilling.Customer.set_marketing_consent("ctm_123", true)
      {:ok, %PaddleBilling.Customer{marketing_consent: true}}

      PaddleBilling.Customer.set_marketing_consent("ctm_123", false)
      {:ok, %PaddleBilling.Customer{marketing_consent: false}}
  """
  @spec set_marketing_consent(String.t(), boolean(), keyword()) ::
          {:ok, t()} | {:error, Error.t()}
  def set_marketing_consent(id, consent, opts \\ []) do
    update(id, %{marketing_consent: consent}, opts)
  end

  # Customer Addresses

  @doc """
  Lists all addresses for a customer.

  ## Examples

      PaddleBilling.Customer.list_addresses("ctm_123")
      {:ok, [%PaddleBilling.Address{}, ...]}

      PaddleBilling.Customer.list_addresses("ctm_123", config: custom_config)
      {:ok, [%PaddleBilling.Address{}, ...]}
  """
  @spec list_addresses(String.t(), keyword()) ::
          {:ok, [PaddleBilling.Address.t()]} | {:error, Error.t()}
  def list_addresses(customer_id, opts \\ []) do
    case Client.get("/customers/#{customer_id}/addresses", %{}, opts) do
      {:ok, addresses} when is_list(addresses) ->
        {:ok, Enum.map(addresses, &PaddleBilling.Address.from_api/1)}

      {:ok, response} ->
        {:error, Error.from_response(response)}

      error ->
        error
    end
  end

  @doc """
  Creates a new address for a customer.

  ## Examples

      PaddleBilling.Customer.create_address("ctm_123", %{
        description: "Billing Address",
        first_line: "123 Main St",
        city: "New York",
        postal_code: "10001",
        country_code: "US"
      })
      {:ok, %PaddleBilling.Address{}}
  """
  @spec create_address(String.t(), map(), keyword()) ::
          {:ok, PaddleBilling.Address.t()} | {:error, Error.t()}
  def create_address(customer_id, params, opts \\ []) do
    case Client.post("/customers/#{customer_id}/addresses", params, opts) do
      {:ok, address} when is_map(address) ->
        {:ok, PaddleBilling.Address.from_api(address)}

      {:ok, response} ->
        {:error, Error.from_response(response)}

      error ->
        error
    end
  end

  @doc """
  Gets a specific address for a customer.

  ## Examples

      PaddleBilling.Customer.get_address("ctm_123", "add_456")
      {:ok, %PaddleBilling.Address{id: "add_456"}}
  """
  @spec get_address(String.t(), String.t(), keyword()) ::
          {:ok, PaddleBilling.Address.t()} | {:error, Error.t()}
  def get_address(customer_id, address_id, opts \\ []) do
    case Client.get("/customers/#{customer_id}/addresses/#{address_id}", %{}, opts) do
      {:ok, address} when is_map(address) ->
        {:ok, PaddleBilling.Address.from_api(address)}

      {:ok, response} ->
        {:error, Error.from_response(response)}

      error ->
        error
    end
  end

  @doc """
  Updates a customer address.

  ## Examples

      PaddleBilling.Customer.update_address("ctm_123", "add_456", %{
        first_line: "456 Updated St"
      })
      {:ok, %PaddleBilling.Address{}}
  """
  @spec update_address(String.t(), String.t(), map(), keyword()) ::
          {:ok, PaddleBilling.Address.t()} | {:error, Error.t()}
  def update_address(customer_id, address_id, params, opts \\ []) do
    case Client.patch("/customers/#{customer_id}/addresses/#{address_id}", params, opts) do
      {:ok, address} when is_map(address) ->
        {:ok, PaddleBilling.Address.from_api(address)}

      {:ok, response} ->
        {:error, Error.from_response(response)}

      error ->
        error
    end
  end

  @doc """
  Deletes a customer address.

  ## Examples

      PaddleBilling.Customer.delete_address("ctm_123", "add_456")
      {:ok, nil}
  """
  @spec delete_address(String.t(), String.t(), keyword()) :: {:ok, nil} | {:error, Error.t()}
  def delete_address(customer_id, address_id, opts \\ []) do
    case Client.request(
           :delete,
           "/customers/#{customer_id}/addresses/#{address_id}",
           nil,
           %{},
           opts
         ) do
      {:ok, _} ->
        {:ok, nil}

      error ->
        error
    end
  end

  # Customer Businesses

  @doc """
  Lists all businesses for a customer.

  ## Examples

      PaddleBilling.Customer.list_businesses("ctm_123")
      {:ok, [%PaddleBilling.Business{}, ...]}
  """
  @spec list_businesses(String.t(), keyword()) ::
          {:ok, [PaddleBilling.Business.t()]} | {:error, Error.t()}
  def list_businesses(customer_id, opts \\ []) do
    case Client.get("/customers/#{customer_id}/businesses", %{}, opts) do
      {:ok, businesses} when is_list(businesses) ->
        {:ok, Enum.map(businesses, &PaddleBilling.Business.from_api/1)}

      {:ok, response} ->
        {:error, Error.from_response(response)}

      error ->
        error
    end
  end

  @doc """
  Creates a new business for a customer.

  ## Examples

      PaddleBilling.Customer.create_business("ctm_123", %{
        name: "Acme Corp",
        tax_identifier: "123456789"
      })
      {:ok, %PaddleBilling.Business{}}
  """
  @spec create_business(String.t(), map(), keyword()) ::
          {:ok, PaddleBilling.Business.t()} | {:error, Error.t()}
  def create_business(customer_id, params, opts \\ []) do
    case Client.post("/customers/#{customer_id}/businesses", params, opts) do
      {:ok, business} when is_map(business) ->
        {:ok, PaddleBilling.Business.from_api(business)}

      {:ok, response} ->
        {:error, Error.from_response(response)}

      error ->
        error
    end
  end

  @doc """
  Gets a specific business for a customer.

  ## Examples

      PaddleBilling.Customer.get_business("ctm_123", "biz_456")
      {:ok, %PaddleBilling.Business{id: "biz_456"}}
  """
  @spec get_business(String.t(), String.t(), keyword()) ::
          {:ok, PaddleBilling.Business.t()} | {:error, Error.t()}
  def get_business(customer_id, business_id, opts \\ []) do
    case Client.get("/customers/#{customer_id}/businesses/#{business_id}", %{}, opts) do
      {:ok, business} when is_map(business) ->
        {:ok, PaddleBilling.Business.from_api(business)}

      {:ok, response} ->
        {:error, Error.from_response(response)}

      error ->
        error
    end
  end

  @doc """
  Updates a customer business.

  ## Examples

      PaddleBilling.Customer.update_business("ctm_123", "biz_456", %{
        name: "Updated Corp Name"
      })
      {:ok, %PaddleBilling.Business{}}
  """
  @spec update_business(String.t(), String.t(), map(), keyword()) ::
          {:ok, PaddleBilling.Business.t()} | {:error, Error.t()}
  def update_business(customer_id, business_id, params, opts \\ []) do
    case Client.patch("/customers/#{customer_id}/businesses/#{business_id}", params, opts) do
      {:ok, business} when is_map(business) ->
        {:ok, PaddleBilling.Business.from_api(business)}

      {:ok, response} ->
        {:error, Error.from_response(response)}

      error ->
        error
    end
  end

  @doc """
  Deletes a customer business.

  ## Examples

      PaddleBilling.Customer.delete_business("ctm_123", "biz_456")
      {:ok, nil}
  """
  @spec delete_business(String.t(), String.t(), keyword()) :: {:ok, nil} | {:error, Error.t()}
  def delete_business(customer_id, business_id, opts \\ []) do
    case Client.request(
           :delete,
           "/customers/#{customer_id}/businesses/#{business_id}",
           nil,
           %{},
           opts
         ) do
      {:ok, _} ->
        {:ok, nil}

      error ->
        error
    end
  end

  # Payment Methods

  @doc """
  Lists all payment methods for a customer.

  ## Examples

      PaddleBilling.Customer.list_payment_methods("ctm_123")
      {:ok, [%{"id" => "paymtd_123", "type" => "card", ...}, ...]}
  """
  @spec list_payment_methods(String.t(), keyword()) :: {:ok, [map()]} | {:error, Error.t()}
  def list_payment_methods(customer_id, opts \\ []) do
    Client.get("/customers/#{customer_id}/payment-methods", %{}, opts)
  end

  @doc """
  Deletes a customer payment method.

  ## Examples

      PaddleBilling.Customer.delete_payment_method("ctm_123", "paymtd_456")
      {:ok, nil}
  """
  @spec delete_payment_method(String.t(), String.t(), keyword()) ::
          {:ok, nil} | {:error, Error.t()}
  def delete_payment_method(customer_id, payment_method_id, opts \\ []) do
    case Client.request(
           :delete,
           "/customers/#{customer_id}/payment-methods/#{payment_method_id}",
           nil,
           %{},
           opts
         ) do
      {:ok, _} ->
        {:ok, nil}

      error ->
        error
    end
  end

  # Portal Sessions

  @doc """
  Creates a portal session for a customer.

  Portal sessions allow customers to manage their subscriptions, payment methods,
  and billing information through Paddle's customer portal.

  ## Examples

      PaddleBilling.Customer.create_portal_session("ctm_123", %{
        return_url: "https://example.com/return"
      })
      {:ok, %{"id" => "ps_123", "url" => "https://customer.paddle.com/...", ...}}
  """
  @spec create_portal_session(String.t(), map(), keyword()) :: {:ok, map()} | {:error, Error.t()}
  def create_portal_session(customer_id, params, opts \\ []) do
    Client.post("/customers/#{customer_id}/portal-sessions", params, opts)
  end

  @doc """
  Gets a portal session for a customer.

  ## Examples

      PaddleBilling.Customer.get_portal_session("ctm_123", "ps_456")
      {:ok, %{"id" => "ps_456", "url" => "https://customer.paddle.com/...", ...}}
  """
  @spec get_portal_session(String.t(), String.t(), keyword()) ::
          {:ok, map()} | {:error, Error.t()}
  def get_portal_session(customer_id, portal_session_id, opts \\ []) do
    Client.get("/customers/#{customer_id}/portal-sessions/#{portal_session_id}", %{}, opts)
  end

  @doc """
  Generates an authentication token for a customer.

  Creates a secure authentication token that allows customers to access
  Paddle.js features like saved payment methods and customer portal
  functionality without requiring full account credentials.

  ## Examples

      PaddleBilling.Customer.generate_auth_token("ctm_123")
      {:ok, %{
        "token" => "ptok_abc123...",
        "expires_at" => "2024-01-15T11:00:00Z"
      }}

      PaddleBilling.Customer.generate_auth_token("ctm_invalid")
      {:error, %PaddleBilling.Error{type: :not_found_error}}
  """
  @spec generate_auth_token(String.t(), keyword()) :: {:ok, map()} | {:error, Error.t()}
  def generate_auth_token(customer_id, opts \\ []) do
    Client.post("/customers/#{customer_id}/auth-token", %{}, opts)
  end

  @doc """
  Lists credit balances for a customer.

  Returns all available credit balances across different currencies
  for the specified customer.

  ## Examples

      PaddleBilling.Customer.list_credit_balances("ctm_123")
      {:ok, [
        %{
          "currency_code" => "USD",
          "balance" => "1500",
          "available" => "1500",
          "reserved" => "0"
        },
        %{
          "currency_code" => "EUR", 
          "balance" => "800",
          "available" => "600",
          "reserved" => "200"
        }
      ]}

      PaddleBilling.Customer.list_credit_balances("ctm_no_credits")
      {:ok, []}
  """
  @spec list_credit_balances(String.t(), keyword()) :: {:ok, [map()]} | {:error, Error.t()}
  def list_credit_balances(customer_id, opts \\ []) do
    Client.get("/customers/#{customer_id}/credit-balances", %{}, opts)
  end

  # Private functions

  @spec from_api(map()) :: t()
  defp from_api(data) when is_map(data) do
    %__MODULE__{
      id: Map.get(data, "id"),
      name: Map.get(data, "name"),
      email: Map.get(data, "email"),
      locale: Map.get(data, "locale"),
      status: Map.get(data, "status"),
      custom_data: Map.get(data, "custom_data"),
      created_at: Map.get(data, "created_at"),
      updated_at: Map.get(data, "updated_at"),
      marketing_consent: Map.get(data, "marketing_consent", false),
      import_meta: Map.get(data, "import_meta")
    }
  end
end
