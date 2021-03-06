require 'java'

module RR
  module ConnectionExtenders

    # Provides various JDBC specific functionality required by Rubyrep.
    module JdbcSQLExtender
      RR::ConnectionExtenders.register :jdbc => self
      
      # Monkey patch for activerecord-jdbc-adapter-0.7.2 as it doesn't set the 
      # +@active+ flag to false, thus ActiveRecord#active? incorrectly confirms
      # the connection to still be active.
      def disconnect!
        super
        @active = false
      end

      # Returns an ordered list of primary key column names of the given table
      def primary_key_names(table)
        if tables.grep(/^#{table}$/i).empty?
          # Note: Cannot use tables.include? as returned tables are made lowercase under JRuby MySQL
          raise "table '#{table}' does not exist"
        end
        columns = []
        result_set = @connection.connection.getMetaData.getPrimaryKeys(nil, nil, table);
        while result_set.next
          column_name = result_set.getString("COLUMN_NAME")
          key_seq = result_set.getShort("KEY_SEQ")
          columns << {:column_name => column_name, :key_seq => key_seq}
        end
        columns.sort! {|a, b| a[:key_seq] <=> b[:key_seq]}
        key_names = columns.map {|column| column[:column_name]}
        key_names
      end

      # Returns for each given table, which other tables it references via
      # foreign key constraints.
      # * tables: an array of table names
      # * returns: a hash with
      #   * key: name of the referencing table
      #   * value: an array of names of referenced tables
      def referenced_tables(tables)
        result = {}
        tables.each do |table|
          references_of_this_table = []
          result_set = @connection.connection.getMetaData.getImportedKeys(nil, nil, table)
          while result_set.next
            referenced_table = result_set.getString("PKTABLE_NAME")
            unless references_of_this_table.include? referenced_table
              references_of_this_table << referenced_table
            end
          end
          result[table] = references_of_this_table
        end
        result
      end
    end
  end
end

# activerecord-jdbc-adapter 0.9.1 (7b3f3eca08149567070837fad63696052dc36cd6)
# improves SQLite binary support by overwriting the global string_to_binary
# methods.
# This appears to break binary support for MySQL.
# And here comes the monkey patch to revert it again...
require 'active_record/connection_adapters/jdbc_adapter_spec'
require 'jdbc_adapter/jdbc_sqlite3'
module ::ActiveRecord
  module ConnectionAdapters
    class JdbcColumn < Column
      def self.string_to_binary(value)
        value
      end

      def self.binary_to_string(value)
        value
      end
    end
  end
end
