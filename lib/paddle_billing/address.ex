defmodule PaddleBilling.Address do
  @moduledoc """
  Manage addresses in Paddle Billing.

  Addresses represent customer billing and shipping locations and are used
  for tax calculations, billing, and compliance. Each address belongs to
  a customer and contains location information required for accurate
  tax computation and regional compliance.
  """

  alias PaddleBilling.{Client, Error}

  @type t :: %__MODULE__{
          id: String.t(),
          customer_id: String.t(),
          description: String.t() | nil,
          first_line: String.t() | nil,
          second_line: String.t() | nil,
          city: String.t() | nil,
          postal_code: String.t() | nil,
          region: String.t() | nil,
          country_code: String.t(),
          custom_data: map() | nil,
          status: String.t(),
          created_at: String.t(),
          updated_at: String.t(),
          import_meta: map() | nil
        }

  defstruct [
    :id,
    :customer_id,
    :description,
    :first_line,
    :second_line,
    :city,
    :postal_code,
    :region,
    :country_code,
    :custom_data,
    :status,
    :created_at,
    :updated_at,
    :import_meta
  ]

  @type list_params :: %{
          optional(:after) => String.t(),
          optional(:customer_id) => [String.t()],
          optional(:id) => [String.t()],
          optional(:status) => [String.t()],
          optional(:country_code) => [String.t()],
          optional(:per_page) => pos_integer(),
          optional(:include) => [String.t()]
        }

  @type create_params :: %{
          :customer_id => String.t(),
          :country_code => String.t(),
          optional(:description) => String.t(),
          optional(:first_line) => String.t(),
          optional(:second_line) => String.t(),
          optional(:city) => String.t(),
          optional(:postal_code) => String.t(),
          optional(:region) => String.t(),
          optional(:custom_data) => map()
        }

  @type update_params :: %{
          optional(:description) => String.t(),
          optional(:first_line) => String.t(),
          optional(:second_line) => String.t(),
          optional(:city) => String.t(),
          optional(:postal_code) => String.t(),
          optional(:region) => String.t(),
          optional(:country_code) => String.t(),
          optional(:custom_data) => map()
        }

  @doc """
  Lists all addresses.

  ## Parameters

  * `:after` - Return addresses after this address ID (pagination)
  * `:customer_id` - Filter by customer IDs
  * `:id` - Filter by specific address IDs
  * `:status` - Filter by status (active, archived)
  * `:country_code` - Filter by country codes (ISO 3166-1 alpha-2)
  * `:per_page` - Number of results per page (max 200)
  * `:include` - Include related resources (customer)

  ## Examples

      PaddleBilling.Address.list()
      {:ok, [%PaddleBilling.Address{}, ...]}

      PaddleBilling.Address.list(%{
        customer_id: ["ctm_123"],
        country_code: ["US", "CA"],
        status: ["active"],
        include: ["customer"],
        per_page: 50
      })
      {:ok, [%PaddleBilling.Address{}, ...]}

      # Filter by specific regions
      PaddleBilling.Address.list(%{
        country_code: ["US"],
        customer_id: ["ctm_enterprise"]
      })
      {:ok, [%PaddleBilling.Address{}, ...]}
  """
  @spec list(list_params(), keyword()) :: {:ok, [t()]} | {:error, Error.t()}
  def list(params \\ %{}, opts \\ []) do
    case Client.get("/addresses", params, opts) do
      {:ok, addresses} when is_list(addresses) ->
        {:ok, Enum.map(addresses, &from_api/1)}

      {:ok, response} ->
        {:error, Error.from_response(response)}

      error ->
        error
    end
  end

  @doc """
  Gets an address by ID.

  ## Parameters

  * `:include` - Include related resources (customer)

  ## Examples

      PaddleBilling.Address.get("add_123")
      {:ok, %PaddleBilling.Address{id: "add_123", country_code: "US"}}

      PaddleBilling.Address.get("add_123", %{include: ["customer"]})
      {:ok, %PaddleBilling.Address{}}

      PaddleBilling.Address.get("invalid_id")
      {:error, %PaddleBilling.Error{type: :not_found_error}}
  """
  @spec get(String.t(), map(), keyword()) :: {:ok, t()} | {:error, Error.t()}
  def get(id, params \\ %{}, opts \\ []) do
    case Client.get("/addresses/#{id}", params, opts) do
      {:ok, address} when is_map(address) ->
        {:ok, from_api(address)}

      {:ok, response} ->
        {:error, Error.from_response(response)}

      error ->
        error
    end
  end

  @doc """
  Creates a new address.

  ## Parameters

  * `customer_id` - Customer ID (required)
  * `country_code` - ISO 3166-1 alpha-2 country code (required)
  * `description` - Address description (optional)
  * `first_line` - First line of address (optional)
  * `second_line` - Second line of address (optional)
  * `city` - City name (optional)
  * `postal_code` - Postal/ZIP code (required in some regions)
  * `region` - State/province/region (optional)
  * `custom_data` - Custom metadata (optional)

  ## Examples

      # Simple US address
      PaddleBilling.Address.create(%{
        customer_id: "ctm_123",
        country_code: "US",
        description: "Billing Address",
        first_line: "123 Main Street",
        city: "New York",
        region: "NY",
        postal_code: "10001"
      })
      {:ok, %PaddleBilling.Address{}}

      # International address with minimal info
      PaddleBilling.Address.create(%{
        customer_id: "ctm_456",
        country_code: "GB",
        description: "London Office",
        first_line: "10 Downing Street",
        city: "London",
        postal_code: "SW1A 2AA"
      })
      {:ok, %PaddleBilling.Address{}}

      # Enterprise address with custom data
      PaddleBilling.Address.create(%{
        customer_id: "ctm_enterprise",
        country_code: "CA",
        description: "Head Office",
        first_line: "100 Queen Street West",
        second_line: "Suite 3200",
        city: "Toronto",
        region: "ON",
        postal_code: "M5H 2N2",
        custom_data: %{
          "department" => "Finance",
          "contact_person" => "John Smith",
          "phone" => "+1-416-555-0123"
        }
      })
      {:ok, %PaddleBilling.Address{}}
  """
  @spec create(create_params(), keyword()) :: {:ok, t()} | {:error, Error.t()}
  def create(params, opts \\ []) do
    case Client.post("/addresses", params, opts) do
      {:ok, address} when is_map(address) ->
        {:ok, from_api(address)}

      {:ok, response} ->
        {:error, Error.from_response(response)}

      error ->
        error
    end
  end

  @doc """
  Updates an address.

  ## Parameters

  * `description` - Address description (optional)
  * `first_line` - First line of address (optional)
  * `second_line` - Second line of address (optional)
  * `city` - City name (optional)
  * `postal_code` - Postal/ZIP code (optional)
  * `region` - State/province/region (optional)
  * `country_code` - ISO 3166-1 alpha-2 country code (optional)
  * `custom_data` - Custom metadata (optional)

  ## Examples

      PaddleBilling.Address.update("add_123", %{
        description: "Updated Billing Address",
        second_line: "Floor 2",
        custom_data: %{
          "updated_by" => "admin@company.com",
          "update_reason" => "Office relocation"
        }
      })
      {:ok, %PaddleBilling.Address{}}

      # Update just the postal code
      PaddleBilling.Address.update("add_123", %{
        postal_code: "10002"
      })
      {:ok, %PaddleBilling.Address{}}

      # Change country (triggers tax recalculation)
      PaddleBilling.Address.update("add_123", %{
        country_code: "CA",
        postal_code: "M5H 2N2",
        region: "ON"
      })
      {:ok, %PaddleBilling.Address{}}
  """
  @spec update(String.t(), update_params(), keyword()) :: {:ok, t()} | {:error, Error.t()}
  def update(id, params, opts \\ []) do
    case Client.patch("/addresses/#{id}", params, opts) do
      {:ok, address} when is_map(address) ->
        {:ok, from_api(address)}

      {:ok, response} ->
        {:error, Error.from_response(response)}

      error ->
        error
    end
  end

  @doc """
  Gets addresses for a specific customer.

  Convenience function to find all addresses for a customer.

  ## Examples

      PaddleBilling.Address.list_for_customer("ctm_123")
      {:ok, [%PaddleBilling.Address{customer_id: "ctm_123"}, ...]}

      PaddleBilling.Address.list_for_customer("ctm_123", ["active"])
      {:ok, [%PaddleBilling.Address{}, ...]}
  """
  @spec list_for_customer(String.t(), [String.t()], keyword()) ::
          {:ok, [t()]} | {:error, Error.t()}
  def list_for_customer(customer_id, statuses \\ ["active"], opts \\ []) do
    list(%{customer_id: [customer_id], status: statuses}, opts)
  end

  @doc """
  Gets addresses for a specific country.

  Convenience function to find addresses in a specific country.

  ## Examples

      PaddleBilling.Address.list_for_country("US")
      {:ok, [%PaddleBilling.Address{country_code: "US"}, ...]}
  """
  @spec list_for_country(String.t(), keyword()) :: {:ok, [t()]} | {:error, Error.t()}
  def list_for_country(country_code, opts \\ []) do
    list(%{country_code: [country_code]}, opts)
  end

  @doc """
  Validates if an address has required fields for tax calculation.

  Returns true if the address has sufficient information for accurate
  tax calculations in its region.

  ## Examples

      PaddleBilling.Address.valid_for_tax?(%PaddleBilling.Address{
        country_code: "US",
        postal_code: "10001",
        region: "NY"
      })
      true

      PaddleBilling.Address.valid_for_tax?(%PaddleBilling.Address{
        country_code: "US",
        postal_code: nil
      })
      false
  """
  @spec valid_for_tax?(t()) :: boolean()
  def valid_for_tax?(%__MODULE__{country_code: country_code, postal_code: postal_code}) do
    case country_code do
      cc when cc in ["US", "CA"] ->
        # US and Canada require postal codes for accurate tax calculation
        not is_nil(postal_code) and postal_code != ""

      cc when cc in ["GB", "DE", "FR", "IT", "ES"] ->
        # EU countries benefit from postal codes but can work without
        true

      _ ->
        # Other countries - basic validation
        not is_nil(country_code) and country_code != ""
    end
  end

  @doc """
  Checks if an address is active.

  ## Examples

      PaddleBilling.Address.active?(%PaddleBilling.Address{status: "active"})
      true

      PaddleBilling.Address.active?(%PaddleBilling.Address{status: "archived"})
      false
  """
  @spec active?(t()) :: boolean()
  def active?(%__MODULE__{status: "active"}), do: true
  def active?(%__MODULE__{}), do: false

  @doc """
  Checks if an address is archived.

  ## Examples

      PaddleBilling.Address.archived?(%PaddleBilling.Address{status: "archived"})
      true
  """
  @spec archived?(t()) :: boolean()
  def archived?(%__MODULE__{status: "archived"}), do: true
  def archived?(%__MODULE__{}), do: false

  # Private functions

  @spec from_api(map()) :: t()
  def from_api(data) when is_map(data) do
    %__MODULE__{
      id: Map.get(data, "id"),
      customer_id: Map.get(data, "customer_id"),
      description: Map.get(data, "description"),
      first_line: Map.get(data, "first_line"),
      second_line: Map.get(data, "second_line"),
      city: Map.get(data, "city"),
      postal_code: Map.get(data, "postal_code"),
      region: Map.get(data, "region"),
      country_code: Map.get(data, "country_code"),
      custom_data: Map.get(data, "custom_data"),
      status: Map.get(data, "status"),
      created_at: Map.get(data, "created_at"),
      updated_at: Map.get(data, "updated_at"),
      import_meta: Map.get(data, "import_meta")
    }
  end
end
