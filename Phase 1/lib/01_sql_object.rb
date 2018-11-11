require_relative 'db_connection'
require 'active_support/inflector'
require 'byebug'

# NB: the attr_accessor we wrote in phase 0 is NOT used in the rest
# of this project. It was only a warm up.

class SQLObject
  def self.columns
    return @columns if @columns

    data = DBConnection.execute2(<<-SQL)
      SELECT
        *
      FROM
        #{self.table_name}
    SQL

    @columns = data.first.map(&:to_sym)
  end

  def self.finalize!
    self.columns.each do |key|
      define_method(key.to_s) do
        self.attributes[key]
      end

      define_method("#{key.to_s}=") do |value|
        self.attributes[key] = value
      end
    end
  end

  def self.table_name=(table_name)
    @table_name = table_name
  end

  def self.table_name
    @table_name = self.to_s.downcase + 's'
  end

  def self.all
    data = DBConnection.execute(<<-SQL)
      SELECT
        *
      FROM
        #{self.table_name}
    SQL

    self.parse_all(data)
  end

  def self.parse_all(results)
    results.map do |params|
      self.new(params)
    end
  end

  def self.find(id)
    data = DBConnection.execute(<<-SQL, id)
      SELECT
        *
      FROM
        #{self.table_name}
      WHERE
        id = ?
    SQL

    return nil if data.empty?
    self.new(data[0])
  end

  def initialize(params = {})
    params.each do |key, value|
      attribute = key.to_sym

      if self.class.columns.include?(attribute)
        self.send("#{attribute}=", value)
      else
        raise "unknown attribute '#{attribute}'"
      end

    end

    self
  end

  def attributes
    @attributes ||= {}
  end

  def attribute_values
    self.class.columns.map do |attribute|
      self.send(attribute.to_s)
    end
  end

  def insert
    col_names = "(" + self.class.columns.join(',') + ")"
    quesiton_marks = "(" + (["?"] * self.class.columns.length).join(',') + ")"
    *args = attribute_values

    data = DBConnection.execute(<<-SQL, *args)
      INSERT INTO
        #{self.class.table_name} #{col_names}
      VALUES
        #{quesiton_marks}
    SQL

    self.id = DBConnection.last_insert_row_id
  end

  def update
    col_names = self.class.columns.map { |attribute| "#{attribute} = ?" }.join(',')
    *args = attribute_values

    data = DBConnection.execute(<<-SQL, *args)
      UPDATE
        #{self.class.table_name}
      SET
        #{col_names}
      WHERE
        id = #{self.id}
    SQL

    true
  end

  def save
    if self.id
      update
    else
      insert
    end
  end
end
