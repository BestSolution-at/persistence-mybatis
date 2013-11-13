package at.bestsolution.persistence.mybatis;

import java.util.Collections;
import java.util.HashMap;
import java.util.HashSet;
import java.util.Map;
import java.util.Set;

public interface SqlMetaDataProvider {
	public Set<Table> getTables();

	public static class Table {
		private final String name;
		private final Set<Column> columns;
		private Column primaryKeyColumn;
		private Map<String, Column> columnMap;

		public Table(String name, Set<Column> columns) {
			this.name = name;
			this.columns = new HashSet<SqlMetaDataProvider.Column>(columns);
		}

		public String getName() {
			return name;
		}

		public Set<Column> getColumns() {
			return Collections.unmodifiableSet(columns);
		}

		public Column getPrimaryKeyColumn() {
			if( primaryKeyColumn == null ) {
				for( Column c : getColumns() ) {
					if( c.isPrimaryKey() ) {
						primaryKeyColumn = c;
						break;
					}
				}
			}
			return primaryKeyColumn;
		}

		public Column getColumn(String columnName) {
			if( columnMap == null ) {
				columnMap = new HashMap<String, Column>();
				for( Column c : columns ) {
					columnMap.put(c.name, c);
				}
			}
			return columnMap.get(columnName);
		}
	}

	public static class Column {
		private final boolean primaryKey;
		private final String name;

		public Column(boolean primaryKey, String name) {
			this.primaryKey = primaryKey;
			this.name = name;
		}

		public boolean isPrimaryKey() {
			return primaryKey;
		}

		public String getName() {
			return name;
		}
	}
}