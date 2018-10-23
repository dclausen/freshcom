defmodule Freshcom.Request do
  use TypedStruct

  typedstruct do
    field :requester, map(), default: %{id: nil, account_id: nil}
    field :fields, map(), default: %{}
    field :identifiers, map(), default: %{}
    field :filter, map(), default: %{}
    field :include, [String.t()]
    field :locale, String.t()
    field :_include_, map(), default: %{paths: [], filters: []}
  end
end
