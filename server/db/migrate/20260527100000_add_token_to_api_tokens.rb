class AddTokenToApiTokens < ActiveRecord::Migration[8.1]
  def change
    add_column :api_tokens, :token, :string
  end
end
