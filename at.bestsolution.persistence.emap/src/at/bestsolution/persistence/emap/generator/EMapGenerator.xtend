/*
 * generated by Xtext
 */
package at.bestsolution.persistence.emap.generator

import at.bestsolution.persistence.emap.eMap.EAttribute
import at.bestsolution.persistence.emap.eMap.EMapping
import at.bestsolution.persistence.emap.eMap.EMappingEntity
import at.bestsolution.persistence.emap.eMap.EMappingEntityDef
import at.bestsolution.persistence.emap.eMap.ENamedQuery
import java.util.ArrayList
import org.eclipse.emf.ecore.EClass
import org.eclipse.emf.ecore.resource.Resource
import org.eclipse.xtext.generator.IFileSystemAccess
import org.eclipse.xtext.generator.IGenerator
import at.bestsolution.persistence.emap.eMap.ReturnType
import at.bestsolution.persistence.emap.eMap.EObjectSection
import java.util.List
import at.bestsolution.persistence.emap.eMap.EParameter
import at.bestsolution.persistence.emap.eMap.EMappingAttribute
import java.util.Map
import java.util.HashMap
import at.bestsolution.persistence.emap.eMap.EMappingBundle
import org.osgi.framework.FrameworkUtil
import org.eclipse.emf.ecore.EReference

/**
 * Generates code from your model files on save.
 *
 * see http://www.eclipse.org/Xtext/documentation.html#TutorialCodeGeneration
 */
class EMapGenerator implements IGenerator {
	static Map<String,DatabaseSupport> DB_SUPPORTS = new HashMap<String,DatabaseSupport>();

	override void doGenerate(Resource resource, IFileSystemAccess fsa) {
		val root = resource.contents.head as EMapping
		if( root.root instanceof EMappingEntityDef ) {
			val edef = root.root as EMappingEntityDef
			if( edef.entity.abstract ) {
				return;
			}
			fsa.generateFile(edef.package.name.replace('.','/')+"/"+edef.entity.name + "Mapper.java", generateJavaMapper(edef, JavaHelper::getEClass(edef.entity.etype)))
//			println("Generating " + edef.entity.name+"Mapper.xml");
			fsa.generateFile("mappers/"+edef.entity.name+"Mapper.xml", generateMappingXML(edef, JavaHelper::getEClass(edef.entity.etype)))
		} else {
			val bundleDef = root.root as EMappingBundle
			fsa.generateFile("mappings/"+bundleDef.name+"MappingUnitProvider.java", generateBundleContribution(bundleDef));
			fsa.generateFile("mappings/"+bundleDef.name+"SqlMetaDataProvider.java", generateSqlMetaDataProvider(bundleDef));
			for( d : bundleDef.databases ) {
				fsa.generateFile("ddls/create_"+d+".sql",DDLGenerator::generatedDDL(bundleDef,getDatabaseSupport(d)));
			}
		}
	}

	def generateSqlMetaDataProvider(EMappingBundle bundleDef) '''
	package mappings;

	import at.bestsolution.persistence.mybatis.SqlMetaDataProvider;

	import java.util.Collections;
	import java.util.HashSet;
	import java.util.HashMap;
	import java.util.Map;
	import java.util.Set;

	@SuppressWarnings("restriction")
	public class «bundleDef.name»SqlMetaDataProvider implements SqlMetaDataProvider {
		private Set<Table> tableSet = new HashSet<Table>();
		public «bundleDef.name»SqlMetaDataProvider() {
			«FOR e : bundleDef.entities»
			{
				Set<Column> colSet = new HashSet<Column>();
				«val pk = e.collectDerivedAttributes.values.findFirst[pk]»
				«FOR a : e.collectDerivedAttributes.values»
					«IF a.columnName != null»
						colSet.add(new Column(«a.pk»,"«a.columnName»"));
					«ELSEIF a.parameters.size == 1 && a.parameters.head != pk.columnName»
						colSet.add(new Column(false,"«a.parameters.head»"));
					«ENDIF»
				«ENDFOR»
				tableSet.add(new Table("«e.calcTableName»",colSet));
			}
			«ENDFOR»
		}

		public Set<Table> getTables() {
			return Collections.unmodifiableSet(tableSet);
		}
	}
	'''

	def generateBundleContribution(EMappingBundle bundleDef) '''
		package mappings;

		import at.bestsolution.persistence.mybatis.MappingProvider;
		import at.bestsolution.persistence.mybatis.mapper.URLMappingUnit;

		import java.util.List;
		import java.util.ArrayList;
		import java.util.Collections;

		@SuppressWarnings("restriction")
		public class «bundleDef.name»MappingUnitProvider implements MappingProvider {
			private List<MappingUnit> units;

			public «bundleDef.name»MappingUnitProvider() {
				units = new ArrayList<MappingUnit>();
				«FOR e : bundleDef.entities»
					units.add(new URLMappingUnit("mappers/«e.name»Mapper.xml",
						«JavaHelper::getEClass(e.etype).instanceClassName».class,
						«JavaHelper::getEClass(e.etype).instanceClassName»Mapper.class,
						«JavaHelper::getEClass(e.etype).packageName».«JavaHelper::getEClass(e.etype).EPackage.name.toFirstUpper»Package.eINSTANCE.get«JavaHelper::getEClass(e.etype).name»(),getClass().getClassLoader().getResource("mappers/«e.name»Mapper.xml")));
				«ENDFOR»
			}

			public List<MappingUnit> getMappingUnits() {
				return Collections.unmodifiableList(units);
			}
		}
	'''

	def generateJavaMapper(EMappingEntityDef entityDef, EClass eClass) '''
	package «entityDef.package.name»;

	public interface «entityDef.entity.name»Mapper extends at.bestsolution.persistence.ObjectMapper<«eClass.instanceClassName»> {
		«FOR query : entityDef.entity.namedQueries»
		public «IF query.returnType == ReturnType::LIST»java.util.List<«ENDIF»«eClass.instanceClassName»«IF query.returnType == ReturnType::LIST»>«ENDIF» «query.name»(«query.parameters.join(",",[p|p.type + " " + p.name])»);
		«ENDFOR»
	}
	'''

	def generateMappingXML(EMappingEntityDef entityDef, EClass eClass) '''
<?xml version="1.0" encoding="UTF-8" ?>
<!DOCTYPE mapper
  PUBLIC "-//mybatis.org//DTD Mapper 3.0//EN"
  "http://mybatis.org/dtd/mybatis-3-mapper.dtd">
<mapper namespace="«eClass.instanceClassName»Mapper">
	«FOR query : entityDef.entity.namedQueries»
		<select id="«query.name»"
			«IF ! query.parameters.empty»parameterType="«IF query.parameters.size > 1»HashMap«ELSE»«query.parameters.head.type»«ENDIF»"«ENDIF»
			«IF query.queries.head.mapping.attributes.empty && entityDef.entity.descriminationColumn == null»resultMap="Default_«eClass.name»Map"«ELSE»resultMap="«query.name»_«eClass.name»Map"«ENDIF»>
			SELECT
				«IF query.queries.head.mapping.attributes.empty»
					*
				«ELSE»
					«query.queries.head.mapping.mapColumns»
				«ENDIF»
			FROM
				«query.queries.head.from.replaceParameters(query.parameters)»
			«IF query.queries.head.where != null»WHERE
				«query.queries.head.where.replaceParameters(query.parameters)»«ENDIF»
			«IF query.queries.head.groupBy != null»GROUP BY
				«query.queries.head.groupBy.replaceParameters(query.parameters)»«ENDIF»
			«IF query.queries.head.orderby != null»ORDER BY
				«query.queries.head.orderby.replaceParameters(query.parameters)»«ENDIF»
		</select>
		«IF !query.queries.head.mapping.attributes.empty»
		<resultMap id="«query.name»_«eClass.name»Map" type="«eClass.instanceClassName»">
			«query.queries.head.mapping.objectSectionMap»
		</resultMap>
		«ELSEIF entityDef.entity.descriminationColumn != null»
		<resultMap id="«query.name»_«eClass.name»Map" type="«eClass.instanceClassName»">
			«attrib_resultMapContent(entityDef.entity.collectAttributes, eClass, "")»
			<discriminator javaType="java.lang.String" column="«entityDef.entity.descriminationColumn»">
				«FOR d : query.queries.head.mapping.descriminatedTypes»
				<case value="«d.name»" resultMap="«d.fqn».Default_«d.name»Map" />
				«ENDFOR»
			</discriminator>
		</resultMap>
		«ENDIF»
	«ENDFOR»
	<resultMap id="Default_«eClass.name»Map" type="«eClass.instanceClassName»">
		«attrib_resultMapContent(entityDef.entity.collectAttributes, eClass, "")»
	</resultMap>
	«val pkAttribute = entityDef.entity.collectDerivedAttributes.values.findFirst[pk]»
	«IF pkAttribute == null || entityDef.entity.extensionType == "extends"»
		«generateInsert(entityDef,eClass,null,null)»
	«ELSE»
		«val dbSupport = pkAttribute.findDatabaseSupport»
		«IF dbSupport != null»
			«FOR d : dbSupport»
				«generateInsert(entityDef,eClass,pkAttribute,d)»
			«ENDFOR»
		«ENDIF»
	«ENDIF»

	<update id="update">
		UPDATE
			«entityDef.tableName»
		<set>
			«FOR a : entityDef.entity.collectDerivedAttributes.values.filter[
					if( pk ) {
						return false;
					} if(eClass.getEStructuralFeature(property) instanceof EReference) {
						val r = eClass.getEStructuralFeature(property) as EReference;
						if( r.containment ) {
							return false;
						}
						return true;
					} else {
						return true;
					}
				].sort([a,b|return sortAttributes(eClass,a,b)])»
				«IF a.columnName != null»
					«a.columnName» = #{«a.property»},
				«ELSEIF a.isSingle(eClass)»
					<if test="_isResolved_«a.property»">«a.parameters.head» = #{«a.property».«(a.query.eContainer as EMappingEntity).collectAttributes.findFirst[pk].property»},</if>
				«ENDIF»
			«ENDFOR»
		</set>
		WHERE
			«entityDef.entity.collectAttributes.findFirst[pk].columnName» = #{«entityDef.entity.collectAttributes.findFirst[pk].property»}
	</update>
</mapper>
	'''

	def static generateInsert(EMappingEntityDef entityDef, EClass eClass, EAttribute pkAttribute, DatabaseSupport dbSupport) '''
	<insert id="insert" parameterType="«eClass.instanceClassName»"
		«IF dbSupport != null»databaseId="«dbSupport.databaseId»" «IF dbSupport.supportsGeneratedKeys»useGeneratedKeys="true" keyProperty="«pkAttribute.property»"«ENDIF»«ENDIF»>
		«IF dbSupport != null»
			«dbSupport.processInsert(pkAttribute,insertSQL(entityDef,eClass,pkAttribute,dbSupport).toString)»
		«ELSE»
			«insertSQL(entityDef,eClass,pkAttribute,dbSupport)»
		«ENDIF»
	</insert>
	'''

	def static insertSQL(EMappingEntityDef entityDef, EClass eClass, EAttribute pkAttribute, DatabaseSupport dbSupport) '''
	«val gen = if(pkAttribute == null) null else pkAttribute.valueGenerators.findFirst[dbType==dbSupport.databaseId]»
	INSERT INTO «entityDef.tableName»
	(
		<trim suffixOverrides=','>
			«IF pkAttribute != null && gen.sequence != null»
				«pkAttribute.columnName»,
			«ENDIF»
			«FOR a : entityDef.entity.collectDerivedAttributes.values.filter[
					if( pk && entityDef.entity.extensionType != "extends" ) {
						return false;
					} if(eClass.getEStructuralFeature(property) instanceof EReference) {
						val r = eClass.getEStructuralFeature(property) as EReference;
						if( r.containment ) {
							return false;
						}
						return true;
					} else {
						return true;
					}
			].sort([a,b|return sortAttributes(eClass,a,b)])»
				«IF a.columnName != null»
				«a.columnName»,
				«ELSEIF a.isSingle(eClass)»
				«a.parameters.head»,
				«ENDIF»
			«ENDFOR»
			«IF entityDef.entity.descriminationColumn != null»
				«entityDef.entity.descriminationColumn»
			«ENDIF»
		</trim>
	)
	VALUES
	(
		<trim suffixOverrides=','>
			«IF pkAttribute != null»
				«IF gen.sequence != null»
					«dbSupport.getSequenceStatement(pkAttribute)»,
				«ENDIF»
			«ELSEIF entityDef.entity.extensionType == "extends"»
				#{«entityDef.entity.attributes.findFirst[pk].property»},
			«ENDIF»
			«FOR a : entityDef.entity.collectDerivedAttributes.values.filter[if( pk ) {
						return false;
					} if(eClass.getEStructuralFeature(property) instanceof EReference) {
						val r = eClass.getEStructuralFeature(property) as EReference;
						if( r.containment ) {
							return false;
						}
						return true;
					} else {
						return true;
					}
				].sort([a,b|return sortAttributes(eClass,a,b)])»
				«IF a.columnName != null»
					#{«a.property»},
				«ELSEIF a.isSingle(eClass)»
					#{«a.property».«(a.query.eContainer as EMappingEntity).collectAttributes.findFirst[pk].property»},
				«ENDIF»
			«ENDFOR»
			«IF entityDef.entity.descriminationColumn != null»
				#{_classname}
			«ENDIF»
		</trim>
	)
	'''

	def static List<DatabaseSupport> findDatabaseSupport(EAttribute attribute) {
		if( attribute == null ) {
			return null;
		}
		val rv = new ArrayList
		for( v : attribute.valueGenerators ) {
			val s = getDatabaseSupport(v.dbType)
			if( s != null ) {
				rv.add(s);
			}
		}

		return rv;
	}

	def static getDatabaseSupport(String name) {
		if( DB_SUPPORTS.containsKey(name) ) {
			return DB_SUPPORTS.get(name)
		} else {
			val bundle = FrameworkUtil::getBundle(typeof(EMapGenerator))
			val serviceRef = bundle.bundleContext.getServiceReferences(typeof(DatabaseSupport),null)
			for( sr : serviceRef ) {
				val s = bundle.bundleContext.getService(sr)
				if( name == s.databaseId ) {
					DB_SUPPORTS.put(name, s);
					return s;
				}
			}
		}
	}

	def static sortValue(EAttribute a, EClass eClass) {
		if( a.pk ) {
			return 0;
		} else if( a.resolved ) {
			if( a.isSingle(eClass) ) {
				return 2;
			} else {
				return 3;
			}
		} else {
			return 1;
		}
	}

	def static attrib_resultMapContent(Iterable<EAttribute> attributes, EClass eClass, String columnPrefix) '''
	<!-- Default mapping -->
	«FOR a : attributes.sort([a,b|
		val iA = a.sortValue(eClass)
		val iB = b.sortValue(eClass)
		return Integer.compare(iA,iB)
	])»
		«IF a.pk»
			<id property="«a.property»" column="«columnPrefix»«a.columnName»" />
		«ELSE»
			«IF a.resolved»
				«IF a.isSingle(eClass)»
					<association property="«a.property»" column="«columnPrefix»«a.parameters.head»" select="«a.query.fqn»"/>
				«ELSE»
					<collection property="«a.property»" column="«columnPrefix»«attributes.head.columnName»" select="«a.query.fqn»" />
				«ENDIF»
			«ELSE»
				<result property="«a.property»" column="«columnPrefix»«a.columnName»" />
			«ENDIF»
		«ENDIF»
	«ENDFOR»
	'''

	def static mappedattrib_resultMapContent(Iterable<EMappingAttribute> attributes, EClass eClass, String columnPrefix) '''
	<!-- MAPPED -->
	«FOR a : attributes»
		«IF a.pk»
			<id property="«a.property»" column="«a.columnName»" />
		«ELSE»
			«IF a.resolved»
				«IF a.isSingle(eClass)»
					<association property="«a.property»" column="«a.parameters.head»" select="«a.query.fqn»"/>
				«ELSE»
					<collection property="«a.property»" select="«a.query.fqn»" />
				«ENDIF»
			«ELSEIF a.mapped»
				«IF a.isSingle(eClass)»
					<association property="«a.property»" javaType="«JavaHelper::getEClass(a.map.entity.etype).instanceClassName»">
						«a.map.objectSectionMap»
					</association>
				«ELSE»
					<collection property="«a.property»" ofType="«JavaHelper::getEClass(a.map.entity.etype).instanceClassName»">
						«a.map.objectSectionMap»
					</collection>
				«ENDIF»
			«ELSE»
				<result property="«a.property»" column="«a.columnName»" />
			«ENDIF»
		«ENDIF»
	«ENDFOR»
	'''

	def static CharSequence objectSectionMap(EObjectSection section) '''
	«attrib_resultMapContent(section.entity.collectAttributes.filter[a|section.attributes.findFirst[ma|ma.property == a.property] == null],JavaHelper::getEClass(section.entity.etype),section.prefix+"_")»
	«mappedattrib_resultMapContent(section.attributes, JavaHelper::getEClass(section.entity.etype),section.prefix+"_")»
	'''
//	{
//		val attrs = section.entity.collectAttributes
//		for( attr : section.attributes ) {
//			attrs.remove(attrs.findFirst[a|a.property == attr.property])
//		}
//
//
//
//		return "";
//	}

	def static replaceParameters(String v, List<EParameter> parameters) {
		if( parameters.empty ){
			return v;
		} else if( parameters.size == 1 ) {
			if( parameters.head.type.isPrimitive ) {
				return v.replace("${"+parameters.head.name+"}","#{id}");
			}
			return v.replace("${"+parameters.head.name+".","#{");
		} else {
			return v.replace("${","#{");
		}
	}

	def static isPrimitive(String type) {
		switch(type) {
			case "long": return true
			case "int": return true
		}
		return false;
	}

	def static String mapColumns(EObjectSection s) {
		val atts = s.entity.collectAllAttributes
		val id = atts.findFirst[a|a.pk]

		val StringBuilder b = new StringBuilder;
		b.append(atts.filter[a| ! a.resolved || a.parameters.head != id.columnName ].join(",\n",[a| s.prefix(a) + ".\"" + (if(a.resolved) a.parameters.head else a.columnName) + "\"\t" + s.prefix + "_" + if(a.resolved) a.parameters.head else a.columnName]))

		for( es : s.attributes.filter[a|a.map!=null] ) {
			b.append(",\n\n" + es.map.mapColumns)
		}

		return b.toString;
	}

	def static String prefix(EObjectSection s, EAttribute attribute) {
		val allDerivedAttributes = s.entity.collectDerivedAttributes
		if( allDerivedAttributes.containsKey(attribute.property) ) {
			if( ! attribute.pk || s.entity == attribute.eContainer ) {
				return s.prefix;
			} else {
				val ownerType = getDbOwnerType(attribute.eContainer as EMappingEntity, attribute)
				return s.prefix + if (ownerType == null) "__UNKNOWN__" else "_" + ownerType.name.toLowerCase
			}
		}
		val ownerType = getDbOwnerType(s.entity, attribute)
		return s.prefix + if (ownerType == null) "__UNKNOWN__" else "_" + ownerType.name.toLowerCase
	}

	def static EClass getDbOwnerType(EMappingEntity childEntity, EAttribute attribute) {
		val allDerivedAttributes = childEntity.collectDerivedAttributes
		if( allDerivedAttributes.containsKey(attribute.property) ) {
			return JavaHelper::getEClass(childEntity.etype)
		} else if( childEntity.parent != null && childEntity.extensionType == "extends" ) {
			return getDbOwnerType(childEntity.parent, attribute)
		}
		return null;
	}

	def static fqn(ENamedQuery e) {
		val r = (e.eResource.contents.head as EMapping).root
		if( r instanceof EMappingEntityDef ) {
			val d = r as EMappingEntityDef;
			return d.package.name + "." + d.entity.name + "Mapper." + e.name
		}
		return "NOX DA"
	}

	def static fqn(EMappingEntity e) {
		val r = (e.eResource.contents.head as EMapping).root
		if( r instanceof EMappingEntityDef ) {
			val d = r as EMappingEntityDef;
			return d.package.name + "." + d.entity.name + "Mapper"
		}
		return "NOX DA"
	}

	def static isSingle(EAttribute attribute, EClass eclass) {
		if( eclass.getEStructuralFeature(attribute.property) == null ) {
			throw new IllegalStateException("Could not find attribute '"+attribute.property+"' in '"+eclass.name+"'")
		}
		return ! eclass.getEStructuralFeature(attribute.property).many
	}

	def static isSingle(EMappingAttribute attribute, EClass eclass) {
		return ! eclass.getEStructuralFeature(attribute.property).many
	}

	def static tableName(EMappingEntityDef entityDef) {
		if( entityDef.entity.tableName == null ) {
			return JavaHelper::getEClass(entityDef.entity.etype).name.toUpperCase
		}
		return entityDef.entity.tableName
	}

	def static calcTableName(EMappingEntity entity) {
		if( entity.tableName == null ) {
			return JavaHelper::getEClass(entity.etype).name.toUpperCase
		}
		return entity.tableName
	}

	def static sortAttributes(EClass eClass, EAttribute a, EAttribute b) {
		if (a.pk)
			return -1
		else if (b.pk)
			return 1
		else
			if ( a.resolved && b.resolved ) {
				if( a.isSingle(eClass) && b.isSingle(eClass) ) {
					return a.property.compareToIgnoreCase(b.property)
				} else if( a.isSingle(eClass) ) {
					return -1;
				} else if( b.isSingle(eClass) ) {
					return 1;
				}
				return a.property.compareToIgnoreCase(b.property)
			}
			else if( ! a.resolved && !  b.resolved )
				return a.property.compareToIgnoreCase(b.property)
			else if( ! a.resolved )
				return -1
			else if( ! b.resolved )
				return 1
			else
				return a.property.compareToIgnoreCase(b.property)
	}

	def static collectAttributes(EMappingEntity entity) {
		val l = new ArrayList<EAttribute>
		entity.allAttributes(l,false)
		val eClass = JavaHelper::getEClass(entity.etype);
		l.sort([ a,b | return sortAttributes(eClass,a,b)]);
		return l
	}

	def static void allAttributes(EMappingEntity entity, ArrayList<EAttribute> l, boolean skipPrimary) {
		l.addAll(entity.attributes.filter[! skipPrimary || ! pk ])
		if( entity.parent != null ) {
			entity.parent.allAttributes(l, true)
		}
	}

	def static collectAllAttributes(EMappingEntity entity) {
		val l = new ArrayList<EAttribute>
		entity.allAttributes(l)
		val eClass = JavaHelper::getEClass(entity.etype);
		l.sort([ a,b | return sortAttributes(eClass,a,b)]);
		return l
	}

	def static void allAttributes(EMappingEntity entity, ArrayList<EAttribute> l) {
		l.addAll(entity.attributes)
		if( entity.parent != null ) {
			entity.parent.allAttributes(l)
		}
	}

	def static collectDerivedAttributes(EMappingEntity entity) {
		val map = new HashMap<String,EAttribute>
		entity.allDerivedAttributes(map)
		return map
	}

	def static void allDerivedAttributes(EMappingEntity entity, Map<String, EAttribute> map) {
		for( a : entity.attributes ) {
			map.put(a.property,a);
		}
		if( entity.parent != null && entity.extensionType == "derived" ) {
			entity.parent.allDerivedAttributes(map)
		}
	}

	static def packageName(EClass eClass) {
		return eClass.instanceClassName.substring(0,eClass.instanceClassName.lastIndexOf("."))
	}
}
