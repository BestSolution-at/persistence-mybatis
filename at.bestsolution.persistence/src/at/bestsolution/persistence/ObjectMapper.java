package at.bestsolution.persistence;

public interface ObjectMapper<O> {
	public void update(O object);
	public void insert(O object);
	public void delete(O object);
	public void delete(O... object);
	public void deleteById(Object... id);
	public void deleteAll();

	public String getTableName();
	public String getColumnName(String propertyName);
	public <P> P getPrimaryKeyValue(O object);
}