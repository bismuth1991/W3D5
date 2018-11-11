require_relative 'db_connection'
require_relative '01_sql_object'

module Searchable
  def where(params)
    where_row = params.map { |attribute, _| "#{attribute}= ?" }.join(' AND ')
    args = params.map { |_, value| value }

    data = DBConnection.execute(<<-SQL, args)
      SELECT
        *
      FROM
        #{self.table_name}
      WHERE
        #{where_row}
    SQL

    self.parse_all(data)
  end
end

class SQLObject
  extend Searchable
end
