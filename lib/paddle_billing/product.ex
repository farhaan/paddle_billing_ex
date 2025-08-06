defmodule PaddleBilling.Product do
  @moduledoc """
  Manage products in Paddle Billing.

  Products represent the goods or services that you sell.
  They contain information like name, description, and tax category.
  """

  alias PaddleBilling.{Client, Error}

  @type t :: %__MODULE__{
          id: String.t(),
          name: String.t(),
          description: String.t() | nil,
          type: String.t(),
          tax_category: String.t(),
          image_url: String.t() | nil,
          custom_data: map() | nil,
          status: String.t(),
          created_at: String.t(),
          updated_at: String.t(),
          import_meta: map() | nil
        }

  defstruct [
    :id,
    :name,
    :description,
    :type,
    :tax_category,
    :image_url,
    :custom_data,
    :status,
    :created_at,
    :updated_at,
    :import_meta
  ]

  @type list_params :: %{
          optional(:after) => String.t(),
          optional(:id) => [String.t()],
          optional(:status) => [String.t()],
          optional(:type) => [String.t()],
          optional(:per_page) => pos_integer(),
          optional(:include) => [String.t()]
        }

  @type create_params :: %{
          :name => String.t(),
          optional(:description) => String.t(),
          optional(:type) => String.t(),
          optional(:tax_category) => String.t(),
          optional(:image_url) => String.t(),
          optional(:custom_data) => map()
        }

  @type update_params :: %{
          optional(:name) => String.t(),
          optional(:description) => String.t(),
          optional(:tax_category) => String.t(),
          optional(:image_url) => String.t(),
          optional(:custom_data) => map(),
          optional(:status) => String.t()
        }

  @doc """
  Lists all products.

  ## Parameters

  * `:after` - Return products after this product ID (pagination)
  * `:id` - Filter by specific product IDs
  * `:status` - Filter by status (archived, active)
  * `:type` - Filter by type (standard, service)
  * `:per_page` - Number of results per page (max 200)
  * `:include` - Include related resources (prices)

  ## Examples

      PaddleBilling.Product.list()
      {:ok, [%PaddleBilling.Product{}, ...]}

      PaddleBilling.Product.list(%{
        status: ["active"],
        include: ["prices"],
        per_page: 50
      })
      {:ok, [%PaddleBilling.Product{}, ...]}
  """
  @spec list(list_params(), keyword()) :: {:ok, [t()]} | {:error, Error.t()}
  def list(params \\ %{}, opts \\ []) do
    case Client.get("/products", params, opts) do
      {:ok, products} when is_list(products) ->
        {:ok, Enum.map(products, &from_api/1)}

      {:ok, response} ->
        {:error, Error.from_response(response)}

      error ->
        error
    end
  end

  @doc """
  Gets a product by ID.

  ## Parameters

  * `:include` - Include related resources (prices)

  ## Examples

      PaddleBilling.Product.get("pro_123")
      {:ok, %PaddleBilling.Product{id: "pro_123", name: "My Product"}}

      PaddleBilling.Product.get("pro_123", %{include: ["prices"]})
      {:ok, %PaddleBilling.Product{}}

      PaddleBilling.Product.get("invalid_id")
      {:error, %PaddleBilling.Error{type: :api_error, message: "Product not found"}}
  """
  @spec get(String.t(), map(), keyword()) :: {:ok, t()} | {:error, Error.t()}
  def get(id, params \\ %{}, opts \\ []) do
    case Client.get("/products/#{id}", params, opts) do
      {:ok, product} when is_map(product) ->
        {:ok, from_api(product)}

      {:ok, response} ->
        {:error, Error.from_response(response)}

      error ->
        error
    end
  end

  @doc """
  Creates a new product.

  ## Parameters

  * `name` - Product name (required)
  * `description` - Product description (optional)
  * `type` - Product type: "standard" or "service" (default: "standard")
  * `tax_category` - Tax category (default: "standard")
  * `image_url` - Product image URL (optional)
  * `custom_data` - Custom metadata (optional)

  ## Examples

      PaddleBilling.Product.create(%{
        name: "My Product",
        description: "A great product",
        type: "standard",
        tax_category: "standard"
      })
      {:ok, %PaddleBilling.Product{id: "pro_123", name: "My Product"}}

      PaddleBilling.Product.create(%{
        name: "Digital Service",
        type: "service",
        custom_data: %{category: "software"}
      })
      {:ok, %PaddleBilling.Product{}}
  """
  @spec create(create_params(), keyword()) :: {:ok, t()} | {:error, Error.t()}
  def create(params, opts \\ []) do
    case Client.post("/products", params, opts) do
      {:ok, product} when is_map(product) ->
        {:ok, from_api(product)}

      {:ok, response} ->
        {:error, Error.from_response(response)}

      error ->
        error
    end
  end

  @doc """
  Updates a product.

  ## Parameters

  * `name` - Product name (optional)
  * `description` - Product description (optional)
  * `tax_category` - Tax category (optional)
  * `image_url` - Product image URL (optional)
  * `custom_data` - Custom metadata (optional)
  * `status` - Product status: "active" or "archived" (optional)

  ## Examples

      PaddleBilling.Product.update("pro_123", %{
        name: "Updated Product Name",
        description: "New description"
      })
      {:ok, %PaddleBilling.Product{name: "Updated Product Name"}}

      PaddleBilling.Product.update("pro_123", %{
        custom_data: %{category: "premium"}
      })
      {:ok, %PaddleBilling.Product{}}

      PaddleBilling.Product.update("pro_123", %{
        status: "archived"
      })
      {:ok, %PaddleBilling.Product{status: "archived"}}
  """
  @spec update(String.t(), update_params(), keyword()) :: {:ok, t()} | {:error, Error.t()}
  def update(id, params, opts \\ []) do
    case Client.patch("/products/#{id}", params, opts) do
      {:ok, product} when is_map(product) ->
        {:ok, from_api(product)}

      {:ok, response} ->
        {:error, Error.from_response(response)}

      error ->
        error
    end
  end

  @doc """
  Archives a product.

  Archived products cannot be used to create new prices or subscriptions,
  but existing subscriptions continue to work.

  ## Examples

      PaddleBilling.Product.archive("pro_123")
      {:ok, %PaddleBilling.Product{status: "archived"}}
  """
  @spec archive(String.t(), keyword()) :: {:ok, t()} | {:error, Error.t()}
  def archive(id, opts \\ []) do
    update(id, %{status: "archived"}, opts)
  end

  # Private functions

  @spec from_api(map()) :: t()
  defp from_api(data) when is_map(data) do
    %__MODULE__{
      id: Map.get(data, "id"),
      name: Map.get(data, "name"),
      description: Map.get(data, "description"),
      type: Map.get(data, "type"),
      tax_category: Map.get(data, "tax_category"),
      image_url: Map.get(data, "image_url"),
      custom_data: Map.get(data, "custom_data"),
      status: Map.get(data, "status"),
      created_at: Map.get(data, "created_at"),
      updated_at: Map.get(data, "updated_at"),
      import_meta: Map.get(data, "import_meta")
    }
  end
end
