defmodule PaddleBilling.Business do
  @moduledoc """
  Manage businesses in Paddle Billing.

  Businesses represent companies or organizations that purchase your products.
  They contain tax identification details, company information, and are used
  for B2B transactions, tax calculations, and compliance with business tax
  regulations across different jurisdictions.
  """

  alias PaddleBilling.{Client, Error}

  @type t :: %__MODULE__{
          id: String.t(),
          customer_id: String.t(),
          name: String.t(),
          company_number: String.t() | nil,
          tax_identifier: String.t() | nil,
          status: String.t(),
          contacts: [contact()],
          created_at: String.t(),
          updated_at: String.t(),
          custom_data: map() | nil,
          import_meta: map() | nil
        }

  defstruct [
    :id,
    :customer_id,
    :name,
    :company_number,
    :tax_identifier,
    :status,
    :contacts,
    :created_at,
    :updated_at,
    :custom_data,
    :import_meta
  ]

  @type contact :: %{
          name: String.t(),
          email: String.t()
        }

  @type list_params :: %{
          optional(:after) => String.t(),
          optional(:id) => [String.t()],
          optional(:customer_id) => [String.t()],
          optional(:status) => [String.t()],
          optional(:search) => String.t(),
          optional(:per_page) => pos_integer(),
          optional(:include) => [String.t()]
        }

  @type create_params :: %{
          :customer_id => String.t(),
          :name => String.t(),
          optional(:company_number) => String.t(),
          optional(:tax_identifier) => String.t(),
          optional(:contacts) => [contact()],
          optional(:custom_data) => map()
        }

  @type update_params :: %{
          optional(:name) => String.t(),
          optional(:company_number) => String.t(),
          optional(:tax_identifier) => String.t(),
          optional(:contacts) => [contact()],
          optional(:status) => String.t(),
          optional(:custom_data) => map()
        }

  @doc """
  Lists all businesses.

  ## Parameters

  * `:after` - Return businesses after this business ID (pagination)
  * `:id` - Filter by specific business IDs
  * `:customer_id` - Filter by customer IDs
  * `:status` - Filter by status (active, archived)
  * `:search` - Search businesses by name or tax identifier
  * `:per_page` - Number of results per page (max 200)
  * `:include` - Include related resources (customer)

  ## Examples

      PaddleBilling.Business.list()
      {:ok, [%PaddleBilling.Business{}, ...]}

      PaddleBilling.Business.list(%{
        customer_id: ["ctm_123"],
        status: ["active"],
        search: "acme corp",
        include: ["customer"],
        per_page: 50
      })
      {:ok, [%PaddleBilling.Business{}, ...]}

      # Search for businesses by tax identifier
      PaddleBilling.Business.list(%{search: "123456789"})
      {:ok, [%PaddleBilling.Business{tax_identifier: "123456789"}, ...]}
  """
  @spec list(list_params(), keyword()) :: {:ok, [t()]} | {:error, Error.t()}
  def list(params \\ %{}, opts \\ []) do
    case Client.get("/businesses", params, opts) do
      {:ok, businesses} when is_list(businesses) ->
        {:ok, Enum.map(businesses, &from_api/1)}

      {:ok, response} ->
        {:error, Error.from_response(response)}

      error ->
        error
    end
  end

  @doc """
  Gets a business by ID.

  ## Parameters

  * `:include` - Include related resources (customer)

  ## Examples

      PaddleBilling.Business.get("biz_123")
      {:ok, %PaddleBilling.Business{id: "biz_123", name: "Acme Corp"}}

      PaddleBilling.Business.get("biz_123", %{include: ["customer"]})
      {:ok, %PaddleBilling.Business{}}

      PaddleBilling.Business.get("invalid_id")
      {:error, %PaddleBilling.Error{type: :not_found_error}}
  """
  @spec get(String.t(), map(), keyword()) :: {:ok, t()} | {:error, Error.t()}
  def get(id, params \\ %{}, opts \\ []) do
    case Client.get("/businesses/#{id}", params, opts) do
      {:ok, business} when is_map(business) ->
        {:ok, from_api(business)}

      {:ok, response} ->
        {:error, Error.from_response(response)}

      error ->
        error
    end
  end

  @doc """
  Creates a new business.

  ## Parameters

  * `customer_id` - Customer ID (required)
  * `name` - Business name (required)
  * `company_number` - Company registration number (optional)
  * `tax_identifier` - Tax identification number (optional)
  * `contacts` - Business contacts (optional)
  * `custom_data` - Custom metadata (optional)

  ## Examples

      # Simple business
      PaddleBilling.Business.create(%{
        customer_id: "ctm_123",
        name: "Acme Corporation"
      })
      {:ok, %PaddleBilling.Business{}}

      # Complete business with tax info
      PaddleBilling.Business.create(%{
        customer_id: "ctm_456",
        name: "Tech Solutions Ltd",
        company_number: "12345678",
        tax_identifier: "GB123456789",
        contacts: [
          %{
            name: "John Doe",
            email: "john.doe@techsolutions.com"
          },
          %{
            name: "Jane Smith",
            email: "jane.smith@techsolutions.com"
          }
        ],
        custom_data: %{
          "industry" => "technology",
          "employees" => "50-100",
          "founded" => "2020"
        }
      })
      {:ok, %PaddleBilling.Business{}}

      # European business with VAT number
      PaddleBilling.Business.create(%{
        customer_id: "ctm_enterprise",
        name: "Innovation GmbH",
        company_number: "HRB 123456",
        tax_identifier: "DE123456789",
        contacts: [
          %{
            name: "Klaus Mueller",
            email: "klaus.mueller@innovation.de"
          }
        ],
        custom_data: %{
          "vat_registered" => true,
          "jurisdiction" => "Germany"
        }
      })
      {:ok, %PaddleBilling.Business{}}
  """
  @spec create(create_params(), keyword()) :: {:ok, t()} | {:error, Error.t()}
  def create(params, opts \\ []) do
    case Client.post("/businesses", params, opts) do
      {:ok, business} when is_map(business) ->
        {:ok, from_api(business)}

      {:ok, response} ->
        {:error, Error.from_response(response)}

      error ->
        error
    end
  end

  @doc """
  Updates a business.

  ## Parameters

  * `name` - Business name (optional)
  * `company_number` - Company registration number (optional)
  * `tax_identifier` - Tax identification number (optional)
  * `contacts` - Business contacts (optional)
  * `status` - Business status: "active" or "archived" (optional)
  * `custom_data` - Custom metadata (optional)

  ## Examples

      PaddleBilling.Business.update("biz_123", %{
        name: "Acme Corporation Ltd",
        tax_identifier: "US123456789",
        contacts: [
          %{
            name: "Alice Johnson",
            email: "alice.johnson@acme.com"
          }
        ]
      })
      {:ok, %PaddleBilling.Business{}}

      # Update tax information
      PaddleBilling.Business.update("biz_123", %{
        tax_identifier: "GB987654321",
        custom_data: %{
          "vat_registration_date" => "2024-01-01",
          "tax_jurisdiction" => "United Kingdom"
        }
      })
      {:ok, %PaddleBilling.Business{}}

      # Add new contact
      PaddleBilling.Business.update("biz_123", %{
        contacts: [
          %{
            name: "Bob Wilson",
            email: "bob.wilson@acme.com"
          },
          %{
            name: "Carol Davis",
            email: "carol.davis@acme.com"
          }
        ]
      })
      {:ok, %PaddleBilling.Business{}}
  """
  @spec update(String.t(), update_params(), keyword()) :: {:ok, t()} | {:error, Error.t()}
  def update(id, params, opts \\ []) do
    case Client.patch("/businesses/#{id}", params, opts) do
      {:ok, business} when is_map(business) ->
        {:ok, from_api(business)}

      {:ok, response} ->
        {:error, Error.from_response(response)}

      error ->
        error
    end
  end

  @doc """
  Archives a business.

  Archived businesses cannot be used for new transactions but existing
  transaction history remains accessible.

  ## Examples

      PaddleBilling.Business.archive("biz_123")
      {:ok, %PaddleBilling.Business{status: "archived"}}
  """
  @spec archive(String.t(), keyword()) :: {:ok, t()} | {:error, Error.t()}
  def archive(id, opts \\ []) do
    update(id, %{status: "archived"}, opts)
  end

  @doc """
  Gets businesses for a specific customer.

  Convenience function to find all businesses for a customer.

  ## Examples

      PaddleBilling.Business.list_for_customer("ctm_123")
      {:ok, [%PaddleBilling.Business{customer_id: "ctm_123"}, ...]}

      PaddleBilling.Business.list_for_customer("ctm_123", ["active"])
      {:ok, [%PaddleBilling.Business{}, ...]}
  """
  @spec list_for_customer(String.t(), [String.t()], keyword()) ::
          {:ok, [t()]} | {:error, Error.t()}
  def list_for_customer(customer_id, statuses \\ ["active"], opts \\ []) do
    list(%{customer_id: [customer_id], status: statuses}, opts)
  end

  @doc """
  Searches for businesses by name or tax identifier.

  Convenience function for searching businesses.

  ## Examples

      PaddleBilling.Business.search("acme")
      {:ok, [%PaddleBilling.Business{name: "Acme Corporation"}, ...]}

      PaddleBilling.Business.search("GB123456789")
      {:ok, [%PaddleBilling.Business{tax_identifier: "GB123456789"}, ...]}
  """
  @spec search(String.t(), keyword()) :: {:ok, [t()]} | {:error, Error.t()}
  def search(query, opts \\ []) do
    list(%{search: query}, opts)
  end

  @doc """
  Validates if a tax identifier appears to be valid.

  Performs basic format validation for common tax identifier formats.
  This is a client-side check only and does not verify with tax authorities.

  ## Examples

      PaddleBilling.Business.valid_tax_identifier?("GB123456789")
      true

      PaddleBilling.Business.valid_tax_identifier?("US12-3456789")
      true

      PaddleBilling.Business.valid_tax_identifier?("DE123456789")
      true

      PaddleBilling.Business.valid_tax_identifier?("invalid")
      false
  """
  @spec valid_tax_identifier?(String.t() | nil) :: boolean()
  def valid_tax_identifier?(nil), do: false
  def valid_tax_identifier?(""), do: false

  def valid_tax_identifier?(tax_id) when is_binary(tax_id) do
    upper_tax_id = String.upcase(tax_id)

    validate_specific_format(upper_tax_id) or validate_generic_format(upper_tax_id)
  end

  def valid_tax_identifier?(_), do: false

  # Check specific country formats first
  defp validate_specific_format(upper_tax_id) do
    uk_vat?(upper_tax_id) or
      us_ein?(upper_tax_id) or
      german_vat?(upper_tax_id) or
      french_vat?(upper_tax_id) or
      canadian_bn?(upper_tax_id) or
      australian_abn?(upper_tax_id)
  end

  # UK VAT numbers: GB followed by 9-12 digits
  defp uk_vat?(tax_id), do: String.match?(tax_id, ~r/^GB\d{9,12}$/)

  # US Federal EIN: XX-XXXXXXX format (exactly 10 chars with dash at position 2)
  defp us_ein?(tax_id), do: String.match?(tax_id, ~r/^\d{2}-\d{7}$/)

  # German VAT: DE followed by exactly 9 digits
  defp german_vat?(tax_id), do: String.match?(tax_id, ~r/^DE\d{9}$/)

  # French VAT: FR followed by 2 alphanumeric + 9 digits
  defp french_vat?(tax_id), do: String.match?(tax_id, ~r/^FR[A-Z0-9]{2}\d{9}$/)

  # Canadian Business Number: 9 digits + 2 letters + 4 digits (exactly 15 chars total)
  defp canadian_bn?(tax_id), do: String.match?(tax_id, ~r/^\d{9}[A-Z]{2}\d{4}$/)

  # Australian ABN: exactly 11 digits
  defp australian_abn?(tax_id), do: String.match?(tax_id, ~r/^\d{11}$/)

  # Generic validation: at least 3 characters, alphanumeric with optional dashes
  defp validate_generic_format(upper_tax_id) do
    byte_size(upper_tax_id) >= 3 and
      valid_generic_pattern?(upper_tax_id) and
      has_mixed_content?(upper_tax_id) and
      not invalid_format?(upper_tax_id)
  end

  defp valid_generic_pattern?(tax_id) do
    String.match?(tax_id, ~r/^[A-Z0-9\-]{3,}$/) and
      not String.starts_with?(tax_id, "-") and
      not String.ends_with?(tax_id, "-")
  end

  defp has_mixed_content?(tax_id) do
    String.contains?(tax_id, ["-"]) or
      (String.match?(tax_id, ~r/[0-9]/) and String.match?(tax_id, ~r/[A-Z]/))
  end

  defp invalid_format?(tax_id) do
    pure_letters?(tax_id) or
      pure_digits?(tax_id) or
      reserved_prefix?(tax_id) or
      invalid_specific_pattern?(tax_id)
  end

  defp pure_letters?(tax_id), do: String.match?(tax_id, ~r/^[A-Z]+$/)
  defp pure_digits?(tax_id), do: String.match?(tax_id, ~r/^\d+$/)

  defp reserved_prefix?(tax_id) do
    String.match?(tax_id, ~r/^GB/) or
      String.match?(tax_id, ~r/^DE/) or
      String.match?(tax_id, ~r/^FR/) or
      String.match?(tax_id, ~r/^\d{2}-\d/)
  end

  defp invalid_specific_pattern?(tax_id) do
    invalid_canadian_pattern?(tax_id) or
      invalid_abn_pattern?(tax_id)
  end

  defp invalid_canadian_pattern?(tax_id) do
    (byte_size(tax_id) == 14 and String.match?(tax_id, ~r/^\d{8}[A-Z]{2}\d{4}$/)) or
      (byte_size(tax_id) == 13 and String.match?(tax_id, ~r/^\d{9}[A-Z]{2}\d$/)) or
      (byte_size(tax_id) == 14 and String.match?(tax_id, ~r/^\d{9}[A-Z]{2}\d{3}$/))
  end

  defp invalid_abn_pattern?(tax_id) do
    (byte_size(tax_id) == 11 and String.match?(tax_id, ~r/^\d{10}[A-Z]$/)) or
      (byte_size(tax_id) == 10 and String.match?(tax_id, ~r/^\d{10}$/)) or
      (byte_size(tax_id) == 12 and String.match?(tax_id, ~r/^\d{12}$/))
  end

  @doc """
  Checks if a business is active.

  ## Examples

      PaddleBilling.Business.active?(%PaddleBilling.Business{status: "active"})
      true

      PaddleBilling.Business.active?(%PaddleBilling.Business{status: "archived"})
      false
  """
  @spec active?(t()) :: boolean()
  def active?(%__MODULE__{status: "active"}), do: true
  def active?(%__MODULE__{}), do: false

  @doc """
  Checks if a business is archived.

  ## Examples

      PaddleBilling.Business.archived?(%PaddleBilling.Business{status: "archived"})
      true
  """
  @spec archived?(t()) :: boolean()
  def archived?(%__MODULE__{status: "archived"}), do: true
  def archived?(%__MODULE__{}), do: false

  @doc """
  Checks if a business has tax identification.

  ## Examples

      business = %PaddleBilling.Business{tax_identifier: "GB123456789"}
      PaddleBilling.Business.has_tax_identifier?(business)
      true

      business = %PaddleBilling.Business{tax_identifier: nil}
      PaddleBilling.Business.has_tax_identifier?(business)
      false
  """
  @spec has_tax_identifier?(t()) :: boolean()
  def has_tax_identifier?(%__MODULE__{tax_identifier: tax_id}) do
    not is_nil(tax_id) and tax_id != ""
  end

  @doc """
  Checks if a business has valid tax identification.

  Combines existence check with format validation.

  ## Examples

      business = %PaddleBilling.Business{tax_identifier: "GB123456789"}
      PaddleBilling.Business.valid_tax_info?(business)
      true
  """
  @spec valid_tax_info?(t()) :: boolean()
  def valid_tax_info?(%__MODULE__{tax_identifier: tax_id}) do
    valid_tax_identifier?(tax_id)
  end

  # Private functions

  @spec from_api(map()) :: t()
  def from_api(data) when is_map(data) do
    %__MODULE__{
      id: Map.get(data, "id"),
      customer_id: Map.get(data, "customer_id"),
      name: Map.get(data, "name"),
      company_number: Map.get(data, "company_number"),
      tax_identifier: Map.get(data, "tax_identifier"),
      status: Map.get(data, "status"),
      contacts: ensure_list(Map.get(data, "contacts", [])),
      created_at: Map.get(data, "created_at"),
      updated_at: Map.get(data, "updated_at"),
      custom_data: Map.get(data, "custom_data"),
      import_meta: Map.get(data, "import_meta")
    }
  end

  @spec ensure_list(any()) :: [any()]
  defp ensure_list(nil), do: []
  defp ensure_list(list) when is_list(list), do: list
  defp ensure_list(_), do: []
end
