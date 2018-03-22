json.extract! transaction, :id, :company, :amount, :status, :created_at, :updated_at
json.url transaction_url(transaction, format: :json)
